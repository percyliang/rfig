# For drawing nodes and connecting them with edges.
class DNode < Obj
  def initialize(label)
    super()
    label = _(label).useRawBounds if label.is_a?(String)
    @label = label
    @shape = :circle
    @size = u(0.5)
    @boundary = true
  end
  def shape(shape); @shape = shape; self end
  def shaded; @shaded = true; self end
  def opaque; @opaque = true; self end
  def boundary(v=true); @boundary = v; self end
  def size(size); @size = size; self end
  def boundaryPostFunc(&func); @boundaryPostFunc = func; self end
  def _finish
    return if @allObj
    contents = []
    contents << _createBoundObj(true) if @shaded || @opaque
    contents << (@boundObj = _createBoundObj(false))
    contents << _(@label)
    @allObj = overlay(*contents).center
  end
  def _createBoundObj(shaded)
    x = nil
    case @shape
      when :circle then x = circle(@size)
      when :rect then x = rect(@size)
      when :diamond then x = diamond(@size.div(Math.sqrt(2)))
      else raise "Unknown shape: #{@shape}"
    end
    x.fill.color(@shaded ? gray : white) if shaded
    x = @boundaryPostFunc.call(x) if @boundaryPostFunc && (not shaded)
    x.color(white) if not @boundary
    x
  end

  def print(writer, style)
    _finish
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    initFinishPicNode(writer, style, @allObj)
  end
  def getBoundObj; _finish; @boundObj end
end
def dnode(label); DNode.new(label) end
def dedge(n1, n2); clippedpath(n1.is_a?(DNode) ? n1.getBoundObj : n1, n2.is_a?(DNode) ? n2.getBoundObj: n2) end
def darrow(n1, n2); dedge(n1, n2).arrow end
def dedges(*pairs); pairs.map { |pair| dedge(*pair) } end
