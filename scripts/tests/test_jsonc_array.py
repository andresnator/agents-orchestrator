import importlib.util
import json
from pathlib import Path
import sys
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "jsonc-array.py"
SPEC = importlib.util.spec_from_file_location("jsonc_editor", SCRIPT)
editor = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = editor
SPEC.loader.exec_module(editor)
DEPTH_PATH = "experimental.subagent_depth"


class JsoncPathTests(unittest.TestCase):
    def test_shouldPreserveCommentsAndNeighborsWhenSettingNestedDepth(self):
        # Given
        source = '{"experimental": {"subagent_depth": 3, // depth\n "other": true,}, "default_agent": "custom"}'
        # When
        rendered, changed = editor.set_scalar_path(source, DEPTH_PATH, "1")
        # Then
        self.assertTrue(changed)
        self.assertEqual(rendered, source.replace('"subagent_depth": 3', '"subagent_depth": 1'))
        self.assertEqual(editor.get_path(rendered, DEPTH_PATH), ("1", True))

    def test_shouldCreateMissingParentsWhenSettingNestedDepth(self):
        # Given
        source = '{"default_agent":"custom" // keep\n}'
        # When
        rendered, changed = editor.set_scalar_path(source, DEPTH_PATH, "1")
        # Then
        self.assertTrue(changed)
        self.assertIn("// keep", rendered)
        self.assertEqual(editor.get_path(rendered, "experimental"), ('{"subagent_depth":1}', True))
        self.assertEqual(editor.set_scalar_path(rendered, DEPTH_PATH, "1"), (rendered, False))

    def test_shouldKeepExistingEmptyParentWhenRemovingNestedDepth(self):
        # Given
        installed, _ = editor.set_scalar_path('{"experimental":{},"default_agent":"custom"}', DEPTH_PATH, "1")
        # When
        restored, changed = editor.remove_path(installed, DEPTH_PATH)
        # Then
        self.assertTrue(changed)
        self.assertEqual(json.loads(restored), {"experimental": {}, "default_agent": "custom"})

    def test_shouldPruneOnlyCreatedEmptyParentWhenRemovingNestedDepth(self):
        # Given
        installed, _ = editor.set_scalar_path('{"default_agent":"custom"}', DEPTH_PATH, "1")
        # When
        restored, changed = editor.remove_path(installed, DEPTH_PATH, prune_empty=True)
        # Then
        self.assertTrue(changed)
        self.assertEqual(json.loads(restored), {"default_agent": "custom"})

    def test_shouldPreserveForeignKeysWhenPruningNestedDepth(self):
        # Given
        source = '{"experimental":{"subagent_depth":1,"other":true}}'
        # When
        restored, _ = editor.remove_path(source, DEPTH_PATH, prune_empty=True)
        # Then
        self.assertEqual(json.loads(restored), {"experimental": {"other": True}})

    def test_shouldPreserveAddedCommentsWhenPruningEmptyParent(self):
        # Given
        source = '{"experimental":{"subagent_depth":1 // keep\n}}'
        # When
        restored, _ = editor.remove_path(source, DEPTH_PATH, prune_empty=True)
        # Then
        self.assertIn("// keep", restored)
        self.assertEqual(editor.get_path(restored, "experimental"), ("{}", True))

    def test_shouldRejectNonObjectParentsBeforeMutation(self):
        for value in ["null", "false", "3", '"invalid"', "[]"]:
            with self.subTest(value=value):
                # Given
                source = '{"experimental":' + value + "}"
                # When / Then
                with self.assertRaises(editor.JsoncError):
                    editor.set_scalar_path(source, DEPTH_PATH, "1")

    def test_shouldRejectEmptyPathSegmentsWhenReadingOrEditing(self):
        for path in ["", ".depth", "depth.", "experimental..depth"]:
            with self.subTest(path=path):
                # Given / When / Then
                with self.assertRaises(editor.JsoncError):
                    editor.get_path("{}", path)

    def test_shouldKeepLiteralDotsWhenUsingLegacyScalarApi(self):
        # Given
        source = '{"literal.depth":3}'
        # When
        rendered, _ = editor.set_scalar(source, "literal.depth", "1")
        # Then
        self.assertEqual(json.loads(rendered), {"literal.depth": 1})
        self.assertEqual(editor.get_scalar(rendered, "literal.depth"), ("1", True))

    def test_shouldLeaveMissingPathsUnchangedWhenRemoving(self):
        # Given
        source = '{"experimental":{"other":true}}'
        # When / Then
        self.assertEqual(editor.remove_path(source, DEPTH_PATH, prune_empty=True), (source, False))
        self.assertEqual(editor.get_path(source, DEPTH_PATH), ("", False))


if __name__ == "__main__":
    unittest.main()
