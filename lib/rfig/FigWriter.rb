############################################################
# An interface that is responsible for generating output (metapost, pdf, etc.)
# from an object.

class FigWriter
  attr_accessor :outputStrings, :strings

  def init(outPrefix, verbose)
    raise "Already opened: '#{@outPrefix}'" if @outPrefix 
    @outPrefix = outPrefix
    @verbose = verbose
    @strings = [] # Keep track of strings so we can run a spell checker later
  end

  # Should return the output file that is written to
  def finish
    IO.writelines(@outPrefix+".strings", @strings) if @outputStrings
    @outPrefix = nil
    nil
  end

  def opened?; @outPrefix != nil end
end
