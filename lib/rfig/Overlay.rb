############################################################

# Just a set of objects.
# When drawing, just add them without modification.
# However, we can also pivot, which shifts the picture nodes.
# The power of overlays comes in when we can change the bounding box.
class Overlay < Obj
  def objs # Skip styles
    @objs.find_all { |obj| obj.is_a?(Obj) }
  end

  def containsPause
    @objs.any? {|x| x.is_a?(DeltaStyle) && x.hasPause}
  end

  def initialize(objs)
    super()
    @objs = filterObjArgs(objs)
    @ghost = [] # obj -> Whether obj is part of the bounding box
    @pivot = nil # [0, 0] (center): common pivot point that the pictures should share
    @depth = []
  end
  def print(writer, style) 
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    childrenStyle = style.createChildrenStyle

    # Interpret dormant contents
    @newObjs = []
    @objs.each { |row|
      if row.is_a?(DormantContents) then
        # The contents should return a list of objs
        @newObjs += filterObjArgs(row.getContents)
      else
        @newObjs << row
      end
    }
    @objs = @newObjs

    picNodes = []
    @objs.each { |obj|
      if aboutStyle?(obj) then # Interpret external styles
        childrenStyle.incorporateExternalStyle!(obj)
      elsif obj.is_a?(Obj) then
        picNode = obj.print(writer, childrenStyle)
        if @pivot then # Shift the pivot point to the origin
          p = writer.store(picNode.getPoint(*@pivot).negate)
          picNode.shift(writer, p)
        end
        picNodes << picNode
      else
        raise "Unknown type: #{obj.class}"
      end
    }

    rootPicNode = initPicNode(writer, style, Value.nullPicture)

    # Sort picture nodes from largest depth to smallest depth
    picNodes = (0...picNodes.size).sort { |i,j| (@depth[j]||0) <=> (@depth[i]||0) }.map { |i| picNodes[i] }

    # Add the non-ghost nodes
    picNodes.each_with_index { |picNode,i|
      rootPicNode.appendChild(writer, picNode) unless getGhost(i)
    }

    # Save the bounding box
    bbox = writer.store(rootPicNode.pic.bbox) if picNodes.size > 0

    # Add the ghost nodes
    picNodes.each_with_index { |picNode,i|
      rootPicNode.appendChild(writer, picNode) if getGhost(i)
    }

    # Now, restore the bounding box without the ghosts
    writer.setBounds(rootPicNode.pic, bbox) if picNodes.size > 0

    finishPicNode(writer, style)
  end

  def ghosts(is); is.each { |i| @ghost[i] = true }; self end
  def ghost(i); @ghost[i] = true; self end
  def getGhost(i); @ghost[i] || false end
  def depths(vs); @depth = vs; self end
  def depth(i, v); @depth[i] = v; self end
  def getDepth(i); @depth[i] || 0 end
  def pivot(xi, yi); @pivot = [xi, yi]; self end

  def center; pivot(0, 0) end

  def color(v); @objs.each do |o| _(o).color(v); end; self; end

  def inspect; 'Overlay('+@objs.map{|o| o.inspect}.join(', ')+')' end
end

def overlay(*objs); Overlay.new(objs) end

# The objects make an apperance one by one.
# If replace, then hide each object when the next one is shown
# (of course, this doesn't affect the last object).
# Usage: first argument could be a hash of options
def stagger(*args)
  if args[0].is_a?(Hash)
    opts, *objs = args
  else
    opts, objs = {}, args
  end
  objs = filterObjArgs(objs)
  newObjs = [] # With pauses inserted
  lastObj = nil
  lifetime = {}
  # Insert a pause right before every object.
  # Note that some of the elements of objs could be styles.
  objs.each { |obj|
    lifetime[lastObj] += obj.getDLevel if lastObj && obj.is_a?(DeltaStyle) # More pausing, so lifetime needs to increase
    if not modifier?(obj) then
      newObjs << (opts[:pause] || pause) if lastObj
      lifetime[obj] = 1
      lastObj = obj
    end
    newObjs << obj
  }

  # Need to set implement the lifetimes of these objects
  if not opts[:sticky] then
    objs.each_with_index { |obj,i|
      if not modifier?(obj) then
        if obj != lastObj
          # If obj is overlay and contains a pause, then the lifetime should only affect the last element.
          # This is a hack to detect whether obj was created by a stagger.
          o = obj.is_a?(Overlay) && obj.containsPause ? obj.objs[-1] : obj
          o.nlevels(lifetime[obj])
        end
      end
    }
  end
  overlay(*newObjs)
end
