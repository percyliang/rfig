############################################################
# A style doubles as both the environment under which nodes are printed and a
# specification of that environment.  Note that things like scaling and
# shifting are not additive, although we could make additive versions.
# A style also has a variable map.

class Style
  def initialize(parentStyle=nil)
    @level = []
    @dimLevel = []
    @variableMap = {} # name -> variable
    @parentStyle = parentStyle
  end

  def _assert(v, type)
    v.assertType(type) if v && (not v.is_a?(Thunk))
  end

  def color(v);     @color = v; _assert(v, :color);   self end # Color
  def shift(v);     @shift = v; _assert(v, :pair);    self end # Shift
  def slant(v);     @slant = v;                 self end # Slant
  def size(v);      @scale = v;                 self end # Magnification scale
  def scale(v);     @scale = v * (@scale||1);   self end # Magnification scale
  def xscale(v);    @xscale = v * (@xscale||1); self end # Magnification scale (x)
  def yscale(v);    @yscale = v * (@yscale||1); self end # Magnification scale (y)
  def rotate(v);    @rotate = v;                self end # Rotation (degrees)
  def bold(v=true); @bold = v;                  self end # Bold
  # If this style is incorporated into another,
  # persistent is how far up the ancestry it should be applied
  # FUTURE: persistent doesn't work for any other style other than 
  # at the end (anything other than level)???
  def persistent(v=$infty); @persistent = v;          self end
  def let(name, var);       @variableMap[name] = var; self end # Variables

  def getColor;             @color                      end
  def getShift;             @shift                      end
  def getSlant;             @slant                      end
  def getScale;             @scale                      end
  def getXScale;            @xscale                     end
  def getYScale;            @yscale                     end
  def getRotate;            @rotate                     end
  def getLevel;             @level                      end
  def getDimLevel;          @dimLevel                   end # When the picture is to be dimmed
  def getBold;              @bold                       end
  def getPersistent;        @persistent                 end
  # Display levels are specified as an array (min, max, min, max, ...)
  def level(*v);            @level    = v.or(@level);    self end
  def dimLevel(*v);         @dimLevel = v.or(@dimLevel) if not ($presentation && $presentation.getPrintMaximal); self end
  def getVariableMap; @variableMap end

  def getParentStyle; @parentStyle end

  # Multiply in the scales of self and its ancestors
  def getCumulativeScale
    style = self
    x = 1
    while style do
      x *= style.getScale if style.getScale
      style = style.getParentStyle
    end
    x
  end

  def applySpatialStyleToPic(pic)
    pic = pic.scale(getScale) # Scale
    pic = pic.xscale(getXScale) # Scale x
    pic = pic.yscale(getYScale) # Scale y
    pic = pic.rotate(getRotate) # Rotate
    pic = pic.shift(getShift) # Shift
    pic = pic.slant(getSlant) # Slant
    pic
  end

  def applyStyleToPicNode(picNode)
    pic = picNode.pic
    pic = applySpatialStyleToPic(pic)
    if (not picNode.colored) && getColor # Color only once
      pic = pic.color(getColor)
      picNode.colored = true
    end

    # Things that can't be recovered from absolute position
    # Need them for externalfigure
    #picNode.rotated = (picNode.rotated || 0) + getRotate if getRotate
    #picNode.slanted = (picNode.slanted || 0) + getSlant if getSlant
    #debug pic

    pic
  end

  # Get the effective style 
  # The internal style should override any initial style (self).
  def createEffectiveStyle(internalStyle, ignoreSpatialStyles)
    Style.new(self).incorporate!(self, 0, ignoreSpatialStyles).incorporate!(internalStyle, 0, false)
  end

  # Children style should *not* contain those things that the parent
  # would apply anyway (such as rotating, scaling), so as to avoid
  # performing the same operation twice
  # Note: don't use internal style
  def createChildrenStyle
    Style.new(self).incorporate!(self, 0, true)
  end

  # Useful when children are arranged in a hierarchy, e.g. rows in a table
  # Like getChildren style, but not for children
  def createDuplicateStyle
    Style.new(self).incorporate!(self, 0, false)
  end

  # If x is a thunk, call its function.
  def evaluateThunk(x)
    if x.is_a?(Array) then
      x.map { |y| evaluateThunk(y) }
    elsif x.is_a?(Symbol) then
      y = @variableMap[x] or raise "Unbound variable name: '#{x}'"
      evaluateThunk(y)
    elsif x.is_a?(Thunk) then
      x.evaluate(self)
    else
      x
    end
  end

  def evaluateThunks!
    @color = evaluateThunk(@color)
    @shift = evaluateThunk(@shift)
    @slant = evaluateThunk(@slant)
    @scale = evaluateThunk(@scale)
    @xscale = evaluateThunk(@xscale)
    @yscale = evaluateThunk(@yscale)
    @rotate = evaluateThunk(@rotate)
    @bold = evaluateThunk(@bold)
    @persistent = evaluateThunk(@persistent)
    @level = evaluateThunk(@level)
    @dimLevel = evaluateThunk(@dimLevel)
    @variableMap.each_pair { |name,value|
      @variableMap[name] = evaluateThunk(value)
    }
    self
  end

  # Incorporate style: style overwrites any values belonging to self.
  # - persistent is an integer specifying the number of ancestors to propagate
  #   the incorporation
  # - ignoreSpatialStyles: if this is on, then we do not incorporate spatial
  #   styles, the ones that are not idempotent.  There are two reasons
  #   why we might want this: (1) self is a children style and the parent
  #   is going to recursively apply the style anyway; (2) our object position
  #   depends on another object's absolute position, and we don't want to
  #   change it.
  # Evaluate thunks based on object.
  def incorporate!(style, persistent, ignoreSpatialStyles)
    return self unless style
    persistent = persistent || style.getPersistent || 0
    return if persistent < 0

    if style.is_a?(DeltaStyle) then
      style.change(self)
    else
      if not ignoreSpatialStyles then
        @shift = style.getShift || @shift
        @slant = style.getSlant || @slant
        @scale = style.getScale || @scale
        @xscale = style.getXScale || @xscale
        @yscale = style.getYScale || @yscale
        @rotate = style.getRotate || @rotate
      end
      @color = style.getColor || @color
      @bold        = style.getBold || @bold
      @persistent  = style.getPersistent || @persistent
      @level       = style.getLevel.or(@level)
      @dimLevel    = style.getDimLevel.or(@dimLevel)

      # Copy over variable map
      style.getVariableMap.each_pair { |name,value|
        @variableMap[name] = value
      }
    end

    evaluateThunks!
    getParentStyle.incorporate!(style, persistent-1, ignoreSpatialStyles) if getParentStyle
    self
  end

  def incorporateExternalStyle!(style)
    incorporate!(style, nil, false)
  end

  def nil; self end
end

############################################################
# Modify styles.

class DeltaStyle
  def getDLevel; @dLevel end
  def getPersistent; @persistent end
  def persistent(v=true); @persistent = v; self end

  def hasPause; @dLevel && @dLevel > 0 end

  def pause(d=1); @dLevel = d; @persistent = $infty; self end # Increment the display level
  def change(style, persistent=nil)
    # Change level only if previous one didn't have a level
    style.level((style.getLevel[0] || 0) + @dLevel) if @dLevel
  end
end

def color(v);         Style.new.color(v)                  end
def shift(v);         Style.new.shift(v)                  end
def slant(v);         Style.new.slant(v)                  end
def scale(v);         Style.new.scale(v)                  end
def xscale(v);        Style.new.xscale(v)                 end
def yscale(v);        Style.new.yscale(v)                 end
def rotate(v);        Style.new.rotate(v)                 end
def level(*v)         Style.new.level(*v)                 end
def plevel(*v)        Style.new.level(*v).persistent      end
def dimLevel(*v)      Style.new.dimLevel(*v)              end
def bold;             Style.new.bold                      end
def let(name, var);   Style.new.let(name, var)            end
def plet(name, var);  Style.new.let(name, var).persistent end
def pause(d=1);       DeltaStyle.new.pause(d)             end
def localpause(d=1);  pause(d).persistent(0)              end
