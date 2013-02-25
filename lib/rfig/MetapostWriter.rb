############################################################

require 'rfig/FigWriter'

# Generates outPrefix
class MetapostWriter < FigWriter
  def getTextScale; @textScale end

  # defaultFont is either sans-serif or times
  # Right now, if sans-serif, then use foils, otherwise use article
  # (and increase the font size).
  def init(outPrefix, latexHeader, defaultFont, fontSize, verbose)
    isMac = (/darwin/ =~ RUBY_PLATFORM) != nil
    super(outPrefix, verbose)
    @mpPath = outPrefix+".mp"

    ExternalCommand.exec(:command => 'mkdir', :args => ['-p', File.dirname(@mpPath)])

    @out = open(@mpPath, "w")
    @numPages = 0

    # Font size
    fontSize = 30*fontSize if fontSize <= 1 # A fraction
    @documentClass = "article" # Default font size is 12pt
    @textScale = fontSize/12.0
    @textScale = round(@textScale, 2)
    case defaultFont
      when 'times' then family = '\rmdefault'
      when 'sans-serif' then family = '\sfdefault'
      else raise "Unknown font: #{defaultFont}, only times and sans-serif supported now"
    end

    @prefixes = { :numeric => "n", :pair => "r", :path => "h", :picture => "p", :color => "c" }
    @counts = {} # Indices for variables

    verbatimTex(<<EOF
%&latex
\\documentclass{#{@documentClass}}
\\usepackage{color,amsmath,amssymb,ulem,verbatim,ifthen}
\\renewcommand{\\familydefault}{#{family}}
EOF
    )
    verbatimTex($latexColorDefinitions) # See Colors.rb (automatically generated)
    verbatimTex(latexHeader)
    verbatimTex(<<EOF
\\begin{document}
EOF
    )
    # Need to define width and height as W and H;
    # otherwise metapost thinks lines are too long
    if !isMac; @out.puts "input mp-spec;\n"; end
    @out.puts <<EOF
vardef W(expr p)  = xpart(urcorner p) - xpart(ulcorner p) enddef;
vardef H(expr p) = ypart(urcorner p) - ypart(lrcorner p) enddef;
u := 1in;

% Change bounds to include potential ascenders and descenders
textyl := ypart llcorner image(draw btex g etex);
textyu := ypart ulcorner image(draw btex l etex);
def hackTextBounds =
  setbounds currentpicture to ((xpart llcorner currentpicture), min(ypart llcorner currentpicture, textyl))--
                              ((xpart lrcorner currentpicture), min(ypart lrcorner currentpicture, textyl))--
                              ((xpart urcorner currentpicture), max(ypart urcorner currentpicture, textyu))--
                              ((xpart ulcorner currentpicture), max(ypart ulcorner currentpicture, textyu))--
                              cycle;
enddef;
EOF
    @prefixes.each_pair { |k,v| @out.puts "#{k} #{v}[];" }
  end
  def finish
    return unless opened?
    super()
    @out.puts "end;"
    @out.close
    mpPath = @mpPath
    @mpPath = nil
    mpPath
  end

  def store(val);
    def newVar(type)
      r = @counts[type] || 0
      @counts[type] = r+1
      Value.new(@prefixes[type]+r.to_s, type)
    end
    var = newVar(val.type)
    set(var, val);
    var
  end
  def comment(str); @out.puts "% #{str}" end

  def addToPicture(targetPic, srcPic)
    @out.puts "addto #{targetPic} also #{srcPic};"
  end

  def text(str, useRawBounds)
    h = useRawBounds ? "" : "; hackTextBounds"
    Value.picture(str && (str != "") && "image(draw btex #{str} etex#{h}) scaled #{@textScale}")
  end

  # Side-effects: modify variables
  def set(var, val)
    printCommand("#{var} := #{val};")
  end
  def incr(num, x)
    num.assertType(:numeric)
    printCommand("#{num} := #{num} + #{x};")
  end
  def incrPair(pair, x, y)
    pair.assertType(:pair)
    printCommand("#{pair} := #{pair} + #{Value.pair(x || 0, y || 0)};")
  end
  def decrPair(pair, x, y)
    pair.assertType(:pair)
    printCommand("#{pair} := #{pair} - #{Value.pair(x || 0, y || 0)};")
  end
  def setBounds(pic, x1, y1=nil, x2=nil, y2=nil)
    # Either (x1, y1, x2, y2) form a box or x1 itself is a rectangle
    if y1
      printCommand("setbounds #{pic} to (#{x1},#{y1})--(#{x1},#{y2})--(#{x2},#{y2})--(#{x2},#{y1})--cycle;")
    else
      printCommand("setbounds #{pic} to #{x1};")
    end
  end

  # Return set of nodes that were drawn and the commands to draw it.
  def drawPictureNode(rootPicNode, level)
    # Bounds is [a1, b1, a2, b2, a3, b3, ...]
    # Return true if the level is in any [ai, bi]
    def inLevel(level, bounds, defaultLower)
      return defaultLower <= level unless bounds.compact.size > 0
      bounds.each_index { |i|
        next unless i % 2 == 0
        a, b = bounds[i..i+1]
        return true if (a || defaultLower) <= level && level < (b || $infty)
      }
      false
    end

    #rootPicNode.recurseEach { |p| debug 'UUU' if p.rotated }

    # drawn: set of picture nodes drawnNodes
    drawnNodes = {}
    commands = []
    commands << "beginfig(#{@numPages});"
    @numPages += 1
    rootPicNode.recurseEachLeaf { |picNode|
      # Skip if we shouldn't draw it (not in interval)
      next unless inLevel(level, picNode.level, 0)

      #debug picNode.pic
      if not (picNode.obj.is_a?(Str) && picNode.obj.value == '') # Empty strings don't count
        drawnNodes[picNode] = true
      end
      # Dim things that are not already white
      isInvisible = picNode.obj && picNode.obj.getStyle.getColor.to_s == white.to_s
      if inLevel(level, picNode.dimLevel, $infty) && (not isInvisible) then
        commands << "draw #{picNode.pic} withcolor (0.75, 0.75, 0.75);"
      else
        commands << "draw #{picNode.pic};"
      end

      # Draw image if it exists
      if picNode.imagePath then
        # Doesn't handle rotation
        size = store(Value.pair(picNode.pic.width, picNode.pic.height))
        loc = store(picNode.pic.getPoint(-1, -1))
        raise "Rotation of images not supported" if picNode.style.getRotate
        list = ["externalfigure \"#{picNode.imagePath}\""]
        list << "xyscaled #{size}"
        list << "shifted #{loc}"
        commands << list.join(' ')+';'

        # externalfigure is not a picture, but use the picNode infrastructure
        # to apply the styles that were applied to the placeholder rectangle (picNode)
        #pic = Value.picture("externalfigure \"#{picNode.imagePath}\"")
        #pic = pic.xscale(picNode.imageSize[0]).yscale(picNode.imageSize[1])
        #pic = picNode.style.applySpatialStyleToPic(pic)

        # Hack: unfortunately, styles that the ancestors of picNode applied are not stored,
        # so we'll have to apply them too
        #pic = pic.scale(picNode.style.getParentStyle.getCumulativeScale) if picNode.style.getParentStyle

        # Hack: we don't keep track of the origin of the placeholder rectangle,
        # so we have to reverse-engineer things (handle popular cases)
        #pic = pic.shift(store(picNode.pic.getPoint(-1, -1)))
        #if picNode.style.getRotate
        #  rot = picNode.style.getRotate
        #  h, w = picNode.pic.height, picNode.pic.width
        #  offset = nil
        #  case rot
        #    when 270 then offset = Value.pair(0, h)
        #    when 180 then offset = Value.pair(w, h)
        #    when  90 then offset = Value.pair(w, 0)
        #    when   0 then offset = Value.pair(0, 0)
        #    else raise "Rotate by #{rot} not supported"
        #  end
        #  pic = pic.shift(store(offset))
        #end

        #commands << pic.value + ";"
        #debug pic.value
      end
    }
    commands << "endfig;"
    [drawnNodes, commands]
  end

  def printCommands(commands)
    commands.each { |command|
      if command.size > 500
        if command =~ /btex/ # Conserative - don't break
          @out.puts command
        else
          #puts "SPLIT"
          @out.puts command.split(" ")
        end
      else
        @out.puts command
      end
    }
  end
  def printCommand(command); printCommands([command]) end

  def verbatimTex(str)
    return unless str
    @out.puts "verbatimtex"
    @out.puts str
    @out.puts "etex"
  end
end
