############################################################

# Possible List styles: bullet, dash, number, letter
# Specified by a function, which takes (depth, index) and returns an object.
# Printing is backed by a table.
$itemizeListStyle = lambda { |depth,index|
  ['$\bullet$', '--'][depth % 2]
}
$enumerateListStyle = lambda { |depth,index|
  ["#{index+1}.", (?a+index).chr+"."][depth % 2]
}
$enumerateLetterListStyle = lambda { |depth,index|
  "("+(?a+index).chr+")"
}

class Tree < Obj
  def rmargin(*v); @rmargin = v; self end # List
  def indent(*v); @indent = v; self end # List
  def listStyleFunc(v); @listStyleFunc = v; self end

  def getIndent; @indent end
  def getRmargin; @rmargin end
  def getListStyleFunc; @listStyleFunc end

  def initialize(nodeChildren, depth, parent=nil)
    super()
    @nodeChildren = nodeChildren
    @depth = depth
    @rmargin = parent && parent.getRmargin && parent.getRmargin[1..-1]
    @indent = parent && parent.getIndent && parent.getIndent[1..-1]
    @listStyleFunc = parent && parent.getListStyleFunc
  end

  # Generic functions that operate on trees which are represented by
  # tree = [rootNode, [subtree1, subtree2]]
  def Tree.getNodeChildren(nodeChildren)
    nodeChildren.is_a?(Array) ? nodeChildren : [nodeChildren]
  end
  def Tree.getLeaves(nodeChildren, leaves=[])
    node, *children = Tree.getNodeChildren(nodeChildren)
    leaves << node if children.size == 0
    children.each { |child| Tree.getLeaves(child, leaves) }
    leaves
  end
  
  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    
    node, *children = filterObjArgs(Tree.getNodeChildren(@nodeChildren))
    node = nil if node.is_a?(Str) && node.value == "" # Empty str takes no space

    indent = (@indent && @indent[0]) || u(0.1)
    rmargin = (@rmargin && @rmargin[0]) || u(0.2)

    ct = nil
    if children.size > 0
      index = 0 # Want to skip styles
      ct = ctable(
        node == nil ? nil : hspace(indent), # If no node, don't indent
        table(*children.map { |child|
          if aboutStyle?(child) then
            child
          else
            bullet = _((@listStyleFunc || $itemizeListStyle).call(@depth, index))
            if child.is_a?(Obj) then
              childObj = child
            elsif child.is_a?(Array) && child[0].is_a?(Obj) then
              childObj = child[0]
            end
            if childObj then
              bullet.level(*childObj.getLevel)
              bullet.dimLevel(*childObj.getDimLevel)
            end
            index += 1
            [bullet, Tree.new(child, @depth+1, self)]
          end
        }).rmargin(rmargin),
      nil)
    end

    t = rtable(
      node, # Could be null
      ct,
    nil).rmargin(rmargin)

    initFinishPicNode(writer, style, t)
  end
end
def tree(*args); Tree.new(args, 0) end
def itemizeList(*args); tree('', *args).listStyleFunc($itemizeListStyle) end
def enumerateList(*args); tree('', *args).listStyleFunc($enumerateListStyle) end

# Create a list; at level 0, everything is undimmed
#def dimPauseList(*args)
#  startLevel = 1
#  i = startLevel
#  dimPauseListHelper = lambda { |args|
#    filterObjArgs(args).map { |x|
#      if x.is_a?(Array) then
#        dimPauseListHelper.call(x)
#      else
#        i += 1
#        _(x).dimLevel(startLevel, i-1, i)
#      end
#    }
#  }
#  itemizeList(*dimPauseListHelper.call(args))
#end
