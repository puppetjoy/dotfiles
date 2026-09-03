# frozen_string_literal: true

require 'minitest/autorun'

class XmonadManualFullscreenTest < Minitest::Test
  TEMPLATE = File.expand_path('../.xmonad/xmonad.hs.erb', __dir__)

  def template
    @template ||= File.read(TEMPLATE)
  end

  def test_client_fullscreen_requests_are_not_handled_automatically
    refute_match(/^\s*\. ewmhFullscreen\b/, template)
    refute_includes template, 'isFullscreen'
    refute_includes template, 'doFullFloat'
  end

  def test_telegram_media_viewer_remains_borderless_without_forced_geometry
    assert_match(
      /isTelegramMediaViewer\s+-\?> doWindowAction \(setBorderWidth' 0\)/,
      template
    )
    assert_includes template, 'suppressTelegramMediaViewerBorders'
  end

  def test_ordinary_ewmh_activation_and_manual_fullscreen_remain
    assert_match(/^\s*\. setEwmhActivateHook activateSwitchWs$/, template)
    assert_match(/^\s*\. ewmh$/, template)
    assert_includes template, '. mkToggle (single NBFULL)'
    assert_includes template, '("M-f"           , sendMessage $ Toggle NBFULL)'
  end
end
