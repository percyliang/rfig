class Str < Obj
  attr :value

  # When computing bounding box of letters, do it directly;
  # don't compensate for descenders and ascenders.
  def useRawBounds(v=true); @useRawBounds = v; self end
  def initialize(value)
    super()
    @value = value
    @useRawBounds = false
  end
  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    value = latexAccents(@value)
    value = style.getBold ? "{\\bf #{value}}" : value
    initFinishPicNode(writer, style, writer.text(value, @useRawBounds))
  end

  def latexAccents(s)
    return nil unless s
    # Another source: http://recodec.progiciels-bpi.ca/showfile.html?name=Recode/latex.py
    s = s.gsub(/é/, '\\\\\'e')
    s = s.gsub(/É/, '\\\\\'E')
    s = s.gsub(/è/, '\\\\`e')
    s = s.gsub(/È/, '\\\\`E')
    s = s.gsub(/ê/, '\\\\^e')
    s = s.gsub(/Ê/, '\\\\^E')
    s = s.gsub(/à/, '\\\\`a')
    s = s.gsub(/À/, '\\\\`A')
    s = s.gsub(/ù/, '\\\\`u')
    s = s.gsub(/Ù/, '\\\\`U')
    s = s.gsub(/â/, '\\\\^a')
    s = s.gsub(/Â/, '\\\\^A')
    s = s.gsub(/î/, '\\\\^i')
    s = s.gsub(/Î/, '\\\\^I')
    s = s.gsub(/ô/, '\\\\^o')
    s = s.gsub(/Ô/, '\\\\^O')
    s = s.gsub(/û/, '\\\\^u')
    s = s.gsub(/Û/, '\\\\^U')
    s = s.gsub(/ä/, '\\\\"a')
    s = s.gsub(/Ä/, '\\\\"A')
    s = s.gsub(/ë/, '\\\\"e')
    s = s.gsub(/Ë/, '\\\\"E')
    s = s.gsub(/ï/, '\\\\"i')
    s = s.gsub(/Ï/, '\\\\"I')
    s = s.gsub(/ö/, '\\\\"o')
    s = s.gsub(/Ö/, '\\\\"O')
    s = s.gsub(/ü/, '\\\\"u')
    s = s.gsub(/Ü/, '\\\\"U')
    s = s.gsub(/ç/, '\\\\c{c}')
    s = s.gsub(/Ç/, '\\\\c{C}')
    s
  end

  def stdHeight; setYBounds('a'); self end

  def collectStrings(strings)
    strings << @value
  end

  def to_s; @value.split(/\n/)[0] end
  def inspect; "Str(#{@value})" end
end

############################################################
# A string, whose parts are shown in various stages by whiting out parts
# The end result is rendering a single LaTeX string
# FUTURE: make it work with color strings.

class LevelStr < Obj
  def initialize(level, args)
    super()
    @level = level
    @args = args
  end

  # Private members
  def maxLevel; ([@level] + @args.map { |x| x.is_a?(LevelStr) ? x.maxLevel : 0 }).max end
  def toStrAtLevel(l)
    (l >= @level ? '\black{' : '\white{') + @args.map { |x| x.is_a?(LevelStr) ? x.toStrAtLevel(l) : x.to_s }.join + '}'
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)

    # Construct the strings at the various levels
    contents = []
    (0..maxLevel).each { |l|
      contents << pause if l > 0 # Pause between strings
      str = _(toStrAtLevel(l)) # Construct the string
      str.nlevels(1) if l < maxLevel # Wipe out all but the last string
      contents << str
    }

    initFinishPicNode(writer, style, overlay(*contents))
  end
end

def levelStr(level, *args); LevelStr.new(level, args) end
def L(level, *args);        LevelStr.new(level, args) end

############################################################

class AutowrapStr < Obj
  def width(v); @width = v; self end

  def align(v); @align = v; self end
  def center; @align = 'center'; self end
  def flushleft; @align = 'flushleft'; self end
  def flushright; @align = 'flushright'; self end
  def flushfull; @align = nil; self end

  # Even if scale, don't change the width?
  def fixedWidth(v); @fixedWidth = v; self end

  def initialize(args)
    super()
    @args = args
    @align = 'flushleft'
    @fixedWidth = true
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)

    # Calculate the actual width (because the text is scaled)
    width = (@width || u(10)).u
    # Change the width so that when we scale back down,
    # the width will be preserved.
    width /= (style.getScale || 1) if @fixedWidth
    #width /= style.getCumulativeScale if @fixedWidth
    lines = []
    lines << "\\begin{minipage}{#{width/writer.getTextScale}in}"
    lines << "\\begin{#{@align}}" if @align
    lines += filterStrArgs(@args)
    lines << "\\end{#{@align}}" if @align
    lines << "\\end{minipage}"
    #obj = _(*lines.join(' '))
    obj = _(lines.join("\n"))

    initFinishPicNode(writer, style, obj)
  end
end
def autowrap(*args); AutowrapStr.new(args) end
