"""Credential-free tests for live application membership checks."""

import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import Mock


spec = importlib.util.spec_from_file_location(
    "verify_application_access", Path(__file__).with_name("verify-application-access.py")
)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class MembershipTests(unittest.TestCase):
    def test_membership_tracks_verified_enrollment_not_saved_user_ids(self):
        email = "test+local@example.com"
        group = {"id": "admins", "name": "factory: Authentik Admins", "is_superuser": True, "users": []}
        verified = {"pk": 42, "is_active": True, "email": email, "attributes": {"osinfra_google_email": email}}
        unverified = {**verified, "pk": 43, "attributes": {}}
        for users, members, mapped, error in (
            ([], [], [group["name"]], None),
            ([verified, unverified], [42], [group["name"]], None),
            ([verified], [], [group["name"]], "membership differs"),
            ([unverified], [43], [group["name"]], "membership differs"),
            ([], [], [], "restore access"),
        ):
            with self.subTest(members=members, mapped=mapped, error=error):
                responses = {
                    "propertymappings/all/google/test/": {"successful": True, "result": json.dumps({"groups": mapped})},
                    "core/users/?email=test%2Blocal%40example.com": {"results": users},
                    "core/groups/admins/": {**group, "users": members},
                }
                api = Mock(side_effect=lambda path, payload=None: responses[path])
                if error:
                    with self.assertRaisesRegex(ValueError, error):
                        verifier.verify_memberships(api, [group], "google", email)
                else:
                    verifier.verify_memberships(api, [group], "google", email)
