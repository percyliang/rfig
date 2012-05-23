############################################################
# A light wrapper around ObjManager that makes it easy to
# generate figures.

require 'rfig/ObjManager'

class FigureSet < ObjManager
  def initialize(options)
    super(options)

    # Set defaults for figures
    # $filePrefix: communicated through otl2tex
    #@outPrefix = $filePrefix if not @outPrefix
    # If we want to write to write many separate files,
    # then write it to the current directory by default
    #@outPrefix = "."         if (not @outPrefix) && @separateFiles
  end

  # Return output for including in latex document directly
  def print(options)
    return "" unless super(options)

    # Return a caption: communicate through otl2tex
    outPrefix = getObjOutPrefix(options[:obj], options[:outPrefix])
    caption = options[:caption]
    caption ?
      "\\begin{center} \\includegraphics{#{outPrefix}} \\begin{equation} \\text{Figure #{@objNum}: #{caption}} \\label{fig:#{File.basename(outPrefix)}} \\end{equation} \\end{center}" :
      "\\begin{center} \\includegraphics{#{outPrefix}} \\end{center}"
  end
end

############################################################
# Global variables: $figureSet

def initFigureSet(options={}); $figureSet = FigureSet.new(options) unless $figureSet end
def finishFigureSet;           if $figureSet; $figureSet.finish; $figureSet = nil; end end
def printObj(options);         initFigureSet; $figureSet.print(options) end
