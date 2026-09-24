"""Fail closed before uploading the exact exported IPA. Never print profile data."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

BUNDLE = 'com.ansandy.moneysnap'
APPLE_LOGIN = 'com.apple.developer.applesignin'


def require(condition, label):
    if not condition:
        raise ValueError(label)


def validate(info, ent, profile, team, build):
    pe = profile.get('Entitlements', {})
    require(info.get('CFBundleIdentifier') == BUNDLE, 'bundle identifier mismatch')
    require(str(info.get('CFBundleVersion')) == build, 'build number mismatch')
    require(ent.get(APPLE_LOGIN) == ['Default'], 'signed Apple login entitlement missing or invalid')
    require('Default' in pe.get(APPLE_LOGIN, []), 'profile Apple login entitlement missing')
    require(ent.get('com.apple.developer.team-identifier') == team, 'signed team mismatch')
    require(profile.get('TeamIdentifier') == [team], 'profile team mismatch')
    require(pe.get('com.apple.developer.team-identifier') == team, 'profile entitlement team mismatch')
    app_id = ent.get('application-identifier', '')
    require(app_id.endswith('.' + BUNDLE) and app_id == pe.get('application-identifier'),
            'application identifier mismatch')
    require(ent.get('get-task-allow') is False and pe.get('get-task-allow') is False,
            'development debugging must be disabled')
    require(ent.get('beta-reports-active') is True, 'not a TestFlight distribution signature')
    require(not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'),
            'not an App Store distribution profile')


def command(*args):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(result.returncode == 0, 'signing inspection command failed: ' + args[0])
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--team', required=True)
    parser.add_argument('--build', required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    # Temporary extraction never includes user data; private material is not published.
    with tempfile.TemporaryDirectory(prefix='moneysnap-signing-') as tmp:
        root = Path(tmp)
        with zipfile.ZipFile(args.ipa) as package:
            require(all(not Path(n).is_absolute() and '..' not in Path(n).parts
                        for n in package.namelist()), 'unsafe IPA entry')
            package.extractall(root)
        apps = [path for path in (root / 'Payload').glob('*.app') if path.is_dir()]
        require(len(apps) == 1, 'expected exactly one application')
        app = apps[0]
        command('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
        # Apple-anchored distribution certificate, not an ad-hoc placeholder.
        command('/usr/bin/codesign', '--verify', '-R',
                'anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.4] exists', str(app))
        ent = plistlib.loads(command('/usr/bin/codesign', '-d', '--entitlements', ':-', str(app)))
        profile = plistlib.loads(command('/usr/bin/security', 'cms', '-D', '-i',
                                        str(app / 'embedded.mobileprovision')))
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        validate(info, ent, profile, args.team, args.build)
    digest = hashlib.sha256(args.ipa.read_bytes()).hexdigest()
    report = {'build': args.build, 'bundle': BUNDLE, 'appleLogin': 'Default',
              'signatureAndProfileValidated': True, 'sha256': digest}
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print('TestFlight signing validation passed; SHA-256: ' + digest)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        raise SystemExit('TestFlight upload blocked: ' + str(error))
