import copy
import unittest

from verify_testflight_signing import validate


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
