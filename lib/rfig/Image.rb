require 'rfig/image_size'

class Image < Obj
  def initialize(file)
    super()
    @file = file
    if file =~ /\.pdf$/ then
      info = ExternalCommand.exec(:command => 'pdfinfo', :args => [file], :returnOutput => true)
      info.split(/\n/).each { |line|
        scale = 1
        if line =~ /Page size:\s+([\d.]+) x ([\d.]+) pts/ then
          @xsize = $1.to_i * scale
          @ysize = $2.to_i * scale
        end
      }
      raise "Unable to get size" unless @xsize && @ysize
      # Hack: look at the PDF file to see if these dimensions are actually rotated
      rotate = false
      IO.foreach(file) { |line|
        if line =~ /^\/Rotate 90/ then
          rotate = true
          break
        end
      }
      @xsize, @ysize = @ysize, @xsize if rotate
    else
      img = ImageSize.new(open(file))
      scale = 1
      @xsize = img.get_width * scale
      @ysize = img.get_height * scale
    end
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)

    # Draw placeholder; fill in the actual image later
    # Flaw: we don't keep track of styles applied by the parent,
    # so the externalfigure can't apply the same ones
    initPicNode(writer, style, rectllur(Value.origin, Value.pair(@xsize, @ysize)).color(white))
    if !nocolor.equal?(@style.getColor) then
      @printedPicNode.imagePath = File.expand_path(@file)
    end

    #@printedPicNode.imageSize = [@xsize, @ysize]
    #placeholderObj = overlay(
      #rectllur(Value.origin, Value.pair(1, 1)).color(black), # Need it to mark the origin
      #rectllur(Value.origin, Value.pair(@xsize, @ysize)).color(black), # Occupy the space
    #nil)
    #initPicNode(writer, style, placeholderObj)
    #originPicNode = @printedPicNode
    #originPicNode = @printedPicNode.children[0] 
    #originPicNode.imagePath = File.expand_path(@file)
    #originPicNode.imageSize = [@xsize, @ysize]
    #debug originPicNode.style.getScale

    finishPicNode(writer, style)
  end
end

def image(file); Image.new(file) end
