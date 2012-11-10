############################################################
# A thunk is a function that takes the current style.
# Return some value (for example, a level, a point, etc.).
# We just wrap it in a Thunk class but really it's just a function.
# In the future, we might want to extend it to store a laziness flag.
class Thunk
  attr_accessor :evalFunc

  def initialize(arg) # arg can either be a evalFunc or another thunk.
    if arg.is_a?(Thunk) then
      @evalFunc = arg.evalFunc
    elsif arg.is_a?(Proc) then
      # arg = lambda {|style| ...}
      @evalFunc = arg
    else
      # Constant
      @evalFunc = lambda{|style| arg}
    end
  end
  def evaluate(style); @evalFunc.call(style) end

  def post(&postFunc); thunk(lambda {|style| postFunc.call(evaluate(style))}) end

  def add(dp); thunk(lambda {|style| evaluate(style).add(thunk(dp).evaluate(style))}) end
  def sub(dp); post{|p| p.sub(dp)} end
  def mul(dx); post{|p| p.mul(dx)} end
  def div(dx); post{|p| p.div(dx)} end
  def xpart; post{|p| p.xpart} end
  def ypart; post{|p| p.ypart} end
end
def thunk(evalFunc); Thunk.new(evalFunc) end

def tlevel; thunk(lambda {|style| style.getLevel}) end
def tstartlevel; tlevel.post{|l| l[0] || 0} end
def tstartlevelplus(v=1); tlevel.post{|l| (l[0] || 0) + v} end

# Return the object specified by the labelPath, which can either be a label or
# object.
def tobj(obj, *labelPath)
  if labelPath.size == 0 then
    thunk(obj)
  else
    thunk(obj).post {|obj|
      picNode = obj.findPicNode(*labelPath)
      raise "Path not found from #{obj.class}: #{labelPath.inspect}" unless picNode
      raise "No object" unless picNode.obj
      picNode.obj
    }
  end
end

# Return the point position of an object.
def tpoint(xi, yi, obj, *labelPath)
  tobj(obj, *labelPath).post {|obj|
    raise "Object #{obj.class} has not been printed yet" unless obj.printedPicNode
    obj.printedPicNode.getPoint(xi, yi)
  }
end
def tcenter(obj, *labelPath); tpoint(0, 0, obj, *labelPath) end
def tleft(obj, *labelPath); tpoint(-1, 0, obj, *labelPath) end
def tright(obj, *labelPath); tpoint(+1, 0, obj, *labelPath) end
def tdown(obj, *labelPath); tpoint(0, -1, obj, *labelPath) end
def tup(obj, *labelPath); tpoint(0, +1, obj, *labelPath) end
def tupperright(obj, *labelPath); tpoint(+1, +1, obj, *labelPath) end
def tupperleft(obj, *labelPath); tpoint(-1, +1, obj, *labelPath) end
def tlowerright(obj, *labelPath); tpoint(+1, -1, obj, *labelPath) end
def tlowerleft(obj, *labelPath); tpoint(-1, -1, obj, *labelPath) end

# Return the width/height of an object.
def twidth(obj, *labelPath); tobj(obj, *labelPath).post{|obj| obj.printedPicNode.width} end
def theight(obj, *labelPath); tobj(obj, *labelPath).post{|obj| obj.printedPicNode.height} end

def tmediation(f, p1, p2); thunk(lambda{|style| Value.mediation(f, thunk(p1).evaluate(style), thunk(p2).evaluate(style))}) end
def tmidpoint(p1, p2); thunk(lambda{|style| Value.midpoint(thunk(p1).evaluate(style), thunk(p2).evaluate(style))}) end
def tpair(x, y); thunk(lambda{|style| Value.pair(x.evaluate(style), y.evaluate(style))}) end
def tadd(p1, p2); thunk(lambda{|style| p1.evaluate(style).add(p2.evaluate(style))}) end
def tsub(p1, p2); thunk(lambda{|style| p1.evaluate(style).sub(p2.evaluate(style))}) end
def txdist(p1, p2); thunk(lambda{|style| thunk(p1).evaluate(style).xpart.sub(thunk(p2).evaluate(style).xpart).abs}) end
def tydist(p1, p2); thunk(lambda{|style| thunk(p1).evaluate(style).ypart.sub(thunk(p2).evaluate(style).ypart).abs}) end
