"""Credential-free checks for Floor's shared source materialization."""

from pathlib import Path
import tempfile
import unittest

from check_shared_files import SHARED_FILES, check_shared_files, sync_shared_files


class SharedFilesTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for source, copies in SHARED_FILES.items():
            canonical = self.root / source
            canonical.parent.mkdir(parents=True, exist_ok=True)
            canonical.write_text(f"# {source}\n")
            for copy in copies:
                path = self.root / copy
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(canonical.read_bytes())
        self.source = next(iter(SHARED_FILES))
        self.copy = self.root / SHARED_FILES[self.source][0]

    def test_detects_stale_and_missing_copies(self):
        self.assertEqual(check_shared_files(self.root), [])
        self.copy.write_text("# stale\n")
        self.assertTrue(any("differs from" in error for error in check_shared_files(self.root)))
        self.copy.unlink()
        self.assertTrue(any("shared copy is missing" in error for error in check_shared_files(self.root)))

    def test_sync_replaces_symlinks_and_stale_copies_with_regular_files(self):
        self.copy.unlink()
        self.copy.symlink_to(self.root / self.source)
        self.assertTrue(any("omit symlinks" in error for error in check_shared_files(self.root)))
        stale = self.root / SHARED_FILES[self.source][1]
        stale.write_text("# stale\n")
        sync_shared_files(self.root)
        self.assertFalse(self.copy.is_symlink())
        self.assertEqual(check_shared_files(self.root), [])

    def test_rejects_unlisted_deployment_symlinks_but_ignores_test_and_provider_artifacts(self):
        for directory in ("tofu/modules/example/tests", "tofu/runtime/example/.terraform"):
            path = self.root / directory / "fixture.tofu"
            path.parent.mkdir(parents=True)
            path.symlink_to(self.root / self.source)
        self.assertEqual(check_shared_files(self.root), [])
        path = self.root / "tofu/runtime/example/new.tofu"
        path.symlink_to(self.root / self.source)
        self.assertTrue(any("new.tofu" in error for error in check_shared_files(self.root)))

    def test_sync_rejects_invalid_sources_before_modifying_copies(self):
        canonical = self.root / self.source
        canonical.unlink()
        canonical.symlink_to(self.copy)
        before = self.copy.read_bytes()
        with self.assertRaisesRegex(ValueError, "canonical source must be a regular file"):
            sync_shared_files(self.root)
        self.assertEqual(self.copy.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
