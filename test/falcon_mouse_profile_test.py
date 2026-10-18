#!/usr/bin/env python3
"""Check the Falcon/X11 boundary and the native saved preference, not its cache."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FalconMouseProfileTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.log = self.home / 'calls.jsonl'
        hostname = self.bin / 'hostname'
        hostname.write_text('#!/bin/sh\nprintf "%s\\n" "$TEST_HOST"\n')
        hostname.chmod(0o755)
        writer = self.bin / 'kwriteconfig6'
        writer.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                          'with open(os.environ["CALL_LOG"],"a") as f:\n'
                          ' f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                          'sys.exit(int(os.environ.get("FAIL_WRITE", "0")))\n')
        writer.chmod(0o755)
        self.env = {'HOME': str(self.home), 'PATH': str(self.bin) + ':' + os.environ['PATH'],
                    'CALL_LOG': str(self.log), 'TEST_HOST': 'falcon', 'DISPLAY': ':0',
                    'XDG_SESSION_TYPE': 'x11'}

    def run_helper(self, **values):
        return subprocess.run(['zsh', '-f', str(ROOT / 'bin/configure-falcon-mouse')],
                              env=self.env | values, capture_output=True, text=True)

    def test_explicit_preference_on_repeated_startup_without_device_dependency(self):
        for _ in range(2):
            result = self.run_helper()
            self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        expected = ['--file', 'kcminputrc', '--group', 'Mouse', '--key',
                    'XLbInptAccelProfileFlat', '--type', 'bool', 'false']
        self.assertEqual(calls, [expected, expected])
        # No xinput, device IDs, global speed/scroll reset, or private config parsing

    def test_other_hosts_and_non_x11_sessions_are_noops(self):
        for values in [dict(TEST_HOST='owl'), dict(TEST_HOST='falcon-other'),
                       dict(DISPLAY=''), dict(WAYLAND_DISPLAY='wayland-0'),
                       dict(XDG_SESSION_TYPE='wayland')]:
            result = self.run_helper(**values)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(self.log.exists())

    def test_write_failure_is_visible(self):
        self.assertEqual(self.run_helper(FAIL_WRITE='7').returncode, 7)

    def test_session_orders_preference_before_kde_initialization(self):
        name = 'falcon-mouse-profile.service'
        service = (ROOT / '.config/systemd/user' / name).read_text()
        self.assertIn('Before=plasma-kcminit.service plasma-ksmserver.service', service)
        self.assertIn('PartOf=xmonad-session.target', service)
        self.assertIn('ConditionHost=falcon', service)
        self.assertIn('ExecStart=%h/bin/configure-falcon-mouse', service)
        link = ROOT / '.config/systemd/user/xmonad-session.target.wants' / name
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), (ROOT / '.config/systemd/user' / name).resolve())
        self.assertFalse((ROOT / '.config/systemd/user/sway-session.target.wants' / name).exists())


if __name__ == '__main__':
    unittest.main()
