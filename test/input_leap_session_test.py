#!/usr/bin/env python3
"""Keep the X11-only Input Leap service out of portal auto-selection."""
import configparser
from pathlib import Path
import shlex
import unittest

ROOT = Path(__file__).resolve().parents[1]
UNITS = ROOT / '.config/systemd/user'


def unit(name):
    config = configparser.ConfigParser(interpolation=None)
    config.read(UNITS / name)
    return config


class InputLeapSessionTest(unittest.TestCase):
    def test_x11_backend_preserves_existing_policy(self):
        service = unit('input-leaps.service')
        self.assertEqual(shlex.split(service['Service']['ExecStart']),
                         ['/usr/bin/input-leaps', '--use-x11', '--disable-crypto'])
        self.assertEqual(service['Service']['Type'], 'forking')
        self.assertEqual(service['Unit']['ConditionFileNotEmpty'],
                         '%h/.config/InputLeap/input-leap.conf')

    def test_service_is_x11_only(self):
        service = unit('input-leaps.service')
        self.assertEqual(service['Unit']['PartOf'], 'x-session.target')
        self.assertEqual(service['Install']['WantedBy'], 'x-session.target')
        self.assertEqual((UNITS / 'x-session.target.wants/input-leaps.service').resolve(),
                         UNITS / 'input-leaps.service')
        self.assertIn('x-session.target',
                      unit('xmonad-session.target')['Unit']['BindsTo'].split())
        sway_targets = unit('sway-session.target')['Unit']['BindsTo'].split()
        self.assertIn('wayland-session.target', sway_targets)
        self.assertNotIn('x-session.target', sway_targets)
        for directory in UNITS.glob('*.wants'):
            if directory.name != 'x-session.target.wants':
                self.assertFalse((directory / 'input-leaps.service').exists(),
                                 f'X11 server unexpectedly enabled in {directory.name}')


if __name__ == '__main__':
    unittest.main()
