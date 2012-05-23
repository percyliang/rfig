$defaultExplodeFactor = 2

# When print is called, @printedPicNode should be set.
class Obj
  attr :printedPicNode

  def initialize; @postProcessors = []; @style = Style.new end

  def color(v);             @style.color(v);              self end
  def shift(v);             @style.shift(v);              self end
  def slant(v);             @style.slant(v);              self end
  def scale(v);             @style.scale(v);              self end
  def dscale(v);            @style.dscale(v);             self end
  def xscale(v);            @style.xscale(v);             self end
  def yscale(v);            @style.yscale(v);             self end
  def rotate(v);            @style.rotate(v);             self end
  def level(*v)             @style.level(*v);             self end
  def dimLevel(*v)          @style.dimLevel(*v);          self end
  def bold;                 @style.bold;                  self end
  def postProcessor(&f);    @postProcessors << f;         self end
  def label(v);             @label = v;                   self end
  def mustPrint(v=true);    @mustPrint = v;               self end
  def mustNotPrint(v=true); @mustNotPrint = v;            self end
  def signature(v);         @signature = v;               self end # Used by writer for lazy printing
  def ignoreSpatialStyles(v=true); @ignoreSpatialStyles = v; self end
  def maximalLevels(*v);    @maximalLevels = v; self end # Levels to print out if maximal flag is set
  def tags(*v); @tags = (@tags || []) + v; self end
  def explode(v=$defaultExplodeFactor); @explode = v; self end

  # Keep showing this object until v levels from now
  def nlevels(v=1);         level(nil, tstartlevelplus(v)); self end

  def getStyle;             @style                        end
  def getLabel;             @label                        end
  def getLevel;             @style.getLevel               end
  def getDimLevel;          @style.getDimLevel            end
  def getScale;             @style.getScale               end
  def getColor;             @style.getColor               end
  def getMustPrint;         @mustPrint                    end
  def getMustNotPrint;      @mustNotPrint                 end
  def getSignature;         @signature || to_s            end
  def getIgnoreSpatialStyles; @ignoreSpatialStyles        end
  def getMaximalLevels; @maximalLevels end
  def getTags; @tags end
  def getExplode; @explode end

  def getPrintedLevel;      @printedPicNode.level         end

  # Set the bounding box based on refObj.
  # Typical use: obj is complicated math with big descenders,
  # and we want to position it as if it were just text.
  # Side effect: prints refObj to writer if it hasn't been printed,
  # but the resulting picture node isn't added.
  def setBounds(refObj, useRefX1, useRefY1, useRefX2, useRefY2)
    postProcessor { |writer,rootObj|
      rootPicNode = rootObj.printedPicNode
      refPicNode = _(refObj).print(writer, rootPicNode.childrenStyle)
      p1 = [rootPicNode.getPoint(-1, -1), 
             refPicNode.getPoint(-1, -1)]
      p2 = [rootPicNode.getPoint(+1, +1), 
             refPicNode.getPoint(+1, +1)]
      x1 = [p1[0].xpart, p1[1].xpart]
      x2 = [p2[0].xpart, p2[1].xpart]
      y1 = [p1[0].ypart, p1[1].ypart]
      y2 = [p2[0].ypart, p2[1].ypart]
      writer.setBounds(rootPicNode.pic,
        x1[useRefX1 ? 1 : 0], y1[useRefY1 ? 1 : 0],
        x2[useRefX2 ? 1 : 0], y2[useRefY2 ? 1 : 0])
    }
  end

  def setXBounds(refObj); setBounds(refObj, true, false, true, false) end
  def setYBounds(refObj); setBounds(refObj, false, true, false, true) end

  # Return the first matching picNode or nil otherwise
  # Go down thed tree of printed picture nodes
  def findPicNode(*labelPath)
    def matches(s, q); q == '*' || q == s end # Allow wildcards
    return nil if labelPath.size == 0
    return nil if @label && (not matches(@label, labelPath[0])) # Label must match if it exists
    #debug "findPicNode", labelPath.join(' '), @label, self.inspect, @printedPicNode.children.size
    return @printedPicNode if labelPath.size == 1 && matches(@label, labelPath[0]) # Match!

    # Try to find the label among children
    @printedPicNode.children.each { |picNode|
      # If there is a label, then strip it away
      tailLabelPath = @label ? labelPath[1..-1] : labelPath
      result = picNode.obj.findPicNode(*tailLabelPath)
      #result = picNode.obj && picNode.obj.findPicNode(*tailLabelPath)
      return result if result
    }
    return nil
  end
  def findObj(*labelPath)
    picNode = findPicNode(*labelPath)
    raise "Unknown label path: #{labelPath.join(' ')}" unless picNode
    picNode.obj
  end

  # Convenient macros to call in postProcessor
  def getPoint(x, y, *labelPath)
    picNode = findPicNode(*labelPath)
    raise "Unknown label path: #{labelPath.join(' ')}" unless picNode
    picNode.getPoint(x, y)
  end
  def postPause; postAddStyle(pause) end
  def postAddStyle(style)
    @printedPicNode.childrenStyle.incorporateExternalStyle!(style)
  end
  def postAddPicNode(writer, picNode)
    @printedPicNode.appendChild(writer, picNode)
    picNode
  end
  def postAdd(writer, obj)
    picNode = _(obj).print(writer, @printedPicNode.childrenStyle)
    @printedPicNode.appendChild(writer, picNode)
    picNode
  end
  def postPreAdd(writer, obj)
    picNode = _(obj).print(writer, @printedPicNode.childrenStyle)
    @printedPicNode.prependChild(writer, picNode)
    picNode
  end

  # By default, the items added in the post processing phase
  # do not use the spatial styles because we expect the items added
  # to refer to absolute positions of the printed items,
  # which themselves have already undergone the transformations.
  # To apply something like scaling to all the items uniformly,
  # we need to wrap the object in an overlay or table and scale that.
  # The transformation will be applied on that level.

  # Add arrows to pairs of identifiers
  def Obj.createArrow; lambda { |p1,p2| arrow(p1, p2).arrowSize(u(0.1)) } end
  def Obj.createEdge; lambda { |p1,p2| edge(p1, p2) } end
  def Obj.createCurvedArrow(d1, d2)
    lambda { |p1,p2|
      path(p1, p2).type(:arrow).arrowSize(u(0.1)).curved.begindir(d1).enddir(d2)
    }
  end

  # Try to deprecate these
  def postAddEdges(writer, *pairs)
    postAddPaths(writer, Obj.createEdge, *pairs)
  end
  def postAddArrows(writer, *pairs)
    postAddPaths(writer, Obj.createArrow, *pairs)
  end
  def postAddCurvedArrows(writer, d1, d2, *pairs)
    postAddPaths(writer, Obj.createCurvedArrow(d1, d2), *pairs)
  end
  def postAddPaths(writer, createPath, *pairs)
    picNodes = []
    pairs.each { |labels1,labels2|
      picNodes << postAddPath(writer, createPath, labels1, labels2)
    }
    picNodes
  end
  def postAddPath(writer, createPath, labels1, labels2)
    def getEnclosure(obj, bbox)
      return bbox unless obj.is_a?(Circle)
      # Find the inscribing circle
      x = bbox.width
      y = bbox.height
      center = bbox.center
      Value.path("(fullcircle xscaled #{x} yscaled #{y} shifted #{center})")
    end
    # Add a path between the center of two objects,
    # but actually start the path at the boundary of the objects.
    labels1 = [labels1] if labels1.class != Array
    labels2 = [labels2] if labels2.class != Array
    picNode1 = findPicNode(*labels1) or raise "Unknown: #{labels1}"
    picNode2 = findPicNode(*labels2) or raise "Unknown: #{labels2}"
    bbox1 = picNode1.pic.bbox
    bbox2 = picNode2.pic.bbox
    obj1 = picNode1.obj
    obj2 = picNode2.obj
    # Get the enclosure paths
    enc1 = getEnclosure(obj1, bbox1)
    enc2 = getEnclosure(obj2, bbox2)
    p1 = bbox1.center
    p2 = bbox2.center
    # Clip the arrows
    path = createPath.call(p1, p2) # Create the path
    p1 = Value.intersectionPoint(path.getPathValue, enc1)
    p2 = Value.intersectionPoint(path.getPathValue, enc2)
    postAdd(writer, createPath.call(p1, p2))
  end

  def to_s; self.class.to_s end

  def print(writer, style); raise 'Override this method' end

  # arg is one of the following
  #  - a string representing the picture
  #    This should be the only situation where PictureNode.new is called
  #  - An object, in which case print will be called.
  def initPicNode(writer, style, arg)
    if arg.is_a?(Obj) then
      arg.explode(getExplode) # Transfer explode
      @printedPicNode = arg.print(writer, style.createChildrenStyle)
    else
      @printedPicNode = PictureNode.new(self,
        style.getLevel, style.getDimLevel, writer.store(arg))
    end
  end
  def finishPicNode(writer, style)
    @printedPicNode.applyStyle(writer, style)
    @printedPicNode.childrenStyle = style.createChildrenStyle
    @postProcessors.each { |postProcessor| postProcessor.call(writer, self) } if @postProcessors
    @printedPicNode
  end
  def initFinishPicNode(writer, style, arg)
    initPicNode(writer, style, arg)
    finishPicNode(writer, style)
  end

  # Assume we've already printed
  def collectStrings(strings)
    # Recurse on children; see Str.collectStrings for action
    @printedPicNode.children.each { |childPicNode| childPicNode.obj.collectStrings(strings) }
  end

  def nil; self end
end
