import base64
import unittest
from pathlib import Path

from release_rules import (
    ReleaseValidationError,
    assert_app_version_constants,
    assert_build_is_newer,
    assert_feed_url,
    assert_public_key,
    assert_tag_matches_project,
    enclosure_error,
    parse_sign_update_output,
    read_project_versions,
    upsert_appcast,
)


class ReleaseRulesTests(unittest.TestCase):
    def test_project_versions_must_agree_with_the_tag(self):
        project = """
        MARKETING_VERSION = 0.2.0;
        CURRENT_PROJECT_VERSION = 2;
        MARKETING_VERSION = 0.2.0;
        CURRENT_PROJECT_VERSION = 2;
        """
        version, build = read_project_versions(project)
        self.assertEqual((version, build), ("0.2.0", "2"))
        assert_tag_matches_project("v0.2.0", version)
        swift = '''
        static let establishedMarketingVersion = "0.2.0"
        static let establishedBuildNumber = "2"
        '''
        assert_app_version_constants(swift, version, build)
        with self.assertRaises(ReleaseValidationError):
            assert_tag_matches_project("v0.1.0", version)

    def test_duplicate_and_older_builds_are_rejected(self):
        assert_build_is_newer("2", ["1"])
        with self.assertRaises(ReleaseValidationError):
            assert_build_is_newer("1", ["1"])
        with self.assertRaises(ReleaseValidationError):
            read_project_versions("MARKETING_VERSION = 0.1.0;\nMARKETING_VERSION = 0.2.0;")

    def test_feed_and_public_key(self):
        assert_feed_url("https://updates.desktopstudio.app/appcast.xml")
        with self.assertRaises(ReleaseValidationError):
            assert_feed_url("https://example.com/appcast.xml")
        with self.assertRaises(ReleaseValidationError):
            assert_feed_url("http://updates.desktopstudio.app/appcast.xml")
        key = base64.b64encode(b"k" * 32).decode("ascii")
        assert_public_key(key)
        with self.assertRaises(ReleaseValidationError):
            assert_public_key(base64.b64encode(b"k" * 16).decode("ascii"))

    def test_appcast_uses_a_versioned_signed_archive_and_rejects_duplicates(self):
        signature = base64.b64encode(b"s" * 64).decode("ascii")
        url = "https://github.com/desktop-studio/DesktopStudio/releases/download/v0.2.0/DesktopStudio-0.2.0.zip"
        xml = upsert_appcast(
            None,
            short_version="0.2.0",
            build="2",
            enclosure_url=url,
            ed_signature=signature,
            length=1200,
            title="Version 0.2.0",
            published_at=1_700_000_000,
        )
        self.assertIn("sparkle:edSignature", xml)
        self.assertIn("/releases/download/v0.2.0/", xml)
        self.assertIn("14.0", xml)
        with self.assertRaises(ReleaseValidationError):
            upsert_appcast(
                xml,
                short_version="0.2.0",
                build="3",
                enclosure_url=url,
                ed_signature=signature,
                length=1200,
                title="Version 0.2.0 again",
                published_at=1_700_000_100,
            )
        self.assertIsNotNone(
            enclosure_error(
                "https://github.com/desktop-studio/DesktopStudio/releases/latest/download/DesktopStudio-0.2.0.zip",
                "0.2.0",
                signature,
                1200,
            )
        )

    def test_sign_update_output(self):
        signature = base64.b64encode(b"s" * 64).decode("ascii")
        parsed, length = parse_sign_update_output(
            f'sparkle:edSignature="{signature}" length="4312"\n'
        )
        self.assertEqual(parsed, signature)
        self.assertEqual(length, 4312)
        with self.assertRaises(ReleaseValidationError):
            parse_sign_update_output("no signature")

    def test_release_workflow_is_not_on_every_push(self):
        workflow_path = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "release.yml"
        workflow = workflow_path.read_text(encoding="utf-8")
        trigger, _, _ = workflow.partition("jobs:")
        self.assertNotIn("branches:", trigger)
        self.assertIn("tags:", trigger)
        self.assertIn("workflow_dispatch:", trigger)
        self.assertNotIn("curl | sh", workflow)
        self.assertNotIn("echo \"$SPARKLE_EDDSA_PRIVATE_KEY\"", workflow)


if __name__ == "__main__":
    unittest.main()
