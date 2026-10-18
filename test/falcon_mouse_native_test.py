#!/usr/bin/env python3
"""Optional integration: real KConfig tools, temporary config, no live X writes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('kwriteconfig6') and shutil.which('kreadconfig6'),
                     'requires KDE 6 KConfig tools')
class NativeMousePreferenceTest(unittest.TestCase):
    def test_preservation_missing_file_and_idempotence(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as directory:
            base = Path(directory)
            (base / 'bin').mkdir()
            hostname = base / 'bin/hostname'
            hostname.write_text('#!/bin/sh\nprintf "falcon\\n"\n')
            hostname.chmod(0o755)
            env = os.environ | {'XDG_CONFIG_HOME': str(base / 'config'),
                                'PATH': str(base / 'bin') + ':' + os.environ['PATH'],
                                'DISPLAY': ':not-contacted', 'WAYLAND_DISPLAY': '',
                                'XDG_SESSION_TYPE': 'x11'}
            config = base / 'config/kcminputrc'
            for initial in (None, '[Mouse]\nX11LibInputXAccelProfileFlat=true\n'
                            'cursorSize=37\nXLbInptPointerAcceleration=0\n'
                            'XLbInptNaturalScroll=false\n\n[Unrelated]\nKeep=untouched\n'):
                config.unlink(missing_ok=True)
                if initial is not None:
                    config.write_text(initial)
                    config.chmod(0o640)
                first = None
                for _ in range(2):
                    subprocess.run(['zsh', '-f', str(ROOT / 'bin/configure-falcon-mouse')],
                                   env=env, check=True)
                    result = subprocess.check_output(['kreadconfig6', '--file', 'kcminputrc',
                               '--group', 'Mouse', '--key', 'XLbInptAccelProfileFlat'], env=env, text=True)
                    self.assertEqual(result.strip(), 'false')
                    contents = config.read_bytes()
                    if initial is not None:
                        for line in initial.splitlines():
                            if line:
                                self.assertIn(line, contents.decode())
                        self.assertEqual(config.stat().st_mode & 0o777, 0o640)
                    if _ == 0:
                        first = contents
                    else:
                        self.assertEqual(contents, first)


if __name__ == '__main__':
    unittest.main()
