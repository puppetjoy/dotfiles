#!/usr/bin/env python3
"""Exercise a private copy of the wrapper with no access to real playerctl."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUS = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
players = json.loads(os.environ['PLAYERS'])
method, name = sys.argv[-3], sys.argv[-1]
if name.startswith('org.mpris.MediaPlayer2.'):
    key = name.removeprefix('org.mpris.MediaPlayer2.')
else:
    key = next((key for key, data in players.items() if data.get('owner') == name), '')
data = players.get(key, {})
if not data.get('owner') or data.get('unavailable'):
    sys.exit(1)
counter = Path(os.environ['PROC_ROOT']).parent / ('bus-' + key + '-' + method)
count = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(count))
if method == 'GetNameOwner':
    if data.get('reuse_at') == count:
        stat = Path(os.environ['PROC_ROOT']) / str(data['pid']) / 'stat'
        stat.write_text(stat.read_text().replace('123456', '654321'))
    if data.get('vanish_at') == count:
        (Path(os.environ['PROC_ROOT']) / str(data['pid']) / 'cmdline').unlink()
    print('s ' + json.dumps(':9.999' if count >= data.get('owner_change_at', 999) else data['owner']))
elif method == 'GetConnectionUnixProcessID':
    print('u', data['pid'] + (1 if count >= data.get('pid_change_at', 999) else 0))
elif method == 'GetConnectionUnixUser':
    print('u', data.get('uid', os.getuid()))
else:
    sys.exit(1)
'''


def managed(pid=3737843, **overrides):
    return dict(owner=':1.' + str(pid), pid=pid, managed=True, **overrides)


BACKEND = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
players = json.loads(os.environ['PLAYERS'])
if '--list-all' in args:
    previous = Path(os.environ['CALLS']).read_text().splitlines()
    if len(previous) > 1 and os.environ.get('NEXT_PLAYERS'):
        players = json.loads(os.environ['NEXT_PLAYERS'])
    print('\\n'.join(players))
    sys.exit(0)
if 'metadata' in args and 'xesam:url' in args and '-p' in args:
    name = args[args.index('-p') + 1]
    url = players[name].get('url')
    if url is None:
        sys.exit(1)
    print(url)
    sys.exit(0)
# Every other invocation is a recorded operation, never a real D-Bus call
sys.exit(int(os.environ.get('RESULT', '0')))
'''


class SpotifyPlayerctlTest(unittest.TestCase):
    def run_wrapper(self, players, *args, result=0, next_players=None):
        with tempfile.TemporaryDirectory(prefix='.playerctl-test-', dir=ROOT) as directory:
            directory = Path(directory)
            backend = directory / 'backend'
            backend.write_text(BACKEND)
            backend.chmod(0o755)
            wrapper = directory / 'playerctl'
            source = (ROOT / 'bin/playerctl').read_text()
            self.assertIn('/usr/bin/playerctl', source)
            bus = directory / 'busctl'
            bus.write_text(BUS)
            bus.chmod(0o755)
            proc_root = directory / 'proc'
            proc_root.mkdir()
            config_home = directory / 'config'
            for data in players.values():
                if not data.get('managed'):
                    continue
                process = proc_root / str(data['pid'])
                process.mkdir(exist_ok=True)
                (process / 'exe').symlink_to(data.get('exe', '/opt/google/chrome/chrome'))
                process_args = data.get('args', ['/opt/google/chrome/chrome',
                    '--user-data-dir=' + str(config_home / 'nest-spotify'),
                    '--ozone-platform=x11', '--force-device-scale-factor=2.0',
                    '--class=nest-spotify', '--app=https://open.spotify.com/'])
                process_args = [arg.replace('{config}', str(config_home)) for arg in process_args]
                (process / 'cmdline').write_bytes(('\0'.join(process_args) + '\0').encode())
                (process / 'stat').write_text(str(data['pid']) + ' (chrome (test)) S ' + '0 ' * 18 + '123456 0')
            wrapper.write_text(source.replace('/usr/bin/playerctl', str(backend))
                               .replace('/usr/bin/busctl', str(bus))
                               .replace("Path('/proc')", 'Path(' + repr(str(proc_root)) + ')'))
            self.assertNotIn('/usr/bin/playerctl', wrapper.read_text())
            self.assertNotIn('/usr/bin/busctl', wrapper.read_text())
            self.assertNotIn("Path('/proc')", wrapper.read_text())
            calls = directory / 'calls'
            env = dict(os.environ, PLAYERS=json.dumps(players), CALLS=str(calls), RESULT=str(result),
                       PROC_ROOT=str(proc_root), XDG_CONFIG_HOME=str(config_home),
                       NEXT_PLAYERS=json.dumps(next_players) if next_players is not None else '')
            proc = subprocess.run(['zsh', '-f', str(wrapper), *args], env=env,
                                  text=True, capture_output=True, timeout=15)
            records = [json.loads(line) for line in calls.read_text().splitlines()]
            return proc, records

    def test_native_spotify_wins_over_firefox_and_chrome_in_any_state(self):
        for state in ('Playing', 'Paused', 'Stopped'):
            with self.subTest(state=state):
                proc, calls = self.run_wrapper({'firefox.instance1': {}, 'chromium.instance2': {
                    'url': 'https://www.youtube.com/watch?v=music'}, 'spotify': {'status': state}}, 'play-pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', '-p', 'spotify', 'play-pause'], calls[-1])

    def test_missing_url_dedicated_chrome_wins_while_playing_or_paused(self):
        for state in ('Playing', 'Paused', 'Stopped'):
            with self.subTest(state=state):
                proc, calls = self.run_wrapper({'firefox.instance1': {}, 'chromium.instance2': {
                    'url': 'https://open.spotify.com/track/ordinary'},
                    'chromium.instance3': managed(status=state)}, 'play-pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', '-p', 'chromium.instance3', 'play-pause'], calls[-1])

    def test_owner_pid_is_not_inferred_from_numeric_suffix(self):
        proc, calls = self.run_wrapper({'chromium.instance7': managed(pid=800)}, 'position', '2+')
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual(['-i', 'Gwenview', '-p', 'chromium.instance7', 'position', '2+'], calls[-1])

    def test_ordinary_spotify_tab_and_wrong_process_identity_do_not_qualify(self):
        for data in ({'url': 'https://open.spotify.com/track/x'},
                     managed(exe='/usr/bin/firefox'), managed(uid=os.getuid() + 1),
                     managed(args=['chrome', '--app=https://open.spotify.com/']),
                     managed(unavailable=True)):
            with self.subTest(data=data):
                proc, calls = self.run_wrapper({'chromium.instance3737843': data}, 'pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', 'pause'], calls[-1])

    def test_owner_changes_pid_reuse_and_vanishing_process_fail_closed(self):
        for change in ({'owner_change_at': 3}, {'reuse_at': 3}, {'vanish_at': 3},
                       {'pid_change_at': 3}):
            with self.subTest(change=change):
                proc, calls = self.run_wrapper({'chromium.instance3': managed(**change),
                                                'firefox': {}}, 'play-pause')
                self.assertEqual(1, proc.returncode, proc.stderr)
                self.assertIn('identity changed', proc.stderr)
                self.assertTrue(all('--list-all' in call for call in calls))

    def test_conflicting_flags_renderer_and_ordinary_profile_fail_identification(self):
        base = ['chrome', '--user-data-dir={config}/nest-spotify', '--class=nest-spotify',
                '--app=https://open.spotify.com/']
        for args in (base + ['--class=other'], base + ['--type=renderer'],
                     [arg.replace('/nest-spotify', '/ordinary') for arg in base],
                     [arg.replace('https://open.spotify.com/', 'https://open.spotify.com.evil/') for arg in base],
                     base + ['--user-data-dir', '/ordinary']):
            with self.subTest(args=args):
                proc, calls = self.run_wrapper({'chromium.instance3737843': managed(args=args)}, 'pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', 'pause'], calls[-1])

    def test_unavailable_proc_and_malformed_unique_owner_keep_legacy_fallback(self):
        for data in ({'owner': ':1.7', 'pid': 7}, {'owner': 'not-unique', 'pid': 7}):
            proc, calls = self.run_wrapper({'chromium.instance7': data}, 'pause')
            self.assertEqual(0, proc.returncode, proc.stderr)
            self.assertEqual(['-i', 'Gwenview', 'pause'], calls[-1])

    def test_player_set_change_before_dispatch_fails_without_generic_retry(self):
        players = {'chromium.instance3': managed()}
        for new in ({}, dict(players, **{'chromium.instance3.other': {}}),
                    dict(players, spotify={})):
            proc, calls = self.run_wrapper(players, 'play-pause', next_players=new)
            self.assertEqual(1, proc.returncode, proc.stderr)
            self.assertIn('player set changed', proc.stderr)
            self.assertTrue(all('--list-all' in call for call in calls))

    def test_changes_during_initial_inspection_cannot_establish_identity(self):
        for change in ({'owner_change_at': 2}, {'pid_change_at': 2}):
            proc, calls = self.run_wrapper({'chromium.instance3': managed(**change)}, 'pause')
            self.assertEqual(0, proc.returncode, proc.stderr)
            self.assertEqual(['-i', 'Gwenview', 'pause'], calls[-1])

    def test_non_spotify_urls_and_unreadable_metadata_keep_generic_fallback(self):
        for url in (None, '', 'https://open.spotify.com.evil/track/x',
                    'https://open.spotify.com@evil/track/x', 'https://example.com/?spotify',
                    'file:///spotify', 'https://music.youtube.com/'):
            with self.subTest(url=url):
                proc, calls = self.run_wrapper({'chromium.instance1': {'url': url}}, 'play-pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', 'play-pause'], calls[-1])

    def test_firefox_spotify_page_is_not_the_managed_chrome_app(self):
        proc, calls = self.run_wrapper({'firefox.instance1': {'url': 'https://open.spotify.com/track/x'}}, 'pause')
        self.assertEqual(0, proc.returncode)
        self.assertEqual(['-i', 'Gwenview', 'pause'], calls[-1])
        self.assertEqual(2, len(calls))

    def test_multiple_candidates_fail_without_controlling_any_player(self):
        for players in ({'spotify': {}, 'chromium.instance1': managed()},
                        {'spotify.instance1': {}, 'spotify.instance2': {}},
                        {'chrome.instance1': managed(pid=100),
                         'chromium.instance2': managed(pid=200)}):
            with self.subTest(players=players):
                proc, calls = self.run_wrapper(players, 'play-pause')
                self.assertEqual(1, proc.returncode)
                self.assertIn('Multiple Spotify players', proc.stderr)
                self.assertTrue(all('--list-all' in call or 'metadata' in call for call in calls))

    def test_explicit_selection_follow_listing_and_queries_are_unchanged(self):
        for args in (('-p', 'firefox', 'play-pause'), ('--player=firefox', 'play-pause'),
                     ('-pfirefox', 'play-pause'), ('play-pause', '--player', 'firefox'),
                     ('-i', 'spotify', 'play-pause'), ('--all', 'pause'),
                     ('--follow', 'status'), ('-F', 'metadata'), ('--list-all',),
                     ('status',), ('metadata', '--format', '{{title}}'), ('position',),
                     ('volume',), ('loop',), ('shuffle',), ('--help',),
                     ('position', '--format', '{{position}}'),
                     ('volume', '-f', '{{volume}}'), ()):
            with self.subTest(args=args):
                proc, calls = self.run_wrapper({'spotify': {}}, *args)
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual([['-i', 'Gwenview', *args]], calls)

    def test_transport_and_seek_target_spotify(self):
        for args in (('play',), ('pause',), ('stop',), ('next',), ('previous',),
                     ('position', '10+'), ('position', '10-'), ('position', '-10'), ('volume', '0.1+'),
                     ('loop', 'Track'), ('shuffle', 'On')):
            with self.subTest(args=args):
                proc, calls = self.run_wrapper({'spotify': {}}, *args)
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', '-p', 'spotify', *args], calls[-1])

    def test_backend_failure_is_not_retried_on_an_unrelated_player(self):
        proc, calls = self.run_wrapper({'spotify': {}, 'firefox': {}}, 'play-pause', result=7)
        self.assertEqual(7, proc.returncode)
        self.assertEqual(2, len(calls))

    def test_prefix_overlaps_fail_without_controlling_a_player(self):
        for players in ({'spotify': {}, 'spotify.other': {}},
                        {'chromium': managed(),
                         'chromium.instance2': {'url': 'https://example.com/'}}):
            proc, calls = self.run_wrapper(players, 'play-pause')
            self.assertEqual(1, proc.returncode)
            self.assertIn('Ambiguous Spotify player selector', proc.stderr)
            self.assertTrue(all('--list-all' in call or 'metadata' in call for call in calls))

    def test_no_players_and_only_gwenview_use_existing_exclusion(self):
        for players in ({}, {'Gwenview': {}}):
            proc, calls = self.run_wrapper(players, 'play-pause')
            self.assertEqual(0, proc.returncode, proc.stderr)
            self.assertEqual(['-i', 'Gwenview', 'play-pause'], calls[-1])


if __name__ == '__main__':
    unittest.main()
