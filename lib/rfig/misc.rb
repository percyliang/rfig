# Miscellaneous functions

def aboutStyle?(x); x.is_a?(Style) || x.is_a?(DeltaStyle) end
def modifier?(x); not x.is_a?(Obj) end

def roundExcess(x); round(x, 4) end

# Need this to avoid scientific notation for small values (1e-3) (emnlp-talk) {03/08/09}
def u(x=""); Value.numeric("#{roundExcess(x)}u") end # One measurement 
def upair(x, y); Value.pair("#{roundExcess(x)}u", "#{roundExcess(y)}u") end

def ind(*l); ctable(hspace(u(0.2)), *l) end # Indent
def indn(n, *l); ctable(hspace(u(0.2*n)), *l) end # Indent

def defineColor(map)
  map.each { |name,color|
    eval "$#{name}Color = #{color}"
    eval "def #{name}Color(x); _(x).color(#{color}) end"
    $presentation.latexHeader << "\\newcommand\\#{name}Color[1]{\\#{color}{#1}}"
  }
end

# Convert into an object
def _(value)
  case value
    when String      then Str.new(value)
    when Fixnum      then Str.new(value.to_s)
    when Float       then Str.new(value.to_s)
    when LatexValue  then Str.new(value.to_s)
    when Proc        then _(value.call)
    when nil         then raise "nil not allowed"
    else                  value
  end
end

# Used in table, overlay, etc.
# Removes nil.
def filterObjArgs(args); args.compact.map { |x| _(x) } end
def filterStrArgs(args); args.compact.map { |x| x.to_s } end

def ignore(*args); nil end # Deprecated
def define(*args); nil end

############################################################

# Display bigObj at a relative location offset to smallObj,
# which is found using the label path from obj
# Called by a post processor usually
# baseLevels = [start, stop]
# Return the big picture node
def zoom(options)
  writer = options[:writer] or raise 'Missing writer'
  rootObj = options[:rootObj] or raise 'Missing root object'
  smallPicNode = options[:smallPicNode] or raise 'Missing the small picture node'
  bigObj = options[:bigObj] or raise 'Missing the big object'
  smallMargin = options[:smallMargin] || u(0)
  bigMargin = options[:bigMargin] || u(0)
  offset = options[:offset] || upair(0, 0)
  color = options[:color] || gray
  postFrameFunc = options[:postFrameFunc] # Apply to the box and edge connectors
  boundsIncludeZoom = options[:boundsIncludeZoom] # Whether to set the bounding box to include zoomed contents

  rootPicNode = rootObj.printedPicNode
  rootPic = rootPicNode.pic
  auxStyle = rootPicNode.childrenStyle.createDuplicateStyle

  # Save the bounding box (assuming this is the one we want)
  bbox = writer.store(rootPic.bbox)

  bigPt = smallPicNode.center.add(offset) # Location for big picture node
  bigPicNode = rootObj.postAdd(writer, overlay(bigObj).center.shift(bigPt)) # Draw big node there

  # Draw small and large boxes
  margin = [smallMargin, bigMargin, bigMargin]
  smallBox, bigBox, bigFillBox =
    [smallPicNode, bigPicNode, bigPicNode].map_with_index { |picNode,i|
    box = rect(picNode.pic.width.add(margin[i]),
               picNode.pic.height.add(margin[i])).color(color)
    box.fill.color(white) if i == 2
    box = overlay(box).center.shift(picNode.center)
    box = postFrameFunc.call(box) if postFrameFunc
    box = box.print(writer, auxStyle)
    rootPicNode.appendChild(writer, box)
    box
  }

  # Connect edges between the boxes
  [[-1, -1], [-1, +1], [+1, -1], [+1, +1]].each { |d|
    e = edge(smallBox.getPoint(*d), bigBox.getPoint(*d)).color(color)
    e = postFrameFunc.call(e) if postFrameFunc
    rootPicNode.appendChild(writer, e.print(writer, auxStyle)) # Draw edge
  }

  # Draw last because opaque
  rootObj.postAddPicNode(writer, bigFillBox)
  rootObj.postAddPicNode(writer, bigBox)
  rootObj.postAddPicNode(writer, bigPicNode)

  # Now, set the bounding box to ignore the zoomed stuff
  writer.setBounds(rootPic, bbox) if not boundsIncludeZoom

  bigPicNode
end

def longLine(head, *tail)
  if head then
    table(*filterObjArgs(tail).map_with_index { |x,i|
      [i == 0 ? head : '', x]
    }).margin(u(0.1), u(0.2))
  else
    rtable(*tail).rmargin(u(0.1))
  end
end

############################################################

# DEPRECATED: use ParseTree
def rootedTree(options)
  tree = options[:tree]
  rmargin = options[:rmargin] || u(0.3)
  cmargin = options[:cmargin] || u(0.3)
  circularNodes = options[:circularNodes] # Are the nodes circular?
  verticalCenterEdges = options[:verticalCenterEdges] # Edges meet (at the bottom) (for parse trees)
  nodePadding = options[:nodePadding] # Amount of space outside a node
  postEdgeFunc = options[:postEdgeFunc] # Modify the edge between nodes somehow
  postChildrenTableFunc = options[:postChildrenTableFunc] # Modify the table containing the children
  # Return the array structure representing the tree,
  # but make elements objects
  # Make the edge function explicit
  makeObj = lambda { |tree|
    tree = [tree] unless tree.is_a?(Array)
    #myEdgeFunc = tree.first.is_a?(Proc) ? tree.shift : nil
    root, *children = tree
    root = _(root)
    root = ctable(root).ospace(nodePadding) if nodePadding
    children = children.map { |child| makeObj.call(child) }
    #[myEdgeFunc, root, *children]
    [root, *children]
  }

  convert = lambda { |tree,path|
    #puts tree.inspect if path.size == 0
    #myEdgeFunc, root, *children = tree
    root, *children = tree
    raise "Object expected: #{root.class}" unless root.is_a?(Object)
    children.each { |child| raise "Tree expected: #{child.class}" unless child.is_a?(Array) }

    if children.size == 0 then
      root
    else
      edges = children.map_with_index { |child,i|
        if verticalCenterEdges
          edge = path(tdown(root), tup(child[0]))
        else
          edge = clippedpath(root, child[0])
        end
        edge.beginIsCircle(circularNodes).endIsCircle(circularNodes)
        edge = postEdgeFunc.call(edge, path+[i]) if postEdgeFunc
        #edge = myEdgeFunc.call(edge) if myEdgeFunc
        edge
      }
      children = children.map_with_index { |child,i| convert.call(child, path+[i]) }
      childrenTable = ctable(*children).cmargin(cmargin).justify('l', 'c')
      childrenTable = postChildrenTableFunc.call(path, childrenTable) if postChildrenTableFunc
      overlay(
        rtable(root, childrenTable).rmargin(rmargin).center,
        *edges)
    end
  }
  convert.call(makeObj.call(tree), [])
end

# graphs is array of [caption, graph] pairs.
# Creates a giant table of the graphs.
def arrangeGraphs(opts)
  graphs = opts[:graphs] or "Missing graphs"
  numPerRow = opts[:numPerRow] || 3
  rjustify = opts[:rjustify] || 'c'
  rmargin = opts[:rmargin] || u(0.3)
  cmargin = opts[:cmargin] || u(0.3)
  caprmargin = opts[:caprmargin] || u(0.1)

  captionRow, objRow = [], []
  rows = []
  n = 0
  numPerRow = [numPerRow]*100 unless numPerRow.is_a?(Array)
  100.times { numPerRow << numPerRow[-1] } # HACK
  partialSums = [numPerRow[0]]
  (1...numPerRow.size).each { |i| partialSums[i] = partialSums[i-1] + numPerRow[i] }
  graphs = graphs.compact
  graphs.each_with_index { |captionObj,i|
    caption, obj = captionObj
    if caption
      captionRow << _("(#{(?a+n).chr}) #{caption}").scale(opts[:capscale] || 0.8)
      n += 1
    else
      captionRow << ''
    end
    objRow << obj
    if i+1 == partialSums[rows.size] || i == graphs.size-1 then
      rows << table(objRow, captionRow).rjustify(rjustify).cjustify('c').cmargin(cmargin).rmargin(caprmargin)
      captionRow, objRow = [], []
    end
  }
  rtable(*rows).center.rmargin(rmargin)
end
