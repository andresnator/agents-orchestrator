#!/usr/bin/env python3
"""Validate the manual-test catalog and report PR-affected case IDs."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DOMAIN_NAMES = (
    "architecture",
    "common",
    "docs",
    "learning",
    "meta",
    "orchestration",
    "plan",
    "review",
)
CATALOG_PATHS = {
    "repository": Path("docs/manual-testing.md"),
    **{domain: Path(f"domains/{domain}/manual-tests.md") for domain in DOMAIN_NAMES},
}
REQUIRED_FIELDS = (
    "Title",
    "Coverage key",
    "Applies to",
    "Preconditions",
    "Steps",
    "Expected result",
    "Cleanup",
)
OPTIONAL_FIELD = "Essential negative variant"
FIELD_ORDER = REQUIRED_FIELDS[:-1] + (OPTIONAL_FIELD, REQUIRED_FIELDS[-1])
CASE_HEADING_PATTERN = re.compile(r"^### (?P<id>MT-[A-Z0-9]+(?:-[A-Z0-9]+)+)\s*$", re.MULTILINE)
ANY_LEVEL_THREE_HEADING_PATTERN = re.compile(r"^### (?P<title>.+?)\s*$", re.MULTILINE)
FIELD_PATTERN = re.compile(r"^- \*\*(?P<name>[^*]+):\*\*(?:\s+(?P<value>.*))?$")
CODE_SPAN_PATTERN = re.compile(r"`([^`\n]+)`")
ID_PATTERN = re.compile(r"^MT-[A-Z0-9]+(?:-[A-Z0-9]+)+$")
COVERAGE_KEY_PATTERN = re.compile(r"^[a-z0-9-]+/[a-z0-9-]+/[a-z0-9-]+$")
ORDERED_STEP_PATTERN = re.compile(r"(?m)^\s{2,}\d+\.\s+\S")
RUNTIME_PATTERNS = (
    "global/AGENTS.md",
    "installers/**",
    "scripts/*.py",
    "scripts/*.sh",
    "domains/*/agents/**",
    "domains/*/commands/**",
    "domains/*/skills/**",
    "domains/*/plugins/**",
    "domains/*/external-plugins/**",
    "skills/**",
)
NON_RUNTIME_PATTERNS = (
    "scripts/lint-manual-tests.py",
    "skills/README.md",
    "domains/*/README.md",
    "domains/*/manual-tests.md",
)


@dataclass(frozen=True)
class ManualCase:
    case_id: str
    domain: str
    title: str
    coverage_key: str
    applies_to: tuple[str, ...]
    source: Path
    line: int
    raw: str


@dataclass(frozen=True)
class CaseSnapshot:
    case_id: str
    title: str
    coverage_key: str
    raw: str


def relative(path: Path) -> str:
    return path.relative_to(REPOSITORY_ROOT).as_posix()


def normalize_title(title: str) -> str:
    decomposed = unicodedata.normalize("NFKD", title)
    ascii_title = "".join(character for character in decomposed if not unicodedata.combining(character))
    return re.sub(r"[^a-z0-9]+", "-", ascii_title.casefold()).strip("-")


def compile_glob(pattern: str) -> re.Pattern[str]:
    trailing_tree = pattern.endswith("/**")
    body = pattern[:-3] if trailing_tree else pattern
    translated: list[str] = []
    index = 0
    while index < len(body):
        if body[index : index + 2] == "**":
            translated.append(".*")
            index += 2
        elif body[index] == "*":
            translated.append("[^/]*")
            index += 1
        elif body[index] == "?":
            translated.append("[^/]")
            index += 1
        else:
            translated.append(re.escape(body[index]))
            index += 1
    suffix = r"(?:/.*)?" if trailing_tree else ""
    return re.compile("^" + "".join(translated) + suffix + "$")


def path_matches(path: str, pattern: str) -> bool:
    return compile_glob(pattern).fullmatch(path) is not None


def parse_fields(block: str, source: Path, line: int, errors: list[str]) -> dict[str, str]:
    fields: dict[str, str] = {}
    current_name: str | None = None
    values: list[str] = []

    def finish_field() -> None:
        nonlocal values
        if current_name is not None:
            fields[current_name] = "\n".join(values).strip()
        values = []

    for block_line in block.splitlines()[1:]:
        match = FIELD_PATTERN.match(block_line)
        if match:
            finish_field()
            current_name = match.group("name")
            if current_name in fields:
                errors.append(f"{relative(source)}:{line}: duplicate field '{current_name}'")
            values = [match.group("value") or ""]
        elif current_name is not None:
            values.append(block_line)
    finish_field()
    return fields


def validate_field_order(fields: dict[str, str], source: Path, line: int, errors: list[str]) -> None:
    names = tuple(fields)
    expected_without_optional = REQUIRED_FIELDS
    expected_with_optional = FIELD_ORDER
    if names not in (expected_without_optional, expected_with_optional):
        errors.append(
            f"{relative(source)}:{line}: fields must follow the canonical order "
            f"{', '.join(REQUIRED_FIELDS[:-1])}, [{OPTIONAL_FIELD}], {REQUIRED_FIELDS[-1]}"
        )


def validate_title(title: str, source: Path, line: int, errors: list[str]) -> str:
    normalized = normalize_title(title)
    if not normalized:
        errors.append(f"{relative(source)}:{line}: Title must contain letters or numbers")
    if title != title.strip() or "  " in title:
        errors.append(f"{relative(source)}:{line}: Title must use normalized spacing")
    if title and (not title[0].isalnum() or title[0] != title[0].upper()):
        errors.append(f"{relative(source)}:{line}: Title must start with an uppercase letter or number")
    if title.endswith((".", ":", ";", "!", "?")):
        errors.append(f"{relative(source)}:{line}: Title must not end with punctuation")
    return normalized


def validate_applies_to(value: str, source: Path, line: int, errors: list[str]) -> tuple[str, ...]:
    patterns = tuple(CODE_SPAN_PATTERN.findall(value))
    residue = CODE_SPAN_PATTERN.sub("", value).replace(",", "").strip()
    if not patterns or residue:
        errors.append(
            f"{relative(source)}:{line}: Applies to must be a comma-separated list of backticked paths or globs"
        )
    if len(set(patterns)) != len(patterns):
        errors.append(f"{relative(source)}:{line}: Applies to contains a duplicate pattern")
    for pattern in patterns:
        parts = Path(pattern).parts
        if pattern.startswith("/") or "\\" in pattern or ".." in parts:
            errors.append(f"{relative(source)}:{line}: invalid Applies to pattern '{pattern}'")
    return patterns


def parse_catalog_file(domain: str, source: Path, errors: list[str]) -> list[ManualCase]:
    if not source.is_file():
        errors.append(f"missing catalog document: {relative(source)}")
        return []

    text = source.read_text(encoding="utf-8")
    valid_headings = {match.start() for match in CASE_HEADING_PATTERN.finditer(text)}
    for heading in ANY_LEVEL_THREE_HEADING_PATTERN.finditer(text):
        if heading.start() not in valid_headings:
            heading_line = text.count("\n", 0, heading.start()) + 1
            errors.append(
                f"{relative(source)}:{heading_line}: level-three headings are reserved for manual case IDs"
            )

    heading_matches = list(CASE_HEADING_PATTERN.finditer(text))
    cases: list[ManualCase] = []
    for index, heading in enumerate(heading_matches):
        end = heading_matches[index + 1].start() if index + 1 < len(heading_matches) else len(text)
        block = text[heading.start() : end].strip()
        line = text.count("\n", 0, heading.start()) + 1
        case_id = heading.group("id")
        fields = parse_fields(block, source, line, errors)

        unknown_fields = tuple(name for name in fields if name not in FIELD_ORDER)
        for name in unknown_fields:
            errors.append(f"{relative(source)}:{line}: unknown field '{name}'")
        for name in REQUIRED_FIELDS:
            if not fields.get(name, "").strip():
                errors.append(f"{relative(source)}:{line}: missing or empty field '{name}'")
        validate_field_order(fields, source, line, errors)

        title = fields.get("Title", "").strip()
        validate_title(title, source, line, errors)
        expected_prefix = f"MT-{domain.upper()}-"
        if not ID_PATTERN.fullmatch(case_id) or not case_id.startswith(expected_prefix):
            errors.append(
                f"{relative(source)}:{line}: ID '{case_id}' must use the domain prefix '{expected_prefix}'"
            )

        coverage_value = fields.get("Coverage key", "").strip()
        coverage_match = re.fullmatch(r"`([^`]+)`", coverage_value)
        coverage_key = coverage_match.group(1) if coverage_match else ""
        if coverage_match is None or not COVERAGE_KEY_PATTERN.fullmatch(coverage_key):
            errors.append(
                f"{relative(source)}:{line}: Coverage key must be one backticked '<domain>/<surface>/<behavior>' value"
            )
        elif not coverage_key.startswith(f"{domain}/"):
            errors.append(
                f"{relative(source)}:{line}: Coverage key '{coverage_key}' must start with '{domain}/'"
            )

        applies_to = validate_applies_to(fields.get("Applies to", ""), source, line, errors)
        if fields.get("Steps") and not ORDERED_STEP_PATTERN.search(fields["Steps"]):
            errors.append(f"{relative(source)}:{line}: Steps must contain an indented ordered list")

        cases.append(
            ManualCase(
                case_id=case_id,
                domain=domain,
                title=title,
                coverage_key=coverage_key,
                applies_to=applies_to,
                source=source,
                line=line,
                raw=block,
            )
        )
    if not cases:
        errors.append(f"{relative(source)}: catalog document contains no manual cases")
    return cases


def validate_uniqueness(cases: list[ManualCase], errors: list[str]) -> None:
    seen_ids: dict[str, ManualCase] = {}
    seen_keys: dict[str, ManualCase] = {}
    seen_titles: dict[str, ManualCase] = {}
    for case in cases:
        for value, seen, label in (
            (case.case_id, seen_ids, "ID"),
            (case.coverage_key, seen_keys, "coverage key"),
            (normalize_title(case.title), seen_titles, "normalized title"),
        ):
            if not value:
                continue
            previous = seen.get(value)
            if previous is not None:
                errors.append(
                    f"{relative(case.source)}:{case.line}: duplicate {label} '{value}'; first used at "
                    f"{relative(previous.source)}:{previous.line}"
                )
            else:
                seen[value] = case


def require_link(source: Path, target: str, errors: list[str]) -> None:
    if not source.is_file():
        errors.append(f"missing link source: {relative(source)}")
        return
    text = source.read_text(encoding="utf-8")
    if f"]({target})" not in text:
        errors.append(f"{relative(source)}: missing Markdown link to {target}")


def validate_catalog_links(errors: list[str]) -> None:
    require_link(REPOSITORY_ROOT / "README.md", "docs/manual-testing.md", errors)
    require_link(REPOSITORY_ROOT / "CONTRIBUTING.md", "docs/manual-testing.md", errors)
    index = REPOSITORY_ROOT / "docs/manual-testing.md"
    for domain in DOMAIN_NAMES:
        require_link(index, f"../domains/{domain}/manual-tests.md", errors)
        require_link(REPOSITORY_ROOT / f"domains/{domain}/README.md", "manual-tests.md", errors)


def git_output(arguments: list[str]) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=REPOSITORY_ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip() or "unknown Git error"
        raise RuntimeError(detail)
    return completed.stdout


def changed_paths(base: str, head: str) -> tuple[str, ...]:
    output = git_output(["diff", "--name-status", "--find-renames", f"{base}...{head}"])
    paths: list[str] = []
    for line in output.splitlines():
        columns = line.split("\t")
        if not columns:
            continue
        status = columns[0]
        if status.startswith(("R", "C")) and len(columns) == 3:
            paths.extend(columns[1:])
        elif len(columns) == 2:
            paths.append(columns[1])
    return tuple(dict.fromkeys(paths))


def read_git_file(reference: str, path: Path) -> str | None:
    completed = subprocess.run(
        ["git", "show", f"{reference}:{path.as_posix()}"],
        cwd=REPOSITORY_ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return completed.stdout if completed.returncode == 0 else None


def case_snapshots(text: str | None) -> dict[str, CaseSnapshot]:
    if text is None:
        return {}
    headings = list(CASE_HEADING_PATTERN.finditer(text))
    snapshots: dict[str, CaseSnapshot] = {}
    for index, heading in enumerate(headings):
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        block = text[heading.start() : end].strip()
        fields: dict[str, str] = {}
        current_name: str | None = None
        values: list[str] = []
        for block_line in block.splitlines()[1:]:
            field_match = FIELD_PATTERN.match(block_line)
            if field_match:
                if current_name is not None:
                    fields[current_name] = "\n".join(values).strip()
                current_name = field_match.group("name")
                values = [field_match.group("value") or ""]
            elif current_name is not None:
                values.append(block_line)
        if current_name is not None:
            fields[current_name] = "\n".join(values).strip()
        coverage_match = re.fullmatch(r"`([^`]+)`", fields.get("Coverage key", ""))
        snapshots[heading.group("id")] = CaseSnapshot(
            case_id=heading.group("id"),
            title=fields.get("Title", ""),
            coverage_key=coverage_match.group(1) if coverage_match else "",
            raw=block,
        )
    return snapshots


def base_snapshots(base: str) -> dict[str, CaseSnapshot]:
    snapshots: dict[str, CaseSnapshot] = {}
    for path in CATALOG_PATHS.values():
        snapshots.update(case_snapshots(read_git_file(base, path)))
    return snapshots


def validate_immutable_identity(
    current_cases: list[ManualCase], previous: dict[str, CaseSnapshot], errors: list[str]
) -> None:
    previous_by_key = {case.coverage_key: case for case in previous.values() if case.coverage_key}
    previous_by_id = previous
    for case in current_cases:
        old_with_key = previous_by_key.get(case.coverage_key)
        if old_with_key is not None and old_with_key.case_id != case.case_id:
            errors.append(
                f"{relative(case.source)}:{case.line}: coverage key '{case.coverage_key}' keeps immutable ID "
                f"'{old_with_key.case_id}', not '{case.case_id}'"
            )
        old_with_id = previous_by_id.get(case.case_id)
        if old_with_id is not None and old_with_id.coverage_key != case.coverage_key:
            errors.append(
                f"{relative(case.source)}:{case.line}: ID '{case.case_id}' keeps immutable coverage key "
                f"'{old_with_id.coverage_key}'"
            )


def ownership_aliases(path: str) -> tuple[str, ...]:
    parts = Path(path).parts
    if len(parts) < 2 or parts[0] != "skills":
        return ()
    skill_name = parts[1]
    remainder = parts[2:]
    aliases: list[str] = []
    for domain in DOMAIN_NAMES:
        owner = REPOSITORY_ROOT / "domains" / domain / "skills" / skill_name
        if not owner.is_symlink():
            continue
        alias = Path("domains") / domain / "skills" / skill_name
        if remainder:
            alias = alias.joinpath(*remainder)
        aliases.append(alias.as_posix())
    return tuple(aliases)


def matching_case_ids(path: str, cases: list[ManualCase]) -> set[str]:
    candidates = (path, *ownership_aliases(path))
    return {
        case.case_id
        for case in cases
        if any(path_matches(candidate, pattern) for candidate in candidates for pattern in case.applies_to)
    }


def is_runtime_artifact(path: str) -> bool:
    if any(path_matches(path, pattern) for pattern in NON_RUNTIME_PATTERNS):
        return False
    absolute_path = REPOSITORY_ROOT / path
    if not absolute_path.exists() and not absolute_path.is_symlink():
        return False
    return any(path_matches(path, pattern) for pattern in RUNTIME_PATTERNS)


def modified_case_ids(current: list[ManualCase], previous: dict[str, CaseSnapshot]) -> set[str]:
    current_by_id = {case.case_id: case for case in current}
    changed = {
        case_id
        for case_id, case in current_by_id.items()
        if case_id not in previous or case.raw != previous[case_id].raw
    }
    changed.update(case_id for case_id in previous if case_id not in current_by_id)
    return changed


def case_link(case: ManualCase) -> str:
    return f"{relative(case.source)}#{case.case_id.casefold()}"


def render_summary(
    cases: list[ManualCase],
    previous: dict[str, CaseSnapshot],
    affected_ids: set[str],
    errors: list[str],
) -> str:
    status = "PASS" if not errors else "FAIL"
    lines = ["# Manual test catalog", "", f"**{status}** — {len(cases)} catalog cases parsed."]
    if errors:
        lines.extend(("", "## Catalog errors", ""))
        lines.extend(f"- {error}" for error in errors)
    lines.extend(("", "## Affected manual cases", ""))
    current_by_id = {case.case_id: case for case in cases}
    if affected_ids:
        for case_id in sorted(affected_ids):
            case = current_by_id.get(case_id)
            if case is not None:
                lines.append(f"- [`{case.case_id}`]({case_link(case)}) — {case.title}")
            else:
                old = previous.get(case_id)
                old_title = old.title if old and old.title else "Removed from the catalog"
                lines.append(f"- `{case_id}` — {old_title} (removed)")
    else:
        lines.append("No runtime manual cases are affected by this change.")
    lines.extend(
        (
            "",
            "This check validates catalog structure and lists what a human should run. "
            "It does not execute OpenCode, installers, plugins, or manual cases.",
            "",
        )
    )
    return "\n".join(lines)


def write_summary(path: Path | None, content: str) -> None:
    if path is None:
        return
    with path.open("a", encoding="utf-8") as summary_file:
        summary_file.write(content)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate manual-test Markdown and optionally report cases affected between two Git refs."
    )
    parser.add_argument("--base", help="PR base commit or ref")
    parser.add_argument("--head", help="PR head commit or ref")
    parser.add_argument("--summary", type=Path, help="append Markdown output to this summary file")
    arguments = parser.parse_args()
    if bool(arguments.base) != bool(arguments.head):
        parser.error("--base and --head must be supplied together")
    return arguments


def main() -> int:
    arguments = parse_arguments()
    errors: list[str] = []
    cases: list[ManualCase] = []
    for domain, path in CATALOG_PATHS.items():
        cases.extend(parse_catalog_file(domain, REPOSITORY_ROOT / path, errors))
    validate_uniqueness(cases, errors)
    validate_catalog_links(errors)

    previous: dict[str, CaseSnapshot] = {}
    affected_ids: set[str] = set()
    if arguments.base and arguments.head:
        try:
            paths = changed_paths(arguments.base, arguments.head)
            previous = base_snapshots(arguments.base)
            validate_immutable_identity(cases, previous, errors)
            affected_ids.update(modified_case_ids(cases, previous))
            for path in paths:
                matches = matching_case_ids(path, cases)
                affected_ids.update(matches)
                if is_runtime_artifact(path) and not matches:
                    errors.append(f"runtime artifact has no manual coverage: {path}")
        except RuntimeError as error:
            errors.append(f"cannot compare Git refs: {error}")

    summary = render_summary(cases, previous, affected_ids, errors)
    write_summary(arguments.summary, summary)
    if arguments.base and arguments.head:
        print(summary)
    elif errors:
        print(summary, file=sys.stderr)
    else:
        print(f"manual test catalog: PASS ({len(cases)} cases)")

    if errors:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
