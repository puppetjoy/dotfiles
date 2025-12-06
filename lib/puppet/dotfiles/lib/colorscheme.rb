#
# colorscheme.rb
#
# My own take on the [Base16](https://github.com/chriskempson/base16)
# builders and templates, primarily so I can integrate it into my
# ERB-based dotfiles, managed by Puppet at:
#
# https://gitlab.joyfullee.me/joy/dotfiles/-/blob/preprocessed/bin/refresh-dotfiles
#
# This has also been carefully extended to work well with low-color
# terminals, like the Linux console.
#

require 'yaml'

class ColorScheme
  class Color
    attr_reader :hex, :hexr, :hexg, :hexb
    attr_reader :r, :g, :b
    attr_reader :base, :ansi, :bold

    def initialize(colorscheme, hex, base, ansi, bold)
      @colorscheme = colorscheme
      @hex = hex
      (@hexr, @hexg, @hexb) = hex.scan(/../)
      (@r, @g, @b) = hex.scan(/../).map { |color| color.to_i(16) }
      @base = base
      @ansi = ansi
      @bold = bold
    end

    # Modified from the original base16 builder
    # See: https://github.com/chriskempson/base16-builder/blob/dfe4cbbf7941ee13ddd9890e74e8787e16375dff/base16#L176
    def mix(color, weight = 50)
      p = (weight / 100.0).to_f
      w = p * 2 - 1

      w1 = (w + 1) / 2.0
      w2 = 1 - w1


      Color.new(@colorscheme, "%02x%02x%02x" % [
        (color.r * w1 + r * w2).to_i,
        (color.g * w1 + g * w2).to_i,
        (color.b * w1 + b * w2).to_i,
      ], nil, nil, nil)
    end

    # Add a bit of 'white' to a color.  White is defined by color 7, the end of the
    # gray scale in a color scheme.  (This is usually #FFFFFF, or close.)
    def tint(weight = 50)
      mix(@colorscheme.colors_by_base[0x07], weight)
    end

    # Add a bit of 'black' to a color.  Black is defined by color 0, the end of the
    # gray scale in a color scheme.  (This is usually #000000, or close.)
    def shade(weight = 50)
      mix(@colorscheme.colors_by_base[0x00], weight)
    end

    def invert
      Color.new(@colorscheme, "%02x%02x%02x" % rgb.map { |n| n ^ 255 }, nil, nil, nil)
    end

    def x11
      "rgb:#{hexr}/#{hexg}/#{hexb}"
    end

    def rgb
      [r, g, b]
    end

    def web
      "##{hexr}#{hexg}#{hexb}"
    end
  end

  # Map the base16 code to ansi number based on the number of available
  # colors.  Where approximations had to be made, they were done subjectively
  # by look (https://chriskempson.github.io/base16/) and style guidelines
  # (https://github.com/chriskempson/base16/blob/master/styling.md).
  #
  # Base0F is the hard one.  It's rarely used, has no historical mapping to
  # any particular color, and varies wildly across different Base16 themes.
  # This mapping approximates it to Base03 for low color terminals, which is
  # usually a middle gray of similar luminance.  I've never seen it used for
  # a background color, but if it is, it will take on the middle gray color
  # on 16-color terminals, and the default background color on 8-color ones.
  BASE_TO_ANSI = {
         # 00  01  02 03  04 05  06  07    08  09     0A     0B     0C     0D    0E   0F
    256 => [0, 18, 19, 8, 20, 7, 21, 15,[1,9], 16,[3,11],[2,10],[6,14],[4,12],[5,13], 17],
    16  => [0,  0,  0, 8,  7, 7, 15, 15,[1,9],  3,[3,11],[2,10],[6,14],[4,12],[5,13],  8],
    8   => [0,  0,  0, 8,  7, 7, 15, 15,    1,  3,     3,     2,     6,     4,     5,  8],
  }

  def self.dark
    ColorScheme.new('.colorscheme-dark.yaml')
  end

  def self.light
    ColorScheme.new('.colorscheme-light.yaml')
  end

  def self.bright
    ColorScheme.new('.colorscheme-bright.yaml')
  end

  def initialize(filename)
    @scheme_data = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', '..', '..', filename))
    @colors = BASE_TO_ANSI.keys.each_with_object(Hash.new) do |term_colors, colors_acc|
      colors_acc[term_colors] = BASE_TO_ANSI[term_colors].each_with_index.map do |ansis, base|
        basestr = '%02X' % base
        hex = @scheme_data["base#{basestr}"]
        Array(ansis).map do |ansi|
          # Map requested ansi color into the available color space.
          # If a mapping is made, pass a flag that bold styling could be used
          # to "jump" back to the original color (for example, on the Linux
          # console, to be able to access all 16 colors from the 8 color space).
          bold = ansi / term_colors > 0
          ansi %= term_colors
          Color.new(self, hex, basestr, ansi, bold)
        end
      end.flatten
      colors_acc
    end
  end

  def colors(term_colors = 256)
    @colors[term_colors]
  end

  def colors_by_ansi(term_colors = 256)
    colors(term_colors).sort do |c1, c2|
      if c1.ansi == c2.ansi
        c1.base <=> c2.base
      else
        c1.ansi <=> c2.ansi
      end
    end.uniq { |color| color.ansi }
  end

  def colors_by_base(term_colors = 256)
    colors(term_colors).sort do |c1, c2|
      if c1.base == c2.base
        c1.ansi <=> c2.ansi
      else
        c1.base <=> c2.base
      end
    end.uniq { |color| color.base }
  end

  def terminal
    colors_by_ansi(256)
  end

  def console
    colors_by_ansi(256).take(16)
  end

  def foreground
    colors_by_base[0x05]
  end

  def background
    colors_by_base[0x00]
  end

  def cursor
    colors_by_base[0x05]
  end

  def bold_colors(term_colors = 256)
    colors_by_base(term_colors).keep_if { |color| color.bold }
  end
end
