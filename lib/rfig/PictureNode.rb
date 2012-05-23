############################################################

# We build up a tree of pictures.
# The leaves are the actual picture items.
# Each node stores the picture which consists of all the nodes below it.
# Most of the methods are for recursively applying a style to all the
# pictures in the tree.
class PictureNode
  attr_reader :obj, :pic, :level, :dimLevel, :children
  #attr_accessor :rotated, :slanted
  attr_accessor :colored # To make sure everything is colored at most once
  attr_accessor :childrenStyle # A style for post-processing (set in finishPicNode)
  attr_accessor :imagePath, :imageSize # Path to the image file and [xsize, ysize] of image
  attr_accessor :style # Style that's applied to this picNode (mostly for externalfigure)

  def initialize(obj, level, dimLevel, pic)
    @obj = obj
    @level = level
    @dimLevel = dimLevel
    @pic = pic # The picture ID of the picture that contains this subtree
    @children = []
  end

  # Note that order of addToPicture calls is irrelevant;
  # only the lowest pictures are printed out anyway,
  # so only the order of the children matters.
  # Behavior is like DOM: if node already exists, remove it and add it.
  def appendChild(writer, node)
    writer.addToPicture(@pic, node.pic) unless removeNodeIfExists(node)
    @children << node
  end
  def prependChild(writer, node)
    writer.addToPicture(@pic, node.pic) unless removeNodeIfExists(node)
    @children = [node] + @children
  end

  # Return if removed anything
  def removeNodeIfExists(node)
    oldSize = children.size
    @children.delete_if { |child| child == node }
    newSize = children.size
    oldSize < newSize
  end

  # Generate the nodes in DFS order
  def recurseEach
    yield self
    @children.each { |child| child.recurseEach { |node| yield node } }
  end
  def recurseEachLeaf
    recurseEach { |node| yield node if node.isLeaf }
  end
  def isLeaf; children.size == 0 end

  def applyStyle(writer, style)
    @style = style
    recurseEach { |node|
      newPic = style.applyStyleToPicNode(node)
      writer.set(node.pic, newPic) if newPic != node.pic
    }
    self
  end

  def setULCorner(writer, pt)
    #writer.comment("PictureNode.setULCorner: #{@pic} to #{pt}")
    dz = writer.store(pt.sub(@pic.getPoint(-1, +1)))
    recurseEach { |node|
      writer.set(node.pic, node.pic.shift(dz))
    }
  end
  def shift(writer, pt)
    applyStyle(writer, Style.new.shift(pt))
  end

  def getPoint(xi, yi); @pic.getPoint(xi, yi) end
  def height; @pic.height end
  def width; @pic.width end
  def center; getPoint(0, 0) end
end
