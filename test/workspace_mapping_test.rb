# frozen_string_literal: true

require 'minitest/autorun'
require 'erb'

ROOT = File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.join(ROOT, 'lib/puppet/dotfiles/lib')

class WorkspaceMappingTest < Minitest::Test
  NAMES = %w[web chat ops music mail six seven eight nine ten].freeze

  def render(path, hostname = 'hawk')
    @facts = { 'networking' => { 'hostname' => hostname },
               'scaling' => { 'gui' => 2, 'text' => 1.5 } }
    ERB.new(File.read(File.join(ROOT, path)), trim_mode: '-').result(binding)
  end

  def test_rendered_workspace_order_and_unique_wildcards
    %w[hawk falcon eagle kite owl].each do |host|
      xmonad = render('.xmonad/xmonad.hs.erb', host)
      names = xmonad[/^workspaces' = (.*)$/, 1].scan(/"([^"]+)"/).flatten
      assert_equal NAMES, names
      assert_equal 10, names.uniq.length
      sway = render('.config/sway/config.erb', host)
      assert_equal NAMES.each_with_index.map { |name, i| [(i + 1).to_s, "#{i + 1}: #{name}"] },
                   sway.scan(/^set \$ws(\d+) '([^']+)'$/)
      refute_includes xmonad + sway, '<%'
    end
  end

  def test_numeric_view_and_move_bindings_include_zero
    xmonad = render('.xmonad/xmonad.hs.erb')
    assert_includes xmonad, '("M-0"           , windows $ W.greedyView "ten")'
    assert_includes xmonad, '("M-S-0"         , windows $ W.shift "ten")'
    refute_match(/onWorkspace "(?:windows|ten)"/, xmonad)
    sway = render('.config/sway/config.erb')
    (1..10).each do |i|
      key = i == 10 ? 0 : i
      assert_includes sway, "bindsym $mod+Mod1+#{key} workspace number $ws#{i}"
      assert_includes sway, "bindsym $mod+#{key} exec sway-greedy-view $ws#{i}"
      assert_includes sway, "bindsym $mod+Shift+#{key} exec sway-layout-manager move $ws#{i}"
    end
  end

  def test_telegram_is_only_an_empty_xmonad_topic_action
    xmonad = render('.xmonad/xmonad.hs.erb')
    assert_includes xmonad, '("chat"   , spawn "Telegram")'
    assert_includes xmonad, 'when (Data.List.null wins) $ topicAction topicConfig topic'
    refute_match(/spawn "code|"dev"|"windows"/, xmonad)
    startup = xmonad[/startupHook' = do\n(.*?)\n\n/m, 1]
    refute_match(/Telegram|code/, startup)
    sway = render('.config/sway/config.erb')
    refute_match(/Telegram|telegram|\bcode\b/, sway)
    # No listener, service or topic lifecycle is added to Sway
    assert_equal ["exec 'systemctl --user stop graphical-session.target && ~/bin/reset-systemd-environment && systemctl --user start sway-session.target'"],
                 sway.lines.map(&:strip).select { |line| line.start_with?('exec ', 'exec_always ') }
  end

  def test_bars_preserve_wildcard_icons_and_numeric_labels
    taffybar = render('.config/taffybar/taffybar.hs.erb')
    assert_includes taffybar, 'fontAwesomeMarkup "\xf069"'
    assert_includes taffybar, '(show $ wsNum + 1) ++ ": "'
    NAMES.drop(5).each { |name| assert_includes taffybar, "\"#{name}\"" }
    refute_match(/"dev"|"windows"/, taffybar)
    source = render('lib/ruby/status.rb.erb')
    # Exercise the real formatter without loading unrelated status widget dependencies
    formatter = source[/  def pretty_name\(name\).*?^  end/m]
    widget = Class.new do
      def fontawesome(icon)
        icon
      end
    end
    widget.class_eval(formatter, 'status.rb')
    instance = widget.new
    NAMES.each_with_index do |name, i|
      icon = ["\uf0ac", "\uf075", "\uf120", "\uf001", "\uf0e0"][i] || "\uf069"
      assert_equal "#{i + 1}: #{icon}", instance.pretty_name("#{i + 1}: #{name}")
    end
    refute_match(/'dev'|'windows'/, formatter)
  end
end
