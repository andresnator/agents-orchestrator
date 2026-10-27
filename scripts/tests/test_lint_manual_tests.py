import argparse
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "lint-manual-tests.py"
MODULE_NAME = "manual_catalog_linter"
SPEC = importlib.util.spec_from_file_location(MODULE_NAME, SCRIPT_PATH)
linter = importlib.util.module_from_spec(SPEC)
sys.modules[MODULE_NAME] = linter
SPEC.loader.exec_module(linter)

CURRENT_PATH = "domains/common/plugins/current.ts"
UNCOVERED_PATH = "domains/common/plugins/uncovered.ts"
RETIRED_PATH = "domains/common/plugins/retired.ts"
BASE_REF = "fixture-base"
HEAD_REF = "fixture-head"


def catalog_case(domain, name="CURRENT", path=None):
    target = path or f"domains/{domain}/plugins/current.ts"
    return f"""### MT-{domain.upper()}-{name}

- **Title:** Validate {domain} {name.lower()} behavior
- **Coverage key:** `{domain}/plugin/{name.lower()}`
- **Applies to:** `{target}`
- **Preconditions:** Use a disposable fixture
- **Steps:**
  1. Inspect the selected component.
  2. Compare it with its documented contract.
- **Expected result:** The component matches its contract
- **Cleanup:** Discard the fixture
"""


class ManualCatalogTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="manual-catalog-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for domain, relative in linter.CATALOG_PATHS.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(catalog_case(domain), encoding="utf-8")
        for domain in linter.DOMAIN_NAMES:
            (self.root / f"domains/{domain}/README.md").write_text(
                "[Manual tests](manual-tests.md)\n", encoding="utf-8"
            )
        index = self.root / "docs/manual-testing.md"
        index.write_text(
            index.read_text(encoding="utf-8") + "\n".join(
                f"[{domain}](../domains/{domain}/manual-tests.md)"
                for domain in linter.DOMAIN_NAMES
            ),
            encoding="utf-8",
        )
        for name in ("README.md", "CONTRIBUTING.md"):
            (self.root / name).write_text(
                "[Manual tests](docs/manual-testing.md)\n", encoding="utf-8"
            )

    def run_check(self, diff, previous=None):
        arguments = argparse.Namespace(base=BASE_REF, head=HEAD_REF, summary=None)
        output = io.StringIO()
        with (
            patch.object(linter, "REPOSITORY_ROOT", self.root),
            patch.object(linter, "parse_arguments", return_value=arguments),
            patch.object(linter, "git_output", return_value=diff),
            patch.object(linter, "read_git_file", side_effect=lambda ref, path: (previous or {}).get(path)),
            contextlib.redirect_stdout(output),
        ):
            result = linter.main()
        return result, output.getvalue()

    def test_shouldPassWhenUncoveredRuntimeIsDeleted(self):
        # Given
        diff = f"D\t{RETIRED_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 0, summary)
        self.assertIn("**PASS**", summary)

    def test_shouldReportRemovedCaseWhenItsRuntimeIsDeleted(self):
        # Given
        previous = {
            Path("domains/common/manual-tests.md"): catalog_case("common")
            + catalog_case("common", "RETIRED", RETIRED_PATH)
        }

        # When
        result, summary = self.run_check(f"D\t{RETIRED_PATH}\n", previous)

        # Then
        self.assertEqual(result, 0, summary)
        self.assertIn("MT-COMMON-RETIRED", summary)
        self.assertIn("(removed)", summary)

    def test_shouldRejectWhenAddedRuntimeHasNoCoverage(self):
        # Given
        diff = f"A\t{UNCOVERED_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 1, summary)
        self.assertIn(f"runtime artifact has no manual coverage: {UNCOVERED_PATH}", summary)

    def test_shouldRejectWhenModifiedRuntimeHasNoCoverage(self):
        # Given
        diff = f"M\t{UNCOVERED_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 1, summary)
        self.assertIn(f"runtime artifact has no manual coverage: {UNCOVERED_PATH}", summary)

    def test_shouldPassWhenModifiedRuntimeHasCoverage(self):
        # Given
        diff = f"M\t{CURRENT_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 0, summary)
        self.assertIn("MT-COMMON-CURRENT", summary)

    def test_shouldPassWhenOnlyRenameDestinationHasCoverage(self):
        # Given
        diff = f"R100\t{RETIRED_PATH}\t{CURRENT_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 0, summary)

    def test_shouldPassWhenSharedSkillDeclarationMatchesBodyCoverage(self):
        # Given
        (self.root / "skills/shared").mkdir(parents=True)
        (self.root / "domains/common/skills").mkdir(parents=True, exist_ok=True)
        (self.root / "domains/common/skills/shared").symlink_to("../../../skills/shared")
        catalog = self.root / "domains/common/manual-tests.md"
        catalog.write_text(catalog_case("common") + catalog_case("common", "SHARED", "skills/shared/**"), encoding="utf-8")

        # When
        result, summary = self.run_check("A\tdomains/common/skills/shared\n")

        # Then
        self.assertEqual(result, 0, summary)
        self.assertIn("MT-COMMON-SHARED", summary)

    def test_shouldRejectWhenRenameDestinationHasNoCoverage(self):
        # Given
        diff = f"R100\t{CURRENT_PATH}\t{UNCOVERED_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 1, summary)
        self.assertIn(f"runtime artifact has no manual coverage: {UNCOVERED_PATH}", summary)

    def test_shouldRejectWhenCopyDestinationHasNoCoverage(self):
        # Given
        diff = f"C100\t{CURRENT_PATH}\t{UNCOVERED_PATH}\n"

        # When
        result, summary = self.run_check(diff)

        # Then
        self.assertEqual(result, 1, summary)
        self.assertIn(f"runtime artifact has no manual coverage: {UNCOVERED_PATH}", summary)

    def test_shouldRejectWhenActiveDomainCatalogIsMissing(self):
        # Given
        missing = self.root / "domains/common/manual-tests.md"
        missing.unlink()

        # When
        result, summary = self.run_check("")

        # Then
        self.assertEqual(result, 1, summary)
        self.assertIn("missing catalog document: domains/common/manual-tests.md", summary)


if __name__ == "__main__":
    unittest.main()
