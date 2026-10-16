#!/usr/bin/env python3
"""Exercise the real zsh helper with isolated manager/activation command doubles."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GraphicalEnvironmentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / 'lib').mkdir()
        shutil.copy(ROOT / 'lib/session-vars.sh', self.home / 'lib/session-vars.sh')
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.log = self.home / 'calls.jsonl'
        mock = self.bin / 'mock'
        mock.write_text('#!/usr/bin/env python3\n'
                        'import json,os,sys\n'
                        'with open(os.environ["CALL_LOG"],"a") as f:\n'
                        ' f.write(json.dumps([os.path.basename(sys.argv[0]),sys.argv[1:],'
                        '{k:os.environ.get(k) for k in sys.argv[1:] if "=" not in k}])+"\\n")\n'
                        'sys.exit(1 if os.environ.get("FAIL_COMMAND") in [os.path.basename(sys.argv[0])] + sys.argv[1:] else 0)\n')
        mock.chmod(0o755)
        for name in ('systemctl', 'dbus-update-activation-environment'):
            (self.bin / name).symlink_to(mock)
        self.env = {'HOME': str(self.home), 'PATH': str(self.bin) + ':' + os.environ['PATH'],
                    'CALL_LOG': str(self.log), 'RUBYLIB': '/runtime/ruby',
                    'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus',
                    'PRIVATE_TEST_TOKEN': 'must-not-be-imported'}

    def run_helper(self, **values):
        return subprocess.run(['zsh', '-f', str(ROOT / 'bin/reset-systemd-environment')],
                              env=self.env | values, capture_output=True, text=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_x11_wayland_and_repeated_session_transitions(self):
        manager = {'DISPLAY': ':old', 'WAYLAND_DISPLAY': 'old-wayland', 'XAUTHORITY': '/old'}
        activation = manager.copy()
        sessions = [dict(DISPLAY=':0', XAUTHORITY='/current auth', XDG_SESSION_TYPE='x11'),
                    dict(WAYLAND_DISPLAY='wayland-1', SWAYSOCK='/run/sway.sock', XDG_SESSION_TYPE='wayland'),
                    dict(DISPLAY=':2', XAUTHORITY='/new auth', XDG_SESSION_TYPE='x11')]
        for session in sessions + sessions[-1:]:
            self.log.unlink(missing_ok=True)
            result = self.run_helper(**session)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = self.calls()
            self.assertEqual([c[0] for c in calls], ['systemctl', 'systemctl', 'dbus-update-activation-environment', 'systemctl'])
            self.assertEqual(calls[0][1][:2], ['--user', 'unset-environment'])
            for name in calls[0][1][2:]:
                manager.pop(name, None)
            self.assertEqual(calls[1][1][:2], ['--user', 'import-environment'])
            self.assertGreater(len(calls[1][1]), 2)  # Never fall back to whole-environment import
            manager.update({name: calls[1][2][name] for name in calls[1][1][2:]})
            updates = dict(value.split('=', 1) for value in calls[2][1])
            activation.update(updates)
            for name in ('DISPLAY', 'XAUTHORITY', 'WAYLAND_DISPLAY', 'SWAYSOCK', 'XDG_SESSION_TYPE'):
                self.assertEqual(manager.get(name), session.get(name))
                self.assertEqual(activation[name], session.get(name, ''))
            self.assertNotIn('DBUS_SESSION_BUS_ADDRESS', updates)
            self.assertNotIn('PRIVATE_TEST_TOKEN', updates)
            self.assertNotIn('PRIVATE_TEST_TOKEN', calls[1][1])
            self.assertEqual(manager['RUBYLIB'], '/runtime/ruby')
            self.assertEqual(manager['PATH'], self.env['PATH'])
            self.assertEqual(calls[-1][1], ['--user', 'reset-failed'])

    def test_sync_failures_stop_startup(self):
        for command, count in [('unset-environment', 1), ('import-environment', 2),
                               ('dbus-update-activation-environment', 3)]:
            self.log.unlink(missing_ok=True)
            result = self.run_helper(FAIL_COMMAND=command)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(len(self.calls()), count)
            self.assertNotIn('reset-failed', str(self.calls()))

    def test_both_compositors_sync_before_starting_services(self):
        for file, target in [('.xmonad/xmonad.hs.erb', 'xmonad-session.target'),
                             ('.config/sway/config.erb', 'sway-session.target')]:
            source = (ROOT / file).read_text()
            self.assertIn('systemctl --user stop graphical-session.target && ~/bin/reset-systemd-environment && systemctl --user start ' + target, source)


if __name__ == '__main__':
    unittest.main()
