############################################################
# Base class for circles, polygons, etc.
# Note that xscale and yscale are just for specifying the dimensions of the
# shape and are separate form the scaling present in style, which would make
# the lines thicker.
# If yscale is null, then use xscale.
class Shape < Obj
  def initialize(xscale, yscale, autoScale)
    super()
    @xscale = xscale
    @yscale = yscale || xscale
    @autoScale = autoScale
  end

  def dashed(v='withdots'); @dashed      = v;           self end
  def fill;                 @fill        = true;        self end
  def thickness(v);         @thickness   = v;           self end
  def shapeXScale(v);       @xscale      = v;           self end
  def shapeYScale(v);       @yscale      = v;           self end
  def shapeScale(v);        @xscale = @yscale = v;      self end

  def getShape(style); raise 'Override me' end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    @xscale = style.evaluateThunk(@xscale)
    @yscale = style.evaluateThunk(@yscale)
    shape = getShape(style)

    drawCmd = @fill ? "fill" : "draw"
    tail = ""
    tail += " xscaled #{@xscale}" if @xscale && (not @autoScale)
    tail += " yscaled #{@yscale}" if @yscale && (not @autoScale)
    tail += " withpen pencircle scaled #{@thickness}" if @thickness
    tail += " dashed #{@dashed}" if @dashed
    pic = Value.picture("image(#{drawCmd} #{shape}#{tail})")
    initFinishPicNode(writer, style, pic)
  end

  def inspect; self.class end
end

############################################################
class Circle < Shape
  def initialize(xscale, yscale=nil); super(xscale, yscale, false) end
  def getShape(style); 'fullcircle' end
end
def circle(xscale, yscale=nil); Circle.new(xscale, yscale) end

############################################################
class Rect < Shape
  def rounded(v); @rounded = v; self end
  # Don't autoscale; build it right into the shape; don't know why I did this
  def initialize(xscale=nil, yscale=nil); super(xscale, yscale, true) end
  def getShape(style)
    if @rounded
      r, x, y = @rounded, @xscale, @yscale
      "(0,#{r})--(0,#{y.sub(r)}){up}..(#{r},#{y})--(#{x.sub(r)},#{y}){right}..(#{x},#{y.sub(r)})--(#{x},#{r}){down}..(#{x.sub(r)},0)--(#{r},0){left}..cycle"
    else
      "(0,0)--(0,#{@yscale})--(#{@xscale},#{@yscale})--(#{@xscale},0)--cycle"
    end
  end
end
def rect(xscale, yscale=nil); Rect.new(xscale, yscale) end
def rectllur(ll, ur) # Specify lower-left and upper-right points
  xscale = ur.xpart.sub(ll.xpart)
  yscale = ur.ypart.sub(ll.ypart)
  rect(xscale, yscale).shift(ll)
end

############################################################
class Polygon < Shape
  def initialize(points); super(nil, nil, false); @points = points end
  def getShape(style)
    @points = style.evaluateThunk(@points)
    @points.join('--')+'--cycle'
  end
end
def polygon(*points); Polygon.new(points) end
def diamond(xscale, yscale=nil)
  yscale = xscale unless yscale
  polygon(Value.pair(xscale.negate, 0), Value.pair(0, yscale), Value.pair(xscale, 0), Value.pair(0, yscale.negate))
end

# Create a shape that fits around the given object.
# If object is printed, then print it, otherwise; use the one already printed.
def enshape(options, &modifyShape)
  obj = options[:obj] or raise 'Missing object'
  obj = _(obj)
  isNewObj = options[:isNewObj] == nil ?
    (not obj.printedPicNode) : options[:isNewObj]
  fill = options[:fill]
  createShape = options[:createShape] or raise 'Missing shape creator' # Width, height -> object
  if options[:expand] then
    expand = options[:expand]
    w, h = twidth(obj).mul(expand), theight(obj).mul(expand)
  else
    margin = options[:margin] || u(0.1)
    w, h = twidth(obj).add(margin.mul(2)), theight(obj).add(margin.mul(2))
  end
  shape = createShape.call(w, h)
  shape = modifyShape.call(shape) if modifyShape
  contents = []
  if fill then
    fillShape = createShape.call(w, h)
    fillShape = modifyShape.call(fillShape) if modifyShape
    fillShape.fill.color(white)
    contents << fillShape
  end
  isNewObj ? centeredOverlay(*(contents+[obj, shape])) :
             centeredOverlay(*(contents+[shape])).shift(tcenter(obj))
             
end

# Return a ellipse around the object.
def encircle(options, &modifyShape)
  options[:createShape] = lambda { |w,h| circle(w, h) }
  enshape(options, &modifyShape) 
end
def redEncircle(options, &modifyShape)
  options[:expand] = 1.5 unless options[:expand] || options[:margin]
  encircle(options) { |shape|
    shape.color(red).thickness(3)
    modifyShape.call(shape) if modifyShape
    shape
  }
end

# Return a rectangle around the object.
def enrect(options, &modifyShape)
  options[:createShape] = lambda { |w,h| rect(w, h) }
  enshape(options, &modifyShape)
end
