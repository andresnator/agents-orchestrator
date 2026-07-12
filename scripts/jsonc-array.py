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


def add_value(text: str, root: Node, array: Node | None, property_name: str, value: str) -> str:
    encoded = json.dumps(value, ensure_ascii=False)
    if array is None:
        close = root.end - 1
        has_properties = bool(root.properties)
        prefix = "," if has_properties and not has_trailing_comma(text, root) else ""
        insertion = f'{prefix}\n  {json.dumps(property_name)}: [{encoded}]\n'
        return text[:close] + insertion + text[close:]

    close = array.end - 1
    if not array.items:
        return text[:close] + f"\n    {encoded}\n  " + text[close:]
    last = array.items[-1]
    prefix = "" if has_comma_between(text, last.end, close) else ","
    return text[:close] + f"{prefix}\n    {encoded}\n  " + text[close:]


def remove_value(text: str, array: Node, item: Node) -> str:
    assert array.items is not None
    if len(array.items) == 1:
        return text[: item.start] + text[item.end :]
    index = array.items.index(item)
    if index < len(array.items) - 1:
        next_item = array.items[index + 1]
        comma = text.find(",", item.end, next_item.start)
        if comma == -1:
            return text[: item.start] + text[item.end :]
        return text[: item.start] + text[item.end : comma] + text[comma + 1 :]
    previous = array.items[index - 1]
    comma = text.rfind(",", previous.end, item.start)
    if comma == -1:
        return text[: item.start] + text[item.end :]
    return text[:comma] + text[comma + 1 : item.start] + text[item.end :]


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
