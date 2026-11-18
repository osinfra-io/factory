"""Verify local test identity selection from Git configuration."""

import os
from pathlib import Path
import subprocess
import unittest


SHARED = Path(__file__).with_name("shared.sh")


class LocalTestUserEmailTests(unittest.TestCase):
    def test_uses_git_email_for_local_test_identity(self):
        env = os.environ.copy()
        env.pop("TF_VAR_local_test_user_email", None)
        env.update({
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "user.email",
            "GIT_CONFIG_VALUE_0": "git-user@example.test",
        })
        result = subprocess.run(
            [
                "bash",
                "-c",
                'source "$1"; set_local_test_user_email; '
                'printf "%s" "$TF_VAR_local_test_user_email"',
                "test",
                str(SHARED),
            ],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "git-user@example.test")


if __name__ == "__main__":
    unittest.main()
