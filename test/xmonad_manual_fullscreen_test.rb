# frozen_string_literal: true

require 'minitest/autorun'

class XmonadManualFullscreenTest < Minitest::Test
  TEMPLATE = File.expand_path('../.xmonad/xmonad.hs.erb', __dir__)
  TELEGRAM_MEDIA_VIEWER_PROPERTIES = {
    wm_name: 'Media viewer',
    net_wm_name: 'Media viewer',
    wm_class_instance: 'Telegram',
    wm_class: 'TelegramDesktop',
    net_wm_window_type: %w[
      _KDE_NET_WM_WINDOW_TYPE_OVERRIDE
      _NET_WM_WINDOW_TYPE_NORMAL
    ],
    gtk_application_id: 'org.telegram.desktop',
    kde_net_wm_desktop_file: 'org.telegram',
    wm_client_machine: 'hawk',
    wm_normal_hints: {
      location: [0, 0],
      size: [3456, 2168],
      minimum_size: [960, 720],
      resize_increment: [2, 2],
      gravity: 'Static'
    }
  }.freeze

  def template
    @template ||= File.read(TEMPLATE)
  end

  def test_client_fullscreen_requests_are_not_handled_automatically
    refute_match(/^\s*\. ewmhFullscreen\b/, template)
    refute_includes template, 'isFullscreen'
    refute_match(/pure True\s+-\?>\s+doFullFloat/, template)
    assert_equal 1, template.scan(/\bdoFullFloat\b/).length
  end

  def test_telegram_media_viewer_identity_matches_override_atom_in_type_list
    assert_equal 'TelegramDesktop', TELEGRAM_MEDIA_VIEWER_PROPERTIES[:wm_class]
    assert_equal 'Media viewer', TELEGRAM_MEDIA_VIEWER_PROPERTIES[:net_wm_name]
    assert_includes(
      TELEGRAM_MEDIA_VIEWER_PROPERTIES[:net_wm_window_type],
      '_KDE_NET_WM_WINDOW_TYPE_OVERRIDE'
    )
    assert_includes(
      TELEGRAM_MEDIA_VIEWER_PROPERTIES[:net_wm_window_type],
      '_NET_WM_WINDOW_TYPE_NORMAL'
    )
    assert_match(
      /isTelegramMediaViewer =\s*\n\s*className =\? "TelegramDesktop" <&&>\s*\n\s*title =\? "Media viewer" <&&>\s*\n\s*isInProperty "_NET_WM_WINDOW_TYPE" "_KDE_NET_WM_WINDOW_TYPE_OVERRIDE"/,
      template
    )
  end

  def test_telegram_media_viewer_is_the_only_automatic_fullscreen_exception
    assert_match(
      /isTelegramMediaViewer\s+-\?> doFullFloat <\+> doWindowAction \(setBorderWidth' 0\)/,
      template
    )
    assert_includes template, 'suppressTelegramMediaViewerBorders'
  end

  def test_ordinary_ewmh_activation_and_manual_fullscreen_remain
    assert_match(/^\s*\. setEwmhActivateHook activateSwitchWs$/, template)
    assert_match(/^\s*\. ewmh$/, template)
    assert_includes template, '. mkToggle (single NBFULL)'
    assert_includes template, '("M-f"           , sendMessage $ Toggle NBFULL)'
    assert_includes template, '. mkToggle (single FULL)'
    assert_includes template, '("M-S-f"         , sendMessage $ Toggle FULL)'
  end
end
