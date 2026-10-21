# frozen_string_literal: true

require 'minitest/autorun'
require 'erb'
require 'tmpdir'
require 'stringio'

ROOT = File.expand_path('..', __dir__)
eval ERB.new(File.read(File.join(ROOT, 'lib/ruby/status.rb.erb')), trim_mode: '-').result,
     TOPLEVEL_BINDING, 'rendered-status.rb'

class ScreensaverStatusTest < Minitest::Test
  def setup
    @saved_env = ENV.to_h
    @directory = Dir.mktmpdir('screensaver-', ENV['TMPDIR'])
    ENV['XDG_RUNTIME_DIR'] = @directory
    @marker = File.join(@directory, 'screensaver.inhibit')
    @widget = ScreensaverStatus.new
    @calls = []
    calls = @calls
    @widget.define_singleton_method(:system) { |*args| calls << args; true }
  end

  def teardown
    ENV.replace(@saved_env)
    FileUtils.remove_entry(@directory)
  end

  def test_x11_absent_and_empty_sway_socket_keep_awake_and_reset
    [nil, ''].each do |socket|
      ENV['SWAYSOCK'] = socket
      FileUtils.touch(@marker)
      @calls.clear
      2.times { assert_equal '', @widget.send(:segments) }
      assert_equal [['qdbus6 org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver.SimulateUserActivity']] * 2, @calls
      File.unlink(@marker)
      @calls.clear
      refute_empty @widget.send(:segments)
      assert_empty @calls
    end
  end

  def test_sway_inhibit_and_reset_preserve_hidden_window_protocol
    ENV['SWAYSOCK'] = '/run/user/1000/sway.sock'
    FileUtils.touch(@marker)
    assert_equal '', @widget.send(:segments)
    assert_equal [['swaymsg \'[title="Sway Idle Inhibitor"] kill; exec kdialog --title "Sway Idle Inhibitor" --msgbox "This hidden box keeps Sway active"\'']], @calls
    File.unlink(@marker)
    refute_empty @widget.send(:segments)
    assert_equal ['swaymsg \'[title="Sway Idle Inhibitor"] kill\''], @calls.last
    assert_nil SwayidlerStatus.new.instance_variable_get(:@timeout)
  end

  def test_real_timer_repeats_x11_activity_with_empty_sway_socket
    ENV['SWAYSOCK'] = ''
    FileUtils.touch(@marker)
    widget = ScreensaverStatus.new('screensaver-test', 0.02)
    calls = Queue.new
    widget.define_singleton_method(:system) { |*args| calls << args; true }
    widget.instance_variable_set(:@output, StringIO.new)
    begin
      widget.send(:start_timer)
      require 'timeout'
      Timeout.timeout(3) do
        2.times do
          assert_equal ['qdbus6 org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver.SimulateUserActivity'], calls.pop
        end
      end
    ensure
      widget.send(:stop_timer)
    end
  end
end
