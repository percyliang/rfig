############################################################
# An object manager connects objects with a writer.
# See FigureSet and Presentation for two subclasses.

require 'rfig/PDFMetapostWriter'
require 'rfig/general'
require 'rfig/misc'
require 'rfig/Style'
require 'rfig/Thunk'
require 'rfig/Value'
require 'rfig/Latex'
require 'rfig/Colors'
require 'rfig/PictureNode'
require 'rfig/DormantContents'

# Types of objects
require 'rfig/Obj'
require 'rfig/Str'
require 'rfig/Path'
require 'rfig/Shape'
require 'rfig/Image'
require 'rfig/Table'
require 'rfig/Overlay'
require 'rfig/Tree'
require 'rfig/DataTable'
require 'rfig/Graph'
require 'rfig/DNode'
require 'rfig/ParseTree'
require 'rfig/Slide'

class ObjManager
  attr_accessor :lazy
  attr_accessor :outGroupName # Prepended to the name of every object/slide (makes it easier to put presentations together without name clashes)
  attr_accessor :latexHeader

  def initialize(options)
    options[:cmdlineOptions] = ARGV unless options[:cmdlineOptions] 
    @latexHeader, # A list of Latex commands 
    @defaultFont, # Font to use for displaying text
    @fontSize, # Font size (e.g., 12pt, 30pt)
    @separateFiles, # Whether to write each object to a separate file
    @explode, # Make a separate file for each exploding object
    @lazy, # Record the signature of an object when it is written; if it hasn't changed, don't write it again.
    @pretend, # Don't actually do anything; just list slides
    @outPrefix, # The global prefix to write to (e.g., the directory name to write out all the files)
    @printSet, # The list of object numbers to print out (e.g., 1-3 6 8 10-)
    @printMaximal, # Good for creating versions of slides for printing; only print pages of a slide that contain a strict subset of the objects in another page
    @outputStrings, # Write all the text strings to a file (good for spell checking)
    @verbose, # When creating pages (PDF), print out a lot of information
    @writer, # Which writer to use (determines output format)
    @includeTags, # Include only slides with at least one of these tags
    @excludeTags = # Don't include slides with any of these tags
      extractArgs(:args => options[:cmdlineOptions] || [], :spec => [
        ['latexHeader', [String], options[:latexHeader]],
        ['defaultFont', String, default(options[:defaultFont], "sans-serif")],
        ['fontSize', Float, default(options[:fontSize], 1.0)],
        ['separateFiles', TrueClass, default(options[:separateFiles], true)],
        ['explode', TrueClass, options[:explode]],
        ['lazy', TrueClass, default(options[:lazy], true)],
        ['pretend', TrueClass, options[:pretend]],
        ['outPrefix', String, options[:outPrefix]],
        ['printSet', [String], default(options[:printSet], 'all')],
        ['printMaximal', TrueClass, options[:printMaximal]],
        ['outputStrings', TrueClass, default(options[:outputStrings], true)],
        ['verbose', TrueClass, options[:verbose]],
        ['writer', String, default(options[:writer], "PDFMetapostWriter")],
        ['includeTags', [String], options[:includeTags]],
        ['excludeTags', [String], options[:excludeTags]]])

    @printSet = parseNumberSet(@printSet)
    @writer = eval "#{@writer}.new" if @writer.is_a?(String)
    @writer.outputStrings = @outputStrings

    @numObjs = 0
    @objNum = 0 # Can be artificially maniuplated (1 based)

    if @explode && (not @separateFiles) then
      raise 'When exloding tree, must set separateFiles'
    end

    if @separateFiles then
      # Not reliable because subclass could modify
      #outPrefix = getGlobalOutPrefix
      #puts "Writing to directory: #{outPrefix}"
      #ExternalCommand.exec(:command => 'mkdir', :args => ['-p', outPrefix])
      #@namesOut = open("#{outPrefix}/names", "w")

      @printedNames = {} # To keep track, make sure there's no conflict
      @printedNamesList = []
      @printedNamesChangedList = [] # Only names that were updated
    end
  end

  # Input example: ['2-4', '6', '11']
  # Output: hash set with the numbers in the range
  def parseNumberSet(list)
    return nil if list == nil
    h = {}
    max = 500
    list.each { |t|
      if    t =~ /^(\d+)$/         then h[$1.to_i] = true
      elsif t =~ /^(\d+)?-(\d+)?$/ then
        (($1 || 0).to_i..($2 || max).to_i).each { |x| h[x] = true }
      elsif t == "all" then
        (0...max).each { |x| h[x] = true }
      end
    }
    h
  end

  def finish
    @writer.finish
    #@namesOut.close if @namesOut

    if @explode then
      lines = @printedNamesList.map { |name|
        jpegFile = Dir["#{name}*.jpeg"][0]
        #jpegFile = Dir["#{name}.jpeg*"][0]
        if jpegFile
          name = File.basename(name)
          jpegFile = File.basename(jpegFile)
          "<a href=\"#{name}.html\"><img width=25% src=\"#{jpegFile}\"></a>"
        else
          puts "Warning: #{name}.jpeg* doesn't exist"
          nil
        end
      }.compact
      IO.writelines(getGlobalOutPrefix+"/index.html", lines)
    end
  end

  def effectiveLabel(obj)
    label = obj.getLabel
    label = @outGroupName + "-" + label if @outGroupName
    label
  end

  # Flush print the object at these levels.
  # Return whether we should print.
  def print(options, modifyObj=nil)
    obj = options[:obj] or raise 'Missing object'

    @numObjs += 1; @objNum += 1

    # Use tags to determine if this object is to be printed
    # If no include/exclude tags specified, take no action
    if @includeTags && obj.getTags && obj.getTags.find{|tag| @includeTags.include?(tag)}
      obj.mustPrint(true)
    end
    if @excludeTags && obj.getTags && obj.getTags.find{|tag| @excludeTags.include?(tag)}
      obj.mustNotPrint(true)
    end

    # Should print this object?
    if @printSet # If specified what to print, then follow that
      return if obj.getMustNotPrint || (not @printSet[@objNum])
    else # If nothing specified, only print the must prints
      return if not obj.getMustPrint
    end

    s = obj.to_s # Save object title (because modify is probably going to put a table around)
    obj = modifyObj.call(obj) if modifyObj
    puts "#{@objNum} [#{obj.class}] #{effectiveLabel(obj)}: #{s}"

    # Fetch print-time options (some of which are also initialization options)
    outPrefix = getObjOutPrefix(obj, options[:outPrefix])

    # Get print-time options
    latexHeader = [@latexHeader, options[:latexHeader]].flatten.compact
    latexHeader = latexHeader.size == 0 ? nil : latexHeader.join("\n")
    lazy = options[:lazy] != nil ? options[:lazy] : @lazy
    defaultFont = options[:defaultFont] || @defaultFont
    fontSize = options[:fontSize] || @fontSize

    needToDo = true
    needToDo = false if File.exists?('STOP') # Temporary
    needToDo = false if @pretend # Don't actually do anything

    if @separateFiles then
      #@namesOut.puts outPrefix if @namesOut

      raise "Prefix already exists: '#{outPrefix}'" if @printedNames[outPrefix]
      @printedNames[outPrefix] = true
      @printedNamesList << outPrefix

      # Figure out if we need to update
      if lazy
        signature = obj.getSignature.to_s

        # Read signature on disk
        sigPath = outPrefix+".sig"
        oldSignature = File.exists?(sigPath) ? IO.readlines(sigPath)[0].chomp : nil
        # If something changed, have to recompile
        needToDo = false if signature && signature == oldSignature && signature.to_i != -1
      end

      # If so, then do it
      if needToDo then
        printSeparate = lambda { |obj,explodeOutPrefix,explodeFactor|
          @writer.init(explodeOutPrefix, latexHeader, defaultFont, fontSize, @verbose)
          printObj(obj, options[:levels])
          @writer.finish
          if explodeFactor then
            ExternalCommand.exec(:command => 'convert',
              :args => ['-density', explodeFactor*100, explodeOutPrefix+".pdf", explodeOutPrefix+".jpeg"])
          end
        }

        # Simply print the slide
        printSeparate.call(obj, outPrefix, @explode ? $defaultExplodeFactor : nil)

        # For each exploding node in the tree, make a separate PDF and convert it to JPEG
        if @explode then
          # Collecting exploding objects
          explodingObjs = [] # List of [obj, explodeFactor]
          traverse = lambda { |obj|
            explodingObjs << [obj, obj.getExplode] if obj.getExplode
            obj.printedPicNode.children.each_with_index { |childPicNode,i|
              childObj = childPicNode.obj
              traverse.call(childObj) if childObj
            }
          }
          traverse.call(obj)

          # Print them out
          htmlContents = []
          addHtmlContent = lambda { |prefix,explodeFactor|
            Dir["#{prefix}.jpeg*"].each { |file|
              # Get size, undoing the explosion factor
              img = ImageSize.new(open(file))
              width = (img.get_width.to_f / explodeFactor + 0.5).to_i
              height = (img.get_height.to_f / explodeFactor + 0.5).to_i

              file = File.basename(file)
              htmlContents <<
                "<a href=\"#{file}\"><img width=#{width} height=#{height} src=\"#{file}\"></a><br>"
            }
          }

          addHtmlContent.call(outPrefix, $defaultExplodeFactor)
          htmlContents << '<br><hr><br>'
          explodingObjs.each_with_index { |explodeObjFactor,i|
            explodeObj, explodeFactor = explodeObjFactor
            puts "  Exploding #{i}/#{explodingObjs.size} by #{explodeFactor}: #{explodeObj}"
            explodeOutPrefix = "#{outPrefix}-#{i}"
            printSeparate.call(explodeObj, explodeOutPrefix, explodeFactor)
            addHtmlContent.call(explodeOutPrefix, explodeFactor)
          }
          IO.writelines(outPrefix+'.html', htmlContents)
        end

        IO.writelines(sigPath, [signature]) if lazy # Write new signature
        @printedNamesChangedList << outPrefix
      end
    else
      if needToDo then
        # Add to the monolithic output (shouldn't be used that often)
        @writer.init(outPrefix, latexHeader, defaultFont, fontSize, @verbose) if not @writer.opened?
        printObj(obj, options[:levels])
      end
    end
  end
      
  # Print the object (private function)
  def printObj(obj, levels)
    #$stdout.print "#{obj.class} #{@objNum} [#{obj}]"

    # Print the object!
    style = Style.new
    picNode = obj.print(@writer, style)

    # Maximal levels may depend on some variables
    maximalLevels = style.evaluateThunk(obj.getMaximalLevels)
    
    oldDrawnNodes = nil
    oldCommands = nil
    levels = [] unless levels
    levels = [levels, levels+1] if levels.is_a?(Fixnum)
    level = levels[0] || 0 # Go through the levels

    # Flush print the object
    while levels[1] == nil || level < levels[1] do
      drawnNodes, commands = @writer.drawPictureNode(picNode, level)
      #puts "S #{drawnNodes.size}"
      #puts commands.inspect if drawnNodes.size == 1
      # If we have already drawn something or we are drawing something, then pay attention
      # (skip empty initial levels which typically occur when exploding objs)
      if oldDrawnNodes != nil || drawnNodes.size > 0
        # If nothing has changed or everything disappeared, then stop
        if oldDrawnNodes == drawnNodes || drawnNodes.size == 0 then
          #oldDrawnNodes = drawnNodes
          #oldCommands = commands
          # Sometimes, want to print out last level
          @writer.printCommands(commands) if @printMaximal && maximalLevels && maximalLevels.member?(-1)
          break
        end
        if @printMaximal then
          if maximalLevels then
            @writer.printCommands(commands) if maximalLevels.member?(level)
          # Print only if something changed, which means old was maximal
          elsif oldDrawnNodes != nil && (not oldDrawnNodes.isSubsetOf(drawnNodes)) then
            @writer.printCommands(oldCommands)
          end
        else
          @writer.printCommands(commands)
        end
        oldDrawnNodes = drawnNodes
        oldCommands = commands
      end
      level += 1
      #puts level
    end
    raise 'No nodes to draw' if not oldDrawnNodes

    # Last one always maximal
    if @printMaximal && (not obj.getMaximalLevels) && oldCommands
      @writer.printCommands(oldCommands)
      #$stdout.print " #{level}"; $stdout.flush
    end

    obj.collectStrings(@writer.strings) if @outputStrings
  end

  def getGlobalOutPrefix; @outPrefix || $0.sub(/\.rb$/, "") end
  def getObjOutPrefix(obj, outPrefix)
    globalOutPrefix = getGlobalOutPrefix
    localOutPrefix = outPrefix || effectiveLabel(obj) || @objNum.to_s
    @separateFiles ?
      (globalOutPrefix+"/"+localOutPrefix).sub(/^\.\//, "") :
      globalOutPrefix
  end

  def getPrintMaximal; @printMaximal end
end
