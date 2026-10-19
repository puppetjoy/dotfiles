#!/usr/bin/env python3
"""Exercise a private copy of the wrapper with no access to real playerctl."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BACKEND = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
players = json.loads(os.environ['PLAYERS'])
if '--list-all' in args:
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
    def run_wrapper(self, players, *args, result=0):
        with tempfile.TemporaryDirectory(prefix='.playerctl-test-', dir=ROOT) as directory:
            directory = Path(directory)
            backend = directory / 'backend'
            backend.write_text(BACKEND)
            backend.chmod(0o755)
            wrapper = directory / 'playerctl'
            source = (ROOT / 'bin/playerctl').read_text()
            self.assertIn('/usr/bin/playerctl', source)
            wrapper.write_text(source.replace('/usr/bin/playerctl', str(backend)))
            self.assertNotIn('/usr/bin/playerctl', wrapper.read_text())
            calls = directory / 'calls'
            env = dict(os.environ, PLAYERS=json.dumps(players), CALLS=str(calls), RESULT=str(result))
            proc = subprocess.run(['zsh', '-f', str(wrapper), *args], env=env,
                                  text=True, capture_output=True, timeout=5)
            records = [json.loads(line) for line in calls.read_text().splitlines()]
            return proc, records

    def test_native_spotify_wins_over_firefox_and_chrome_in_any_state(self):
        for state in ('Playing', 'Paused', 'Stopped'):
            with self.subTest(state=state):
                proc, calls = self.run_wrapper({'firefox.instance1': {}, 'chromium.instance2': {
                    'url': 'https://www.youtube.com/watch?v=music'}, 'spotify': {'status': state}}, 'play-pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', '-p', 'spotify', 'play-pause'], calls[-1])

    def test_web_spotify_uses_exact_origin_not_generic_chrome_name(self):
        for url in ('https://open.spotify.com/track/example', 'spotify:track:example',
                    'https://open.spotify.com/intl-en/track/example', 'spotify:episode:example'):
            with self.subTest(url=url):
                proc, calls = self.run_wrapper({'firefox.instance1': {}, 'chromium.instance2': {
                    'url': 'https://music.youtube.com/'}, 'chromium.instance3': {'url': url}}, 'play-pause')
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual(['-i', 'Gwenview', '-p', 'chromium.instance3', 'play-pause'], calls[-1])

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
        for players in ({'spotify': {}, 'chromium.instance1': {'url': 'https://open.spotify.com/track/x'}},
                        {'spotify.instance1': {}, 'spotify.instance2': {}},
                        {'chrome.instance1': {'url': 'https://open.spotify.com/track/x'},
                         'chromium.instance2': {'url': 'https://open.spotify.com/track/y'}}):
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
                     ('volume',), ('loop',), ('shuffle',), ('--help',), ()):
            with self.subTest(args=args):
                proc, calls = self.run_wrapper({'spotify': {}}, *args)
                self.assertEqual(0, proc.returncode, proc.stderr)
                self.assertEqual([['-i', 'Gwenview', *args]], calls)

    def test_transport_and_seek_target_spotify(self):
        for args in (('play',), ('pause',), ('stop',), ('next',), ('previous',),
                     ('position', '10+'), ('position', '10-'), ('volume', '0.1+'),
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
                        {'chromium': {'url': 'https://open.spotify.com/track/x'},
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
