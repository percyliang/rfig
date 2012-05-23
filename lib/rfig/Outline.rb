class Outline
  def highlightColor(v); @highlightColor = v; self end
  def unhighlightColor(v); @unhighlightColor = v; self end
  def labelPrefix(v); @labelPrefix = v; self end
  def title(v); @title = v; self end
  def signature(v); @signature = v; self end
  def rmargin(v); @rmargin = v; self end

  def initialize(tree); init(tree) end
  def init(tree)
    @tree = tree
    @title = "Outline"
    @index = -1
    @highlightColor = blue
    @unhighlightedColor = gray
    @labelPrefix = "outline"
  end

  def getPath(index=@index)
    i = -1
    path = []
    traverse = lambda { |nodeChildren|
      node, *children = Tree.getNodeChildren(nodeChildren).compact
      path << node
      i += 1
      if i != index then
        children.each { |child|
          break if traverse.call(child)
        }
      end
      path.pop if i != index # No match, keep on going
      i == index
    }
    traverse.call(@tree)
    path
  end
  def getPathStr; getPath.map {|x| x.size == 0 ? nil : x}.compact.join(' / ') end

  def incrIndex
    @index += 1
  end

  def getObj(options)
    highlightColor = options[:highlightColor] || @highlightColor
    unhighlightColor = options[:unhighlightColor] || @unhighlightColor
    omitRootNode = options[:omitRootNode]

    incrIndex
    i = -1
    traverse = lambda { |nodeChildren, depth, highlight|
      node, *children = filterObjArgs(Tree.getNodeChildren(nodeChildren))
      node = '' if omitRootNode && depth == 0 # Don't display the root
      node = node.call if node.is_a?(Proc)

      i += 1 
      highlight = true if i == @index
      #puts [i, @index, highlight, node].inspect
      if node then
        if highlight then node.color(highlightColor)
        else              node.color(unhighlightColor) if unhighlightColor
        end
      end
      [node] + children.map { |child| traverse.call(child, depth + 1, highlight) }
    }
    #puts traverse.call(@tree, false).inspect
    t = tree(*traverse.call(@tree, 0, false))
    t.rmargin(@rmargin) if @rmargin
    t
  end
  def getSlide(options={})
    title = options[:title] || @title
    scale = options[:scale] || 1
    labelPrefix = options[:labelPrefix] || @labelPrefix
    slide(title, getObj(options).scale(scale)).signature(@signature).label("#{labelPrefix}#{@index}")
  end

  def footerFunc; lambda { getPathStr } end
end
