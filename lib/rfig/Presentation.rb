############################################################
# A presentation is a list of slides.

require 'rfig/ObjManager'
require 'rfig/Outline'
require 'rfig/RefDB'

class Presentation < ObjManager
  def initialize(options)
    super(options)
    @printComments, # Whether to print out comments (notes) for each slide
    @recentOutPath, # Copy last output file to this file (set by edition)
    @aggregateOutPath, # Aggregated all output files and write to this file (set by edition)
    @debug, # Whether to operate in debug mode (used if edition is specified)
    @multipage, # Whether to put many slides onto one page
    @edition = # Specifies a list of standard additional options and commands
      extractArgs(:args => options[:cmdlineOptions] || [], :spec => [
        ['printComments', TrueClass, options[:printComments]],
        ['recentOutPath', String, options[:recentOutPath]],
        ['aggregateOutPath', String, options[:aggregateOutPath]],
        ['debug', TrueClass, options[:debug]],
        ['multipage', TrueClass, options[:multipage]],
        ['edition', String, options[:edition]]])

    # General slide style
    @slideStyle = SlideStyle.new

    # Set options based on edition
    if @edition then
      # Unfortunately, PDF is kind of hard coded.
      @outPrefix = "#{@edition}.slides" unless @outPrefix
      if @debug then
        @recentOutPath = "debug.pdf"
      else
        @aggregateOutPath = "#{@edition}.pdf"
      end
      if @edition == 'present' then # Final presentation version
        @excludeTags = (@excludeTags || []) + ['reference']
        @printComments = false
        @printMaximal = false
        @multipage = false
      elsif @edition == 'practice' then # Presentation version with comments
        @printComments = true
        @printMaximal = false
        @multipage = false
      elsif @edition == 'poster' then # Paper version (no comments and only maximal slides)
        @printComments = false
        @printMaximal = true
        @multipage = false
      elsif @edition == 'paper' then # Paper version (with comments and only maximal slides)
        @printComments = true
        @printMaximal = true
        @multipage = true
      elsif @edition == 'explode' then # Exploded version
        @explode = true
        @printComments = false
        @printMaximal = true
        @multipage = false
      else
        raise "Unknown edition: #{@edition}"
      end
    end
  end

  # Flush print the slide at these levels.
  def print(options)
    super(options, lambda { |slide|
      # Assume these are slides
      # Get effective slide style (intrinsic slide style overwrites the current slide style)
      slideStyle = SlideStyle.new.incorporate!(@slideStyle).incorporate!(slide.getSlideStyle)
      slide.getSlideStyle.incorporate!(slideStyle)
      slide.slideNum(@objNum)

      if @printComments then
        # Print the comments underneath the slide
        commentBox = 
          ctable(
            autowrap(*slide.getComments).scale(0.5).width(u(10)).flushfull.
              level(0),
              #level(0, @printMaximal ? nil : 1), # If print maximal, print on every page
          nil).outerMargin(u(0.1), u(0.1)).border(1).
            clength(u(10)).rlength(u(1.5)).
            borderColor(gray).level(0)

        newSlide = rtable(slide.scale(0.8).borderColor(black).border(2), commentBox).center
        # Transfer important information from the slides
        newSlide.signature(slide.getSignature)
        newSlide.label(slide.getLabel)
        newSlide.maximalLevels(*slide.getMaximalLevels) if slide.getMaximalLevels
        newSlide.mustPrint(slide.getMustPrint)
        newSlide.mustNotPrint(slide.getMustNotPrint)
        slide = newSlide
      end
      slide
    })
  end

  def finish
    super()
    if @aggregateOutPath then
      # Create a single PDF
      if @printedNamesList && @printedNamesList.size > 0 then
        #ExternalCommand.exec(
          #:command => 'pdftk',
          #:args => @printedNamesList.map{|f| f+'.pdf'} + ['cat', 'output', @aggregateOutPath])
        ExternalCommand.exec(
          :command => 'pdfjoin',
          :args => @printedNamesList.map{|f| f+'.pdf'} + ['--outfile', @aggregateOutPath])
        if @multipage then
          # Put two pages on one
          ExternalCommand.exec(
            :command => 'pdfnup',
            :args => ['--delta', '1cm 1cm', '--scale', 0.9,
                      '--nup', '1x2', @aggregateOutPath])
        end
      end
    end
    # Copy recently changed slide to the recent path (e.g., debug.pdf)
    if @recentOutPath then
      if @printedNamesChangedList && @printedNamesChangedList.size > 0 then
        ExternalCommand.exec(
          :command => 'cp',
          :args => [@printedNamesChangedList[-1]+'.pdf', @recentOutPath])
      end
    end
  end

  def slideStyle(slideStyle); @slideStyle.incorporate!(slideStyle) if slideStyle end
end

############################################################
# Global variables: $presentation
def initPresentation(options={});  $presentation = Presentation.new(options) unless $presentation end
def finishPresentation;            $presentation.finish if $presentation end
def printSlide(slide, levels=nil); initPresentation; $presentation.print(:obj => slide, :levels => levels) end
def slide!(*args, &post);          initPresentation; printSlide((post || lambda{|x|x}).call(slide(*args))) end
