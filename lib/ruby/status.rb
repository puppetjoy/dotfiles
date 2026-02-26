require 'concurrent'
require 'fileutils'
require 'json'

class StatusWidget
  STATUS_FIFO_DIR = "/tmp/status-#{Process.uid}".freeze

  def initialize(name, timeout = nil)
    @fifo_name = File.join(STATUS_FIFO_DIR, "#{name}.fifo")
    @timeout = timeout
  end

  def run
    monitor(true)
  end

  def monitor(stdout = false)
    at_exit { cleanup }
    @output = stdout ? STDOUT : mkfifo(@fifo_name)
    Signal.trap('USR1') { trigger }
    puts segments
    start_timer
    loop do
      start_monitor
      sleep 1
    end
  end

  protected

  def trigger
    stop_timer
    puts segments
    start_timer
  end

  def fontawesome(char)
    "<span font='Font Awesome 6 Free Solid'>#{char}</span>"
  end

  def segment(str, first = false)
    content = colorize('#d8d8d8', '#282828', " #{str} ")
    if first
      "#{colorize '#282828', '#000000', ''}#{content}"
    else
      "#{colorize '#000000', '#282828', ''}#{content}"
    end
  end

  def colorize(fg, bg, text, bold=false)
    fgcolor=" fgcolor='#{fg}'" if fg
    bgcolor=" bgcolor='#{bg}'" if bg
    font_weight=" font_weight='bold'" if bold
    "<span#{fgcolor}#{bgcolor}#{font_weight}>#{text}</span>"
  end

  def puts(str)
    if str
      @output.puts(str)
      @output.flush
    end
  end

  def mkfifo(fifo_name)
    begin
      Dir.mkdir STATUS_FIFO_DIR
    rescue SystemCallError => e
      raise unless e.errno == Errno::EEXIST::Errno
    end

    File.mkfifo(fifo_name, 0600) unless File.exist? fifo_name
    open(fifo_name, 'w+')
  end

  private

  def cleanup
    stop_timer
    @output.close if @output
    File.unlink @fifo_name if File.exist? @fifo_name

    begin
      FileUtils.rmdir STATUS_FIFO_DIR
    rescue SystemCallError => e
      raise unless [Errno::ENOTEMPTY::Errno, Errno::ENOENT::Errno].include? e.errno
    end
  end

  def start_timer
    if @timeout
      @timer = Concurrent::TimerTask.new(execution_interval: @timeout) { puts segments }
      @timer.execute
    end
  end

  def stop_timer
    if @timer
      @timer.shutdown
      @timer = nil
    end
  end
end

class LoadStatus < StatusWidget
  def initialize
    super('load', 1)
  end

  private

  def start_monitor
    sleep
  end

  def segments
    loadavg = File.read('/proc/loadavg').split(' ').first
    segment("#{fontawesome "\uf233"} #{loadavg}", first: true)
  end
end

class PowerStatus < StatusWidget
  def initialize
    super('power', 5)
  end

  private

  def start_monitor
    @p = IO.popen('upower --monitor')
    @p.each do |line|
      if line !~ /^Monitoring/
        trigger
      end
    end
    @p.close
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    `upower --enumerate`.lines.map do |line|
      if line =~ /\/battery_/
        battery_object = line
        state = nil; percentage = nil; tte = '...'
        `upower --show-info #{battery_object}`.each_line do |info_line|
          case info_line
          when /mouse/
            break
          when /state:\s+(.*)/
            state = $1
          when /percentage:\s+(.*)%/
            percentage = $1.to_i
          when /time to empty:\s+(.*)\s(\w)/
            tte = "#{$1}#{$2}"
          end
        end

        case state
        when 'discharging'
          segment "#{battery_icon(percentage)} #{tte}"
        when 'charging'
          segment "#{fontawesome "\uf0e7"} #{percentage}%"
        else
          ''
        end
      else
        ''
      end
    end.join
  end

  def battery_icon(percentage)
    if percentage > 80
      fontawesome "\uf240"
    elsif percentage > 60
      fontawesome "\uf241"
    elsif percentage > 40
      fontawesome "\uf242"
    elsif percentage > 20
      fontawesome "\uf243"
    else
      fontawesome "\uf244"
    end
  end
end

class NetworkStatus < StatusWidget
  class NetworkDevice
    attr_reader :id, :link, :type, :operational, :setup

    def initialize(id, link, type, operational, setup)
      @id = id
      @link = link
      @type = type
      @operational = operational
      @setup = setup
    end

    def <=>(other)
      if setup != 'unmanaged' and other.setup == 'unmanaged'
        -1
      elsif setup == 'unmanaged' and other.setup != 'unmanaged'
        1
      else
        if operational == 'routable' and other.operational != 'routable'
          -1
        elsif operational != 'routable' and other.operational == 'routable'
          1
        elsif operational == 'carrier' and other.operational != 'carrier'
          -1
        elsif operational != 'carrier' and other.operational == 'carrier'
          1
        elsif operational != 'no-carrier' and other.operational == 'no-carrier'
          -1
        elsif operational == 'no-carrier' and other.operational != 'no-carrier'
          1
        else
          if type != 'wlan' and other.type == 'wlan'
            -1
          elsif type == 'wlan' and other.type != 'wlan'
            1
          else
            0
          end
        end
      end
    end

    def to_s
      "#{id}:#{link}:#{type}:#{operational}:#{setup}"
    end
  end

  def self.test_sort
    puts `networkctl`.lines[1..-3].map { |line| NetworkDevice.new(*line.split) }.sort
  end

  def initialize
    super('network', 5)
  end

  private

  def start_monitor
    @p = IO.popen('journalctl --follow --unit=systemd-networkd')
    @p.each { trigger }
    @p.close
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    device = `networkctl`.lines[1..-3].map { |line| NetworkDevice.new(*line.split) }.sort.first

    if device.type == 'wlan'
      icon = fontawesome "\uf1eb"

      if device.operational == 'routable'
        if `iw dev #{device.link} link` =~ /signal:\s+(\S+)\s(\S+)/
          signal = "#{$1}#{$2}"
          segment "#{icon} #{signal}"
        else
          segment "#{icon}"
        end
      else
        segment "#{icon} ..."
      end
    else
      ''
    end
  end
end

class AudioStatus < StatusWidget
  def initialize
    super('audio')
  end

  private

  def start_monitor
    @p = IO.popen('pactl subscribe')
    @p.each do |line|
      if line =~ /\s(sink|server)\s/
        trigger
      end
    end
    @p.close
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    default_sink = `pactl info`.each_line do |line|
      if line =~ /^Default Sink:/
        break line.split(' ')[2]
      end
    end

    is_default = false
    description = nil; mute = nil; volume = nil; port = nil
    `pactl list sinks`.each_line do |line|
      tokens = line.split(' ')
      if line =~ /\tName:/
        is_default = tokens[1] == default_sink
      elsif is_default
        case line
        when /\tDescription: (.*)/
          description = $1
        when /\tMute:/
          mute = tokens[1]
        when /\tVolume:/
          volume = tokens[6]
        when /\tActive Port:/
          port = tokens[2]
          break
        end
      end
    end

    if description =~ /Built-in Audio (Analog|Stereo)/ or
       description == 'Dell AC511 USB SoundBar Analog Stereo' or
       description == 'DROP Panda Analog Stereo'
      icon = if mute == 'yes'
               fontawesome "\uf6a9"
             elsif port == 'analog-output-headphones'
               fontawesome "\uf025"
             else
               fontawesome "\uf028"
             end

      segment "#{icon} #{(volume.to_f * 2).round / 2.0}dB"
    else
      ''
    end
  end
end

class BacklightStatus < StatusWidget
  def initialize
    super('backlight')
  end

  private

  def start_monitor
    if Dir.glob('/sys/class/backlight/*/actual_brightness').empty?
      sleep
    else
      @p = IO.popen('inotifywait --quiet --monitor --event modify /sys/class/backlight/*/actual_brightness')
      @p.each { trigger }
      @p.close
    end
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    brightness = `qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightness`.to_i
    max_brightness = `qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightnessMax`.to_i
    if max_brightness > 0
      percentage = brightness * 100.0 / max_brightness
      @clear_thread.exit if @clear_thread
      @clear_thread = Thread.new { sleep 2; puts '' }
      segment "#{fontawesome "\uf0eb"} #{percentage.round}%"
    end
  end
end

class ScreensaverStatus < StatusWidget
  def initialize(name = 'screensaver', timeout = 30)
    super(name, timeout)
  end

  private

  def start_monitor
    @p = IO.popen('inotifywait --quiet --monitor --event create --event delete --include screensaver.inhibit $XDG_RUNTIME_DIR')
    @p.each { trigger }
    @p.close
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    if File.exist?(File.join(ENV['XDG_RUNTIME_DIR'], 'screensaver.inhibit'))
      if ENV['SWAYSOCK']
        system 'swaymsg \'[title="Sway Idle Inhibitor"] kill; exec kdialog --title "Sway Idle Inhibitor" --msgbox "This hidden box keeps Sway active"\''
      else
        system 'qdbus6 org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver.SimulateUserActivity'
      end
      ''
    else
      system 'swaymsg \'[title="Sway Idle Inhibitor"] kill\'' if ENV['SWAYSOCK']
      segment fontawesome "\uf4fd"
    end
  end
end

class SwayidlerStatus < ScreensaverStatus
  def initialize
    super('swayidler', nil)
  end
end

class VpnStatus < StatusWidget
  def initialize
    super('vpn')
  end

  private

  def start_monitor
    @p = IO.popen('journalctl --user --follow --identifier=systemd')
    @p.each { trigger }
    @p.close
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    if `systemctl --user is-active vpn`.chomp == 'active'
      segment fontawesome "\uf023"
    else
      ''
    end
  end
end

class WindowStatus < StatusWidget
  MAX_LENGTH = 100.freeze

  def initialize
    super('window', nil)
  end

  private

  def start_monitor
    @p = IO.popen('swaymsg --monitor --type subscribe \'["window", "workspace"]\'')
    @p.each do |line|
      event = JSON.parse(line) || next
      case event['change']
      when 'init'
        @title = ''
      when 'close', 'move'
        @title = '' if event['container']
      when 'focus', 'title'
        @title = event['container']['name'] if event['container']
      else
        next
      end
      trigger
    end
    @p.close
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    super
  end

  def segments
    return unless @title
    title = @title.length > MAX_LENGTH ? "#{@title[0..MAX_LENGTH - 2]}…" : @title
    " #{title}"
  end
end

class SwayWorkspaces < StatusWidget
  def initialize(count)
    super('sway-workspaces')
    @count = count
    @fifos = (1..count).map { |num| mkfifo File.join(STATUS_FIFO_DIR, "sway-workspace-#{num}.fifo") }
  end

  def cleanup
    Process.kill('TERM', @p.pid) if @p and !@p.closed?
    @fifos.each_with_index do |fifo, i|
      fifo.close
      File.unlink File.join(STATUS_FIFO_DIR, "sway-workspace-#{i + 1}.fifo")
    end if @fifos
    super
  end

  private

  def start_monitor
    @p = IO.popen('swaymsg --monitor --type subscribe \'["workspace"]\'')
    @p.each do |line|
      if line =~ /^{/
        trigger
      end
    end
    @p.close
  end

  def segments
    workspaces = JSON.parse(`swaymsg -t get_workspaces`)
    workspaces.select! { |ws| ws['num'] > 0 }
    workspaces.sort! { |a, b| a['num'] <=> b['num'] }
    (1..@count).each do |num|
      fifo = @fifos[num - 1]
      workspace = workspaces.find { |ws| ws['num'] == num }
      if workspace
        if workspace['focused']
          fgcolor = '#282828'
          bgcolor = '#7cafc2'
          bold = true
        elsif workspace['urgent']
          fgcolor = '#282828'
          bgcolor = '#f7ca88'
          bold = false
        elsif workspace['visible']
          fgcolor = '#d8d8d8'
          bgcolor = '#383838'
          bold = false
        else
          fgcolor = '#d8d8d8'
          bgcolor = '#282828'
          bold = false
        end
        endsep = workspace == workspaces.last ? colorize(bgcolor, nil, ' ') : ''
        fifo.puts colorize(fgcolor, bgcolor, " #{pretty_name(workspace['name'])} ", bold) + endsep
      else
        fifo.puts ''
      end
      fifo.flush
    end
    nil # don't output any segments
  end

  def pretty_name(name)
    subs = {
      'web'     => "\uf0ac", # fa-globe
      'dev'     => "\uf121", # fa-code
      'ops'     => "\uf120", # fa-terminal
      'music'   => "\uf001", # fa-music
      'mail'    => "\uf0e0", # fa-envelope
      'chat'    => "\uf075", # fa-comment
      'windows' => "\uf17a", # fa-windows
    }

    return name unless name =~ /^(\d+).*?: (.*)/
    num = Regexp.last_match(1)
    icon = fontawesome(subs[Regexp.last_match(2)] || "\uf069")
    "#{num}: #{icon}"
  end
end

# vim: filetype=ruby
