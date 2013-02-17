$defaultArrowSize = 6
class Path < Obj
  attr_accessor :points

  def initialize(points)
    super()
    @points = filterObjArgs(points)
    @dir = [nil] * points.length # Directions (when curved)
  end

  def getReverse; @reverse end
  def getArrowSize; @arrowSize || $defaultArrowSize end
  def getType; @type end

  def type(t);              @type        = t;           self end
  def normal;               @type        = :normal;     self end
  def arrow;                @type        = :arrow;      self end
  def reverse;              @reverse     = true;        self end
  def dblarrow;             @type        = :dblarrow;   self end
  def fill;                 @type        = :fill;       self end
  def closed;               @closed      = true;        self end
  def curved;               @curved      = true;        self end
  def dashed(v='withdots'); @dashed      = v;           self end # Other possibility: evenly (longer)
  def thickness(v);         @thickness   = v;           self end
  def arrowSize(v);         @arrowSize   = v;           self end
  def linecap(v);           @linecap     = v;           self end
  def dir(i, v);            @dir[i]      = v;           self end
  def begindir(v);          dir(0, v);                  self end
  def enddir(v);            dir(-1, v);                 self end
  def beginClipObj(v); @beginClipObj = v;        self end
  def endClipObj(v); @endClipObj = v;            self end
  def beginIsCircle(v=true); @beginIsCircle = v; self end
  def endIsCircle(v=true); @endIsCircle = v;     self end
  def tension(v); @tension = v; self end # How squigly the curves should be

  def getPathValue
    def getSep; @curved ? ".." : "--" end
    Value.path(@points.map_with_index { |p,i|
      d = @dir[i]
      if d == nil then
        d = ""
      else
        d = "dir(#{d})" if d.is_a?(Fixnum)
        d = "{#{d}}"
      end
      d += "#{getSep} tension #{@tension}" if @tension && i+1 < @points.size
      p.to_s+d+((i+1) % 10 == 0 ? "\n" : "") # Prevent lines from getting too long
    }.join(getSep))
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    @points = style.evaluateThunk(@points)
    @beginClipObj = style.evaluateThunk(@beginClipObj)
    @endClipObj = style.evaluateThunk(@endClipObj)
    clipEndPoints!
    @points = @points.reverse if @reverse

    case @type
      when :normal   then drawCmd = "draw"
      when :arrow    then drawCmd = "drawarrow"
      when :dblarrow then drawCmd = "drawdblarrow"
      when :fill     then drawCmd = "fill"
      else                drawCmd = "draw"
    end
    tail = @closed ? getSep + "cycle" : ""
    head = ""

    tail += " withpen pencircle scaled #{@thickness}" if @thickness
    tail += " dashed #{@dashed}" if @dashed
    head += "linecap := #{@linecap}; " if @linecap
    arrowSize = getArrowSize
    head += "tmp := ahlength; ahlength := #{arrowSize}; " if arrowSize
    tail += "; ahlength := tmp" if arrowSize

    pic = Value.picture("image(#{head}#{drawCmd} #{getPathValue}#{tail})")
    initFinishPicNode(writer, style, pic)
  end

  # Replace the end points with points with intersections of the clip objects
  def clipEndPoints!
    # Return a path value representing the tightest fit
    def getEnclosure(obj, bbox, isCircle)
      x = bbox.width
      y = bbox.height
      center = bbox.center
      if isCircle || obj.is_a?(Circle)
        # Find the inscribing circle
        Value.path("(fullcircle xscaled #{x} yscaled #{y} shifted #{center})") # HACK
      elsif obj.is_a?(Polygon) # 01/17/09: added this for diamond polygon 
        # Assume that obj.getShape is centered around 0
        Value.path("(" + obj.getShape(@style) + ") shifted (#{center})") # HACK
      else
        bbox
      end
    end

    def intersectionPoint(path, obj, isCircle) # Return point of intersect of path with object
      picNode = obj.printedPicNode
      bbox = picNode.pic.bbox
      enc = getEnclosure(obj, bbox, isCircle)
      Value.intersectionPoint(path, enc)
    end

    path = getPathValue
    # Replace end points with the intersection with the path
    @points[0] = intersectionPoint(path, @beginClipObj, @beginIsCircle) if @beginClipObj
    @points[-1] = intersectionPoint(path, @endClipObj, @endIsCircle) if @endClipObj
  end
end

def path(*points); Path.new(points); end

def edge(p1, p2, f=0); # f is fraction of the length to remove on each side
  if f == 0 then path(p1, p2)
  else           path(tmediation(f, p1, p2), tmediation(1-f, p1, p2))
  end
end
def arrow(p1, p2, f=0); edge(p1, p2, f).type(:arrow) end

def vedge(d=u(1));          path(Value.origin, Value.pair(0, d)) end
def hedge(d=u(1));          path(Value.origin, Value.pair(d, 0)) end
def leftarrow(d=u(1));      path(Value.origin, Value.pair(d.negate, 0)).type(:arrow) end
def rightarrow(d=u(1));     path(Value.origin, Value.pair(d, 0)).type(:arrow) end
def downarrow(d=u(1));      path(Value.origin, Value.pair(0, d.negate)).type(:arrow) end
def uparrow(d=u(1));        path(Value.origin, Value.pair(0, d)).type(:arrow) end
def downrightarrow(d=u(1)); path(Value.origin, Value.pair(d, d.negate)).type(:arrow) end
def downleftarrow(d=u(1));  path(Value.origin, Value.pair(d.negate, d.negate)).type(:arrow) end
def uprightarrow(d=u(1));   path(Value.origin, Value.pair(d, d)).type(:arrow) end
def upleftarrow(d=u(1));    path(Value.origin, Value.pair(d.negate, d)).type(:arrow) end

def clippedpath(obj1, obj2, *midPoints)
  path(*([tcenter(obj1)] + midPoints + [tcenter(obj2)])).
    beginClipObj(obj1).endClipObj(obj2)
end
def clippedpath1(obj1, pt2, *midPoints)
  path(*([tcenter(obj1)] + midPoints + [pt2])).beginClipObj(obj1)
end
def clippedpath2(pt1, obj2, *midPoints)
  path(*([pt1] + midPoints + [tcenter(obj2)])).endClipObj(obj2)
end

# To create white space, use white edges (FUTURE: make a better solution, if the background isn't white)
def vspace(d=u(1));  path(Value.origin, Value.pair(0, d)).color(white) end
def hspace(d=u(1));  path(Value.origin, Value.pair(d, 0)).color(white) end
def cr; vspace(u(0.1)) end # Carriage return
