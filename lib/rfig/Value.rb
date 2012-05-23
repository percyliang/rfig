############################################################
# Values for metapost.  FUTURE: make this more strongly typed.

# Possible types: numeric, pair, path, picture
class Value
  attr_reader :type, :value

  # Construct
  def Value.numeric(value);     Value.new(value,                  :numeric) end
  def Value.picture(value);     Value.new(value || "nullpicture", :picture) end
  def Value.pair(x, y=nil);     Value.new(y ? "(#{x},#{y})" : x,  :pair)    end
  def Value.path(value);        Value.new(value,                  :path)    end
  def Value.color(r, g, b);     Value.new("(#{roundExcess(r)},#{roundExcess(g)},#{roundExcess(b)})", :color)   end
  def Value.icolor(r, g, b);    Value.color(r/256.0, g/256.0, b/256.0)      end
  def Value.zero;               Value.numeric(0)   end
  def Value.origin;             Value.pair(0, 0)   end
  def Value.nullPicture;        Value.picture(nil) end
  def Value.xpair(x);           Value.pair(x, 0)   end
  def Value.ypair(y);           Value.pair(0, y)   end

  def Value.mean(v1, v2); v1.assertType(:numeric); v2.assertType(:numeric); "(((#{v1})+(#{v2}))/2)" end
  def Value.midpoint(p1, p2); p1.assertType(:pair); p2.assertType(:pair); Value.pair(".5[#{p1}, #{p2}]") end
  def Value.mediation(f, p1, p2); p1.assertType(:pair); p2.assertType(:pair); Value.pair("#{f}[#{p1}, #{p2}]") end
  def Value.intersectionPoint(path1, path2); path1.assertType(:path); path2.assertType(:path); Value.pair("((#{path1}) intersectionpoint (#{path2}))") end
  def Value.max(num1, num2)
    num1.assertType(:numeric)
    num2.assertType(:numeric)
    Value.numeric("max(#{num1}, #{num2})")
  end
  def Value.min(num1, num2)
    num1.assertType(:numeric)
    num2.assertType(:numeric)
    Value.numeric("min(#{num1}, #{num2})")
  end
  def Value.rectllur(p1, p2)
    Value.path("("+[
      p1, Value.pair(p1.xpart, p2.ypart),
      p2, Value.pair(p2.xpart, p1.ypart), 'cycle'].join('--')+")")
  end

  def initialize(value, type)
    @value = value.to_s
    @type = type
  end
  def to_s; @value end

  def xpart
    assertType(:pair)
    Value.numeric(@value =~ /^\(([^,]+),([^\)]+)\)$/ ? $1 : "xpart #{@value}")
  end
  def ypart
    assertType(:pair)
    Value.numeric(@value =~ /^\(([^,]+),([^\)]+)\)$/ ? $2 : "ypart #{@value}")
  end
  def negate; assertVector; Value.new("-#{@value}", @type) end
  def add(p); assertVector; p ? Value.new("((#{@value})+(#{p}))", @type) : self end
  def sub(p); assertVector; p ? Value.new("((#{@value})-(#{p}))", @type) : self end
  def mul(p); assertVector; p ? Value.new("((#{@value})*(#{p}))", @type) : self end
  def div(p); assertVector; p ? Value.new("((#{@value})/(#{p}))", @type) : self end
  def abs; assertType(:numeric); Value.new("abs(#{@value})", @type) end

  def length; assertType(:pair); Value.pair("arclength ((0, 0)--(#{@value}))") end # Length of a 
  def angle; assertType(:pair); Value.pair("angle(xpart(#{@value}), ypart(#{@value}))") end
  def xadd(x); assertType(:pair); add(Value.xpair(x)) end
  def yadd(y); assertType(:pair); add(Value.ypair(y)) end

  def width;  assertType(:picture, :path); Value.numeric("W(#{@value})") end
  def height; assertType(:picture, :path); Value.numeric("H(#{@value})") end
  def getPoint(xi, yi)
    assertType(:picture, :path)
    return Value.pair("ulcorner #{@value}") if xi == -1 && yi == +1
    return Value.pair("urcorner #{@value}") if xi == +1 && yi == +1
    return Value.pair("llcorner #{@value}") if xi == -1 && yi == -1
    return Value.pair("lrcorner #{@value}") if xi == +1 && yi == -1
    return Value.pair("center #{@value}")   if xi ==  0 && yi ==  0
    return Value.pair("0.5[llcorner #{@value}, ulcorner #{@value}]") if xi == -1 && yi ==  0
    return Value.pair("0.5[lrcorner #{@value}, urcorner #{@value}]") if xi == +1 && yi ==  0
    return Value.pair("0.5[llcorner #{@value}, lrcorner #{@value}]") if xi ==  0 && yi == -1
    return Value.pair("0.5[ulcorner #{@value}, urcorner #{@value}]") if xi ==  0 && yi == +1
    return Value.pair("#{(xi+1.0)/2}[#{(yi+1.0)/2}[llcorner #{@value}, ulcorner #{@value}], #{(yi+1.0)/2}[lrcorner #{@value}, urcorner #{@value}]]")
    raise "Bad #{xi} #{yi}"
  end
  def center; getPoint(0, 0) end

  def bbox
    assertType(:picture)
    Value.path("(ulcorner #{@value}--urcorner #{@value}--lrcorner #{@value}--llcorner #{@value}--cycle)")
  end
  def scale(scale)
    assertType(:picture)
    scale ? Value.picture("#{@value} scaled #{scale}") : self
  end
  def xscale(xscale)
    assertType(:picture)
    xscale ? Value.picture("#{@value} xscaled #{xscale}") : self
  end
  def yscale(yscale)
    assertType(:picture)
    yscale ? Value.picture("#{@value} yscaled #{yscale}") : self
  end
  def rotate(deg)
    assertType(:picture)
    deg ? Value.picture("#{@value} rotated #{deg}") : self
  end
  def shift(z)
    assertType(:picture)
    z ? Value.picture("#{@value} shifted #{z}") : self
  end
  def slant(z)
    assertType(:picture)
    z ? Value.picture("#{@value} slanted #{z}") : self
  end
  def color(color)
    assertType(:picture)
    color ? Value.picture("image(draw #{@value} withcolor #{color})") : self
  end

  def assertType(*types)
    types.each { |type| return if type == @type }
    raise "Type mis-match; wanted #{types.join(' or ')}, got #{@type}"
  end
  def assertVector
    assertType(:numeric, :pair, :color)
  end

  # 3u -> 3
  def u
    assertType(:numeric)
    if @value =~ /^(.+)u$/ then
      $1.to_f
    else
      raise "Don\'t know how to handle: '#{@value}'"
    end
  end

  # (0.3,0.5,1)
  def triple
    assertType(:color)
    if @value =~ /^\((.+),(.+),(.+)\)$/ then
      [$1.to_f, $2.to_f, $3.to_f]
    else
      raise "Don\'t know how to handle: '#{@value}'"
    end
  end
end

############################################################
# Colors

#def black;        Value.color(0, 0, 0)          end
#def gray;         Value.color(0.5, 0.5, 0.5)    end
#def lightgray;    Value.color(0.75, 0.75, 0.75) end
#def white;        Value.color(1, 1, 1)          end
#
#def red;          Value.color(1, 0, 0)          end
#def green;        Value.color(0, 1, 0)          end
#def blue;         Value.color(0, 0, 1)          end
#def darkred;      Value.color(0.5, 0, 0)        end
#def darkgreen;    Value.color(0, 0.5, 0)        end
#def darkblue;     Value.color(0, 0, 0.5)        end
#
#def magenta;      Value.color(1, 0, 1)          end
#def darkmagenta;  Value.color(0.5, 0, 0.5)      end
#def yellow;       Value.color(1, 1, 0)          end
#def darkyellow;   Value.color(0.5, 0.5, 0)      end
#def orangetwo;    Value.icolor(238, 154, 0)     end
#
#def olivegreen;   Value.icolor(120, 144, 0)     end
#def brown;        Value.icolor(165, 42, 42)     end
#def dodgerblue;   Value.icolor(30, 144, 255)    end
