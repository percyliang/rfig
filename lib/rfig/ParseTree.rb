# For drawing parse trees.

# Regular mode: A tree is either an object (singleton node) or an array [object, child1, ..., childn].
# Labeled edge mode: Array is [object, edgeInfo1, child1, ..., edgeInfon, childn]
# Edge info is a singleton or an array consisting of
#  - Lambda function: these are interpreted as functions to be applied to an edge
#  - String/object: these are labels on the edge
class ParseTree < Obj
  def rmargin(v); @rmargin = v; self end
  def cmargin(v); @cmargin = v; self end
  def useRawBounds(v=true); @useRawBounds = v; self end
  def verticalCenterEdges(v=true); @verticalCenterEdges = v; self end
  def nodePadding(v); @nodePadding = v; self end
  def postNodeFunc(&f); @postNodeFunc = f; self end # Called with node
  def postNode2Func(&f); @postNode2Func = f; self end # Called with (original) node, new node
  def postEdgeFunc(&f); @postEdgeFunc = f; self end # Called with edge, parent node, child node, child index
  def edgeLabelFunc(&f); @edgeLabelFunc = f; self end # Called with edge, parent node, child node, child index
  def labeledEdgeMode; @labeledEdgeMode = true; self end
  def moveEdgeLabelsOnArrows(v=true); @moveEdgeLabelsOnArrows = true; self end
  def nodeBorder(v=1); @nodeBorder = v; self end
  def nodeBorderRounded(v); @nodeBorderRounded = v; self end
  def getNew(origNode); @toNew[origNode] or raise "Not found: #{origNode}, only have #{@toNew.keys.join(' ')}" end

  # nodeChildren = [label, [child1Label, ...], child2Label, ...] (for example)
  def initialize(nodeChildren)
    super()
    @nodeChildren = nodeChildren
    @verticalCenterEdges = true
    @nodePadding = u(0.05)
    @useRawBounds = true
    @rmargin = u(0.5)
    @cmargin = u(0.5)
    @toOrig = {} # Map node (labels) to their the original value (what we were passed)
    @toNew = {} # Map the other way
    @edgeLabels = {} # [parent, child] -> edge label (if it exists) [parent and child are original values]
    @edgeFuncs = {} # [parent, child] -> edge func (if it exists)
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)

    # Put the edge information info into the global tables and just return a nodeChildren without the edge information
    processEdgeLabels = lambda { |nodeInfoChildren|
      nodeInfoChildren = [nodeInfoChildren] unless nodeInfoChildren.is_a?(Array)
      node, *infoChildren = nodeInfoChildren
      infoChildren = infoChildren.compact # remove nil's
      raise "In info edge mode: must have even number, but got #{infoChildren.size}" if infoChildren.size % 2 != 0
      children = []
      while infoChildren.size > 0
        info = infoChildren.shift
        child = processEdgeLabels.call(infoChildren.shift)
        children << child

        info = [info] unless info.is_a?(Array)
        info.each { |x|
          edgeKey = [node,child[0]]
          if x.is_a?(Proc) then
            @edgeFuncs[edgeKey] = x
          else
            @edgeLabels[edgeKey] = x
          end
        }
        #puts "SET #{node.inspect} #{child.inspect} #{label}"
      end
      [node]+children
    }

    standarize = lambda { |nodeChildren|
      nodeChildren = [nodeChildren] unless nodeChildren.is_a?(Array)
      node, *children = nodeChildren
      children = children.compact # remove nil's
      origNode = node
      node = _(node)
      node.useRawBounds if node.is_a?(Str) && @useRawBounds
      if node.is_a?(Str) && node.value == ''
        node = circle(u(0.01)).fill # No label, put something there
      else
        node = ctable(node).outerMargin(@nodePadding, @nodePadding)
        node.border(@nodeBorder) if @nodeBorder
        node.borderRounded(@nodeBorderRounded) if @nodeBorderRounded
      end
      @toOrig[node] = origNode
      @toNew[origNode] = node
      [node]+children.map{|child| standarize.call(child)}
    }

    # Return a Table object
    recurse = lambda { |nodeChildren|
      node, *children = nodeChildren
      #puts "recurse: #{nodeChildren.inspect}"
      #puts children.inspect
      @postNodeFunc.call(@toOrig[node]) if @postNodeFunc # Note: doesn't take return value
      node = @postNode2Func.call(@toOrig[node], node) if @postNode2Func # Does use return value

      if children.size > 0 # If there are children, draw them
        ctable(*children.map { |childNodeChildren| recurse.call(childNodeChildren) }).cmargin(@cmargin).postProcessor { |writer,rootObj|
          # Draw the node to center it with the first and last children
          first = children[0][0]
          last = children[-1][0]
          pt = Value.midpoint(first.printedPicNode.pic.getPoint(0, +1), last.printedPicNode.pic.getPoint(0, +1)).add(Value.pair(0, @rmargin))
          origNode = node
          node = overlay(node).center.shift(pt)
          rootObj.postAdd(writer, node)

          # Draw the edges from that node to each child
          children.each_with_index { |childNodeChildren,i|
            child = childNodeChildren[0]
            if @verticalCenterEdges
              e = path(tdown(node), tup(child))
            else
              e = clippedpath(node, child)
            end

            edgeKey = [@toOrig[origNode], @toOrig[child]]

            # Edge functions
            e = @edgeFuncs[edgeKey].call(e) if @edgeFuncs[edgeKey]
            e = @postEdgeFunc.call(e, @toOrig[origNode], @toOrig[child], i) if @postEdgeFunc

            # Figure out where to put the label
            frac = 0.5
            if @moveEdgeLabelsOnArrows && e.is_a?(Path) && e.getType == :arrow # If arrow, then shift the label away from the head a bit
              #e.getArrowSize
              frac = 0.4
              frac = 1-frac if e.getReverse
            end
            if @verticalCenterEdges
              mid = tmediation(frac, tdown(node), tup(child))
            else
              mid = tmediation(frac, tcenter(node), tcenter(child))
            end

            # Put labels
            label = @edgeLabels[edgeKey]
            rootObj.postPreAdd(writer, overlay(label).center.shift(mid)) if label
            label = @edgeLabelFunc.call(e, @toOrig[origNode], @toOrig[child], i) if @edgeLabelFunc
            rootObj.postPreAdd(writer, overlay(label).center.shift(mid)) if label

            rootObj.postPreAdd(writer, e)
          }
        }
      else
        node
      end
    }

    nodeChildren = @labeledEdgeMode ? processEdgeLabels.call(@nodeChildren) : @nodeChildren
    nodeChildren = standarize.call(nodeChildren)
    initFinishPicNode(writer, style, recurse.call(nodeChildren))
  end
end
def parseTree(args); ParseTree.new(args) end

# "(NP (DT the) (NN cat))" => a nested list that denotes the tree that can be passed to parseTree
# call postFunc
def str2trees(str, &postFunc)
  postFunc = lambda { |path,x| x } unless postFunc
  str.gsub!(/\(/, " ( ")
  str.gsub!(/\)/, " ) ")
  tokens = str.split
  i = 0
  advance = lambda { |path|
    if tokens[i] == '('
      i += 1
      list = []
      while tokens[i] != ')'
        tokens[i] != nil or raise "Missing ')'"
        list << advance.call(list.size == 0 ? path : path+[list.size-1])
      end
      i += 1
      list
    else
      x = postFunc.call(path, tokens[i])
      i += 1
      x
    end
  }
  trees = []
  while i < tokens.size
    trees << advance.call([])
  end
  trees
end
def str2tree(str, &postFunc); str2trees(str, &postFunc)[0] end
