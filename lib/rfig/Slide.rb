############################################################
# Comments show up at the top of the slide.

class Comment
  attr_reader :values
  def initialize(values); @values = values end
end
def comment(*values); Comment.new(values) end

class SlideStyle
  def getBorder; @border end
  def getBorderColor; @borderColor end
  def getTitleScale; @titleScale end
  def getTitleColor; @titleColor end
  def getTitleSpacing; @titleSpacing end
  def getLineSpacing; @lineSpacing end
  def getShowSlideNum; @showSlideNum end
  def getWidth; @width end
  def getHeight; @height end
  def getTitleHeight; @titleHeight end
  def getLeftMargin; @leftMargin end
  def getBgColor; @bgColor end
  def getBorderColor; @borderColor end
  def getBorder; @border end
  def getSlideNum; @slideNum end
  def getFootnote; @footnote end
  def getFooterScale; @footerScale end
  def getFooterMargin; @footerMargin end
  def getLeftHeader; @leftHeader end
  def getRightHeader; @rightHeader end
  def getHeaderScale; @headerScale end

  def border(v=1); @border = v; self end
  def borderColor(v); @borderColor = v; self end
  def titleScale(v); @titleScale = v; self end
  def titleColor(v); @titleColor = v; self end
  def titleSpacing(v); @titleSpacing = v; self end # Space between title and body of slide
  def lineSpacing(v); @lineSpacing = v; self end
  def showSlideNum(v); @showSlideNum = v; self end
  def width(v); @width = v; self end
  def height(v); @height = v; self end
  def titleHeight(v); @titleHeight = v; self end
  def leftMargin(v); @leftMargin = v; self end
  def bgColor(v); @bgColor = v; self end
  def borderColor(v); @borderColor = v; self end
  def border(v); @border = v; self end
  def slideNum(v); @slideNum = v; self end # Filled in by the presentation
  def footnote(v); @footnote = v; self end # Goes in bottom-left corner
  def footerScale(v); @footerScale = v; self end
  def footerMargin(v); @footerMargin = v; self end
  def leftHeader(v); @leftHeader = v; self end
  def rightHeader(v); @rightHeader = v; self end
  def headerScale(v); @headerScale = v; self end

  def incorporate!(slideStyle)
    @border = slideStyle.getBorder || @border
    @borderColor = slideStyle.getBorderColor || @borderColor
    @border = slideStyle.getBorder || @border
    @borderColor = slideStyle.getBorderColor || @borderColor
    @titleScale = slideStyle.getTitleScale || @titleScale
    @titleColor = slideStyle.getTitleColor || @titleColor
    @titleSpacing = slideStyle.getTitleSpacing || @titleSpacing
    @lineSpacing = slideStyle.getLineSpacing || @lineSpacing
    @showSlideNum = slideStyle.getShowSlideNum || @showSlideNum
    @width = slideStyle.getWidth || @width
    @height = slideStyle.getHeight || @height
    @titleHeight = slideStyle.getTitleHeight || @titleHeight
    @leftMargin = slideStyle.getLeftMargin || @leftMargin
    @bgColor = slideStyle.getBgColor || @bgColor
    @borderColor = slideStyle.getBorderColor || @borderColor
    @border = slideStyle.getBorder || @border
    #@printComments = slideStyle.getPrintComments || @printComments
    @slideNum = slideStyle.getSlideNum || @slideNum
    @footnote = slideStyle.getFootnote || @footnote
    @footerScale = slideStyle.getFooterScale || @footerScale
    @footerMargin = slideStyle.getFooterMargin || @footerMargin
    @leftHeader = slideStyle.getLeftHeader || @leftHeader
    @rightHeader = slideStyle.getRightHeader || @rightHeader
    @headerScale = slideStyle.getHeaderScale || @headerScale
    self
  end

  def nil; self end
end

############################################################

# Printing backed by a table.
class Slide < Obj
  def initialize(title, *children)
    super()
    @title = title ? _(title) : nil
    @comments = []
    @children = []
    #debug "Slide.initialize: #{title}"; $stdout.flush

    @slideStyle = SlideStyle.new

    filterObjArgs(children).each { |child|
      if child.is_a?(Comment)
        @comments = @comments + child.values
      else
        @children << child
      end
    }
  end

  def border(v=1); @slideStyle.border(v); self end
  def borderColor(v); @slideStyle.borderColor(v); self end
  def titleScale(v); @slideStyle.titleScale(v); self end
  def titleColor(v); @slideStyle.titleColor(v); self end
  def titleSpacing(v); @slideStyle.titleSpacing(v); self end
  def lineSpacing(v); @slideStyle.lineSpacing(v); self end
  def showSlideNum(v); @slideStyle.showSlideNum(v); self end
  def width(v); @slideStyle.width(v); self end
  def height(v); @slideStyle.height(v); self end
  def titleHeight(v); @slideStyle.titleHeight(v); self end
  def leftMargin(v); @slideStyle.leftMargin(v); self end
  def bgColor(v); @slideStyle.bgColor(v); self end
  def borderColor(v); @slideStyle.borderColor(v); self end
  def border(v); @slideStyle.border(v); self end
  #def printComments(v); @slideStyle.printComments(v); self end
  def slideNum(v); @slideStyle.slideNum(v); self end
  def footnote(v); @slideStyle.footnote(v); self end
  def footerScale(v); @slideStyle.footerScale(v); self end
  def footerMargin(v); @slideStyle.footerMargin(v); self end
  def leftHeader(v); @slideStyle.leftHeader(v); self end
  def rightHeader(v); @slideStyle.rightHeader(v); self end
  def headerScale(v); @slideStyle.headerScale(v); self end

  def slideStyle(slideStyle); @slideStyle.incorporate!(v); self end
  def getSlideStyle; @slideStyle end
  def getComments; @comments end

  # Returns a picture (identifier)
  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    auxStyle = style.createChildrenStyle # For bounding box and footers

    width = @slideStyle.getWidth || u(11)
    height = @slideStyle.getHeight || u(8.5)

    if @title
      @title.scale(@slideStyle.getTitleScale || 1.3) unless @title.getScale
      @title.color(@slideStyle.getTitleColor || darkblue) unless @title.getColor
    end

    writer.comment("Slide.print: #{@slideNum}")
    table = rtable(@title || '', vspace(@slideStyle.getTitleSpacing || u(0.1)), *@children)
    table.border(@slideStyle.getBorder || 1).borderColor(@slideStyle.getBorderColor || white) # Necessary to make outside border
    table.bgColor(@slideStyle.getBgColor || white)
    table.rmargin(@slideStyle.getLineSpacing || u(0.2)).coffset(@slideStyle.getLeftMargin || u(0.5)).cexpand
    table.totalLength(height, width)
    table.cjustify(:center, 0) # Center title
    if @title
      table.rlength(@slideStyle.getTitleHeight || u(1), 0).rjustify('r', 0) # Title: height, height
    end

    rootPicNode = initPicNode(writer, style, table)

    footerScale = @slideStyle.getFooterScale || 0.5
    headerScale = @slideStyle.getHeaderScale || 0.5
    margin = @slideStyle.getFooterMargin || u(0.5)
    margin2 = margin.div(2)

    # Add footnote
    if @slideStyle.getFootnote then
      p = Value.pair(margin2, height.sub(margin2).negate)
      footnotePicNode = overlay(@slideStyle.getFootnote).
        scale(footerScale).pivot(-1, 0).shift(p).print(writer, auxStyle)
      rootPicNode.appendChild(writer, footnotePicNode)
    end

    # Add headers
    if @slideStyle.getLeftHeader then
      p = Value.pair(margin2, margin2.negate)
      picNode = overlay(@slideStyle.getLeftHeader).
        scale(headerScale).pivot(-1, +1).shift(p).print(writer, auxStyle)
      rootPicNode.appendChild(writer, picNode)
    end
    if @slideStyle.getRightHeader then
      p = Value.pair(width.sub(margin2), margin2.negate)
      picNode = overlay(@slideStyle.getRightHeader).
        scale(headerScale).pivot(+1, +1).shift(p).print(writer, auxStyle)
      rootPicNode.appendChild(writer, picNode)
    end

    # Add slide number
    showSlideNum = @slideStyle.getShowSlideNum == nil ? true : @slideStyle.getShowSlideNum
    if showSlideNum && @slideStyle.getSlideNum then
      p = Value.pair(width.sub(margin2), height.sub(margin2).negate)
      slideNumPicNode = overlay(@slideStyle.getSlideNum).
        scale(footerScale).pivot(0, 0).shift(p).print(writer, auxStyle)
      rootPicNode.appendChild(writer, slideNumPicNode)
    end

    # Add comments
#    if @slideStyle.getPrintComments && @comments.size > 0 then
#      p = Value.pair(margin.div(4), margin.div(4).negate)
#      commentPicNode = overlay(rtable(*@comments).scale(0.4)).
#        pivot(-1, +1).shift(p).print(writer, auxStyle)
#      rootPicNode.appendChild(writer, commentPicNode)
#    end

    writer.comment("Slide.print: end")
    finishPicNode(writer, style)
  end

  def to_s; (@title || '').to_s end
end
def slide(*args); Slide.new(*args) end
