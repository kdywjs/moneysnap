import copy
import unittest
from unittest.mock import patch
import os
import subprocess
import tempfile
from pathlib import Path

from verify_testflight_signing import validate, extract_ipa, command


class DiagnosticTests(unittest.TestCase):
    def test_failure_reports_stage_and_allowlisted_category_only(self):
        result = subprocess.CompletedProcess([], 1, b'',
                    b'/private/sensitive-path: a sealed resource is missing or invalid')
        with patch('verify_testflight_signing.subprocess.run', return_value=result):
            with self.assertRaises(ValueError) as caught:
                command('/usr/bin/codesign', '--verify', stage='bundle integrity')
        self.assertEqual(str(caught.exception),
                         'bundle integrity failed: a sealed resource is missing or invalid')

    def test_unknown_error_does_not_leak_output(self):
        result = subprocess.CompletedProcess([], 1, b'', b'sensitive details')
        with patch('verify_testflight_signing.subprocess.run', return_value=result):
            with self.assertRaisesRegex(ValueError, '^inspection failed: unclassified$'):
                command('/usr/bin/codesign', '--verify')


@unittest.skipUnless(os.path.exists('/usr/bin/ditto'), 'macOS archive metadata test')
class ExtractionTests(unittest.TestCase):
    def test_preserves_executable_mode_and_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = root / 'Payload' / 'Fixture.app'
            app.mkdir(parents=True)
            binary = app / 'Fixture'
            binary.write_bytes(b'fixture')
            binary.chmod(0o755)
            (app / 'linked').symlink_to('Fixture')
            ipa = root / 'fixture.ipa'
            subprocess.run(['/usr/bin/ditto', '-c', '-k', '--keepParent',
                            str(root / 'Payload'), str(ipa)], check=True)
            extracted = root / 'extracted'
            extract_ipa(ipa, extracted)
            actual = extracted / 'Payload' / 'Fixture.app'
            self.assertEqual((actual / 'Fixture').stat().st_mode & 0o777, 0o755)
            self.assertTrue((actual / 'linked').is_symlink())


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.team = 'ABCDEFGHIJ'
        self.bundle = 'com.ansandy.moneysnap'
        self.info = {'CFBundleIdentifier': self.bundle, 'CFBundleVersion': '22'}
        self.ent = {'com.apple.developer.applesignin': ['Default'],
                    'application-identifier': self.team + '.' + self.bundle,
                    'com.apple.developer.team-identifier': self.team,
                    'get-task-allow': False, 'beta-reports-active': True}
        self.profile = {'TeamIdentifier': [self.team], 'Entitlements': copy.deepcopy(self.ent)}

    def test_valid_distribution(self):
        validate(self.info, self.ent, self.profile, self.team, '22')

    def test_missing_apple_login_in_signature(self):
        del self.ent['com.apple.developer.applesignin']
        with self.assertRaisesRegex(ValueError, 'signed Apple login'):
            validate(self.info, self.ent, self.profile, self.team, '22')

    def test_missing_apple_login_in_profile(self):
        del self.profile['Entitlements']['com.apple.developer.applesignin']
        with self.assertRaisesRegex(ValueError, 'profile Apple login'):
            validate(self.info, self.ent, self.profile, self.team, '22')

    def test_identity_and_distribution_mismatches(self):
        for key, value in [('application-identifier', 'OTHER.app'),
                           ('com.apple.developer.team-identifier', 'OTHER'),
                           ('get-task-allow', True), ('beta-reports-active', False)]:
            with self.subTest(key=key):
                ent = {**self.ent, key: value}
                with self.assertRaises(ValueError):
                    validate(self.info, ent, self.profile, self.team, '22')

    def test_wrong_build_and_bundle(self):
        for info in [{**self.info, 'CFBundleVersion': '21'},
                     {**self.info, 'CFBundleIdentifier': 'other.app'}]:
            with self.assertRaises(ValueError):
                validate(info, self.ent, self.profile, self.team, '22')

    def test_wrong_profile_identity_or_device_distribution(self):
        for key, value in [('TeamIdentifier', ['OTHER']),
                           ('ProvisionedDevices', ['test-device']), ('ProvisionsAllDevices', True)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(self.info, self.ent, {**self.profile, key: value}, self.team, '22')
        for key, value in [('application-identifier', 'OTHER.*'),
                           ('com.apple.developer.team-identifier', 'OTHER'), ('get-task-allow', True)]:
            profile = {**self.profile, 'Entitlements': {**self.ent, key: value}}
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(self.info, self.ent, profile, self.team, '22')


if __name__ == '__main__':
    unittest.main()
