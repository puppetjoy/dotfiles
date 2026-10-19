# frozen_string_literal: true

require 'minitest/autorun'
require 'erb'
require 'tmpdir'
require 'open3'

ROOT = File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.join(ROOT, 'lib/puppet/dotfiles/lib')

class SpotifyMusicWorkspaceTest < Minitest::Test
  def render(path, hostname)
    @facts = { 'networking' => { 'hostname' => hostname },
               'scaling' => { 'gui' => 2, 'text' => 1.5 } }
    ERB.new(File.read(File.join(ROOT, path)), trim_mode: '-').result(binding)
  end

  def test_render_on_enabled_and_unrelated_hosts_uses_runtime_capability
    %w[falcon hawk osprey owl].each do |hostname|
      source = render('.xmonad/xmonad.hs.erb', hostname)
      assert_includes source, 'launcher <- io $ findExecutable "/usr/local/bin/nest-spotify"'
      assert_includes source, 'if launcher == Nothing then youtubeMusic else do'
      assert_includes source, '("music"  , musicTopicAction)'
      assert_includes source, 'className =? "Spotify" <||> className =? "nest-spotify"'
      refute_includes source, '<%'
    end
  end

  def test_music_action_reuses_managed_windows_and_throttles_pending_launches
    source = render('.xmonad/xmonad.hs.erb', 'hawk')
    assert_includes source, 'W.allWindows . windowset'
    assert_includes source, 'filterM (runQuery isSpotify) . sort'
    assert_includes source, 'W.focusWindow window . W.shiftWin "music" window'
    assert_includes source, 'when (pending == Nothing)'
    assert_includes source, 'startTimer 20 >>= XS.put . MusicLaunchTimer . Just'
    assert_includes source, 'XS.put (MusicLaunchTimer Nothing)'
    assert_includes source, '(isSpotify --> doShift "music") <+> composeOne'
    assert_match(/when \(Data.List.null wins\) \$ topicAction topicConfig topic/, source)
    startup = source[/startupHook' = do\n(.*?)\n\n/m, 1]
    refute_includes startup, 'spotify'
  end

  def test_media_bindings_and_separate_ytm_entry_point
    xmonad = render('.xmonad/xmonad.hs.erb', 'falcon')
    assert_includes xmonad, '("M-<Space>"               , spawn "~/bin/playerctl play-pause")'
    assert_includes xmonad, '("<XF86AudioPlay>"         , spawn "~/bin/playerctl play-pause")'
    assert_includes xmonad, '("M-C-y"         , youtubeMusic)'
    assert_includes xmonad, 'youtubeMusic = spawn "firefox -P music --kiosk https://music.youtube.com/"'
    sway = render('.config/sway/config.erb', 'hawk')
    assert_includes sway, 'bindsym $mod+Space            exec ~/bin/playerctl play-pause'
    assert_includes sway, 'bindsym XF86AudioPlay         exec ~/bin/playerctl play-pause'
    refute_includes sway, '<%'
  end

  def test_compile_rendered_config_when_toolchain_is_available
    ghc = ENV.fetch('PATH').split(File::PATH_SEPARATOR).map { |path| File.join(path, 'ghc') }
             .find { |path| File.executable?(path) }
    skip 'GHC unavailable; host compile remains an integration gate' unless ghc

    Dir.mktmpdir('.spotify-xmonad-compile-', ROOT) do |directory|
      %w[falcon hawk].each do |hostname|
        source = File.join(directory, "#{hostname}.hs")
        File.write(source, render('.xmonad/xmonad.hs.erb', hostname))
        output, status = Open3.capture2e(ghc, '--make', '-fno-code', '-fforce-recomp',
                                      '-outputdir', directory, source)
        assert status.success?, output
      end
    end
  end
end
