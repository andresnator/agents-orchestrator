#!/usr/bin/env python3
"""Targeted JSONC string-array editor used before OpenCode plugin dependencies load."""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Token:
    kind: str
    value: object
    start: int
    end: int


@dataclass
class Node:
    kind: str
    start: int
    end: int
    value: object = None
    properties: dict[str, "Node"] | None = None
    items: list["Node"] | None = None


class JsoncError(ValueError):
    pass


class Parser:
    def __init__(self, text: str) -> None:
        self.text = text
        self.tokens = tokenize(text)
        self.index = 0

    def parse(self) -> Node:
        node = self.parse_value()
        if self.index != len(self.tokens):
            raise JsoncError(f"unexpected token at offset {self.tokens[self.index].start}")
        return node

    def parse_value(self) -> Node:
        token = self.take()
        if token.kind == "{":
            return self.parse_object(token)
        if token.kind == "[":
            return self.parse_array(token)
        if token.kind in {"string", "number", "literal"}:
            return Node(token.kind, token.start, token.end, token.value)
        raise JsoncError(f"expected value at offset {token.start}")

    def parse_object(self, opening: Token) -> Node:
        properties: dict[str, Node] = {}
        if self.peek("}"):
            closing = self.take()
            return Node("object", opening.start, closing.end, properties=properties)
        while True:
            key = self.take()
            if key.kind != "string" or not isinstance(key.value, str):
                raise JsoncError(f"expected object key at offset {key.start}")
            self.expect(":")
            properties[key.value] = self.parse_value()
            if self.peek("}"):
                closing = self.take()
                return Node("object", opening.start, closing.end, properties=properties)
            self.expect(",")
            if self.peek("}"):
                closing = self.take()
                return Node("object", opening.start, closing.end, properties=properties)

    def parse_array(self, opening: Token) -> Node:
        items: list[Node] = []
        if self.peek("]"):
            closing = self.take()
            return Node("array", opening.start, closing.end, items=items)
        while True:
            items.append(self.parse_value())
            if self.peek("]"):
                closing = self.take()
                return Node("array", opening.start, closing.end, items=items)
            self.expect(",")
            if self.peek("]"):
                closing = self.take()
                return Node("array", opening.start, closing.end, items=items)

    def take(self) -> Token:
        if self.index >= len(self.tokens):
            raise JsoncError("unexpected end of input")
        token = self.tokens[self.index]
        self.index += 1
        return token

    def expect(self, kind: str) -> None:
        token = self.take()
        if token.kind != kind:
            raise JsoncError(f"expected '{kind}' at offset {token.start}")

    def peek(self, kind: str) -> bool:
        return self.index < len(self.tokens) and self.tokens[self.index].kind == kind


def tokenize(text: str) -> list[Token]:
    tokens: list[Token] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char.isspace():
            index += 1
            continue
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline == -1 else newline + 1
            continue
        if text.startswith("/*", index):
            closing = text.find("*/", index + 2)
            if closing == -1:
                raise JsoncError(f"unterminated comment at offset {index}")
            index = closing + 2
            continue
        if char in "{}[]: ,":
            if char != " ":
                tokens.append(Token(char, char, index, index + 1))
            index += 1
            continue
        if char == '"':
            end = scan_string(text, index)
            try:
                value = json.loads(text[index:end])
            except json.JSONDecodeError as error:
                raise JsoncError(f"invalid string at offset {index}: {error.msg}") from error
            tokens.append(Token("string", value, index, end))
            index = end
            continue
        end = index
        while end < len(text) and text[end] not in "{}[]:,/\" \t\r\n":
            end += 1
        raw = text[index:end]
        if raw in {"true", "false", "null"}:
            value = {"true": True, "false": False, "null": None}[raw]
            tokens.append(Token("literal", value, index, end))
        else:
            try:
                value = json.loads(raw)
            except json.JSONDecodeError as error:
                raise JsoncError(f"invalid token at offset {index}") from error
            tokens.append(Token("number", value, index, end))
        index = end
    return tokens


def scan_string(text: str, start: int) -> int:
    index = start + 1
    escaped = False
    while index < len(text):
        char = text[index]
        if escaped:
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == '"':
            return index + 1
        index += 1
    raise JsoncError(f"unterminated string at offset {start}")


def edit(text: str, property_name: str, value: str, action: str) -> tuple[str, bool]:
    root = Parser(text).parse()
    if root.kind != "object" or root.properties is None:
        raise JsoncError("JSONC root must be an object")
    array = root.properties.get(property_name)
    if array is not None and (array.kind != "array" or array.items is None):
        raise JsoncError(f"property '{property_name}' must be an array")

    matching = [] if array is None else [item for item in array.items if item.kind == "string" and item.value == value]
    if action == "has":
        return text, bool(matching)
    if action == "add":
        if matching:
            return text, False
        return add_value(text, root, array, property_name, value), True
    if action == "remove":
        if not matching or array is None:
            return text, False
        return remove_value(text, array, matching[0]), True
    raise JsoncError(f"unsupported action '{action}'")


def trim_before(text: str, close: int, floor: int) -> int:
    """Start of the whitespace run that ends at `close`, never crossing `floor`.

    Insertions carry their own newline and indent, so whatever whitespace the previous
    formatting left before the closing bracket has to go — otherwise the two stack and the
    array gains a blank line on every edit.
    """
    while close > floor and text[close - 1] in " \t\r\n":
        close -= 1
    return close


def add_value(text: str, root: Node, array: Node | None, property_name: str, value: str) -> str:
    encoded = json.dumps(value, ensure_ascii=False)
    if array is None:
        close = root.end - 1
        prefix = "," if root.properties and not has_trailing_comma(text, root) else ""
        insertion = f'{prefix}\n  {json.dumps(property_name)}: [\n    {encoded}\n  ]\n'
        return text[: trim_before(text, close, root.start + 1)] + insertion + text[close:]

    close = array.end - 1
    if array.items:
        # The separator belongs right after the last item; on the new entry's own line it would
        # land on the blank line before ']'.
        last = array.items[-1]
        if not has_comma_between(text, last.end, close):
            text = text[: last.end] + "," + text[last.end :]
            close += 1
    return text[: trim_before(text, close, array.start + 1)] + f"\n    {encoded}\n  " + text[close:]


def separator_comma(text: str, array: Node, item: Node, close_bracket: int) -> int | None:
    """Index of the comma that separates `item` from the rest of the array, if there is one."""
    assert array.items is not None
    items = array.items
    index = items.index(item)
    if index < len(items) - 1:
        comma = text.find(",", item.end, items[index + 1].start)
        return None if comma == -1 else comma

    probe = item.end
    while probe < close_bracket and text[probe] in " \t\r\n":
        probe += 1
    if probe < close_bracket and text[probe] == ",":
        return probe
    if index > 0:
        comma = text.rfind(",", items[index - 1].end, item.start)
        return None if comma == -1 else comma
    return None


def remove_value(text: str, array: Node, item: Node) -> str:
    """Delete one item, its separator comma, and the whitespace it occupied.

    Removal has to leave the array in the exact shape add_value would produce, because
    `install` is a remove-then-add sync: whitespace left inside the brackets makes the next
    add insert its own newline after it, and the array grows one blank line per install — the
    drift that put 22 blank entries in a real tui.json. Any non-whitespace inside the brackets
    (a comment) stops the collapse, so it survives with ']' still on its own line.
    """
    assert array.items is not None
    open_bracket, close_bracket = array.start + 1, array.end - 1
    start, end = item.start, item.end

    # Cut the separator on its own, never as part of the item's span: a comment can sit between
    # the two ("./foreign.tsx", // keep me), and it has to survive.
    comma = separator_comma(text, array, item, close_bracket)
    if comma is not None:
        text = text[:comma] + text[comma + 1 :]
        close_bracket -= 1
        if comma < start:
            start -= 1
            end -= 1

    while start > open_bracket and text[start - 1] in " \t\r\n":
        start -= 1
    # Only a now-empty array collapses forward, to '[]'; with items left, the newline before
    # ']' is exactly what add_value expects to find.
    if len(array.items) == 1 and start == open_bracket:
        while end < close_bracket and text[end] in " \t\r\n":
            end += 1
    return text[:start] + text[end:]


def has_comma_between(text: str, start: int, end: int) -> bool:
    return any(token.kind == "," for token in tokenize(text[start:end]))


def has_trailing_comma(text: str, node: Node) -> bool:
    if not node.properties:
        return False
    last = max(node.properties.values(), key=lambda value: value.end)
    return has_comma_between(text, last.end, node.end - 1)


def main() -> int:
    if len(sys.argv) != 5:
        print("usage: jsonc-array.py <has|add|remove> <file> <property> <value>", file=sys.stderr)
        return 2
    action, file_name, property_name, value = sys.argv[1:]
    file = Path(file_name)
    text = file.read_text() if file.exists() else "{}\n"
    try:
        rendered, changed = edit(text, property_name, value, action)
    except (OSError, JsoncError) as error:
        print(f"error: {file}: {error}", file=sys.stderr)
        return 2
    if action == "has":
        return 0 if changed else 1
    sys.stdout.write(rendered)
    return 0 if changed else 3


if __name__ == "__main__":
    raise SystemExit(main())
