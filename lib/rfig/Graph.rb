############################################################
=begin
Two types of graphs:
 - Bar graph: each group of bars is a column.
   The r-th bar in a group c corresponds to the (r, c) entry.
Both graphs use a data table as input.
=end

############################################################
# Properties of an axis
class Axis
  def tickIncludeAxis(v); @tickIncludeAxis = v; self end # Draw the tick at the axis
  def tickStartValue(v); @tickStartValue = v; self end # Start at this tick
  def tickIncrValue(v); @tickIncrValue = v; self end # Show a tick every this increment of value
  def numTicks(v); @numTicks = v; self end # Number of ticks to show (not applied if tickIncrValue is specified)
  def tickStyle(v); @tickStyle = v; self end # nil, :short, or :long
  def tickColor(v); @tickColor = v; self end
  def tickLength(v); @tickLength = v; self end
  def labelTicks(v=true); @labelTicks = v; self end # Whether to label the ticks
  def tickLabelPadding(v); @tickLabelPadding = v; self end
  def tickLabelScale(v); @tickLabelScale = v; self end
  def labelPadding(v); @labelPadding = v; self end # How much space to put between the label and the tick labels
  def labelScale(v); @labelScale = v; self end # Scale label by this
  def labelBold(v=true); @labelBold = v; self end # Whether the labels should be bold (unfortunately, the default is true)
  def range(*v); @range = v; self end # Range of values to use
  def length(v); @length = v; self end # How long this axis is
  def overshoot(v); @overshoot = v; self end # Extra spacing to overshoot
  def rotateAxisLabel(v=true); @rotateAxisLabel = v; self end # Probably only makes sense for y-axis
  def postAxis(&func); @postAxisFuncs << func; self end
  def roundPlaces(v); @roundPlaces = v; self end # Number of decimal places to print for y tick labels
  def sciNotation(v=true); @sciNotation = v; self end # 1e-6
  def abbrevLarge(v=true); @abbrevLarge = v; self end # 10K
  def expValue(v=true); @expValue = v; self end # Print out exponentiated values (useful for log-log plots)?

  def getTickIncludeAxis; @tickIncludeAxis end
  def getTickStartValue; @tickStartValue end
  def getTickIncrValue; @tickIncrValue end
  def getNumTicks; @numTicks end
  def getTickStyle; @tickStyle end
  def getTickColor; @tickColor end
  def getTickLength; @tickLength end
  def getLabelTicks; @labelTicks end
  def getTickLabelPadding; @tickLabelPadding end
  def getTickLabelScale; @tickLabelScale end
  def getLabelPadding; @labelPadding end
  def getLabelScale; @labelScale end
  def getLabelBold; @labelBold end
  def getRange; @range end
  def getLength; @length end
  def getOvershoot; @overshoot end
  def getRotateAxisLabel; @rotateAxisLabel end
  def getPostAxisFuncs; @postAxisFuncs end
  def getRoundPlaces; @roundPlaces end
  def getSciNotation; @sciNotation end
  def getAbbrevLarge; @abbrevLarge end
  def getExpValue; @expValue end

  def initialize
    @tickStartValue = nil
    @tickIncrValue = nil # Has precedence over numTicks
    @numTicks = 5
    @tickStyle = :long
    @tickColor = gray
    @labelTicks = true
    @tickLabelPadding = u(0.1)
    @tickLabelScale = 0.6
    @tickLength = u(0.1)
    @labelPadding = u(0.1)
    @labelScale = 0.8
    @labelBold = true
    @range = [nil, nil]
    @length = u(4)
    @postAxisFuncs = []
    @roundPlaces = 1
    @overshoot = u(0.2)
  end
end

############################################################
=begin
Dynamic state of an axis when drawing it; some variables such
as range and length may be different from the underlying axis.
They can be set after the rest of the graph is plotted.
We need to draw the following things in layers.
 - Axis line
 - Tick marks
 - Tick labels
 - Axis label
When we draw a layer, we do it with respect to the old offset,
and at the same time, determining the new offset (how far things
are sticking out), so we can switch to the new layer
=end
class AxisPrintState
  def getLength; @length end
  def length(v); @length = v end
  def tickLabels(v); @tickLabels = v end
  def getRange; @range end
  def range(minValue, maxValue)
    if maxValue - minValue < 1e-10 then
      maxValue += 1e-10
      minValue -= 1e-10
    end
    @range = @range.or([minValue, maxValue])
  end

  def initialize(writer, childrenStyle, rootPicNode, axis)
    @writer = writer
    @childrenStyle = childrenStyle
    @rootPicNode = rootPicNode
    @axis = axis
    @range = axis.getRange
    @length = axis.getLength
    # How far stuff is sticking out
    @oldOffset = u(0) # Where the current layer starts
    @newOffset = u(0) # Where the current layer ends
  end

  def valueToLength(value)
    @length.mul(roundExcess(1.0*(value-@range[0])/(@range[1]-@range[0])))
  end

  # Either x or y must be nil
  # If we're the x-axis, then then y must be nil
  def printObjAtLayer(obj, padding, x, y)
    raise "Exactly one of x and y must be nil" if (x == nil) == (y == nil)
    objPt = Value.pair(x || @oldOffset.sub(padding), # Where to draw
                       y || @oldOffset.sub(padding))
    picNode = overlay(obj).pivot((x ? 0 : 1), (y ? 0 : 1)).
      shift(objPt).print(@writer, @childrenStyle)
    @rootPicNode.appendChild(@writer, picNode)
    updateLayer(picNode, x, y)
  end
  def updateLayer(picNode, x, y)
    # Update offset for new layer
    borderPt = picNode.getPoint((x ? 0 : -1), (y ? 0 : -1))
    @newOffset = @writer.store(Value.min(@newOffset, x ? borderPt.ypart : borderPt.xpart))
  end
  def flushLayer; @oldOffset = @newOffset end

  def printAllElse(isYAxis, otherLength, label)
    # We perform the calculation for the x-axis, and then
    # transpose if isYAxis
    pair = lambda { |x,y| isYAxis ? Value.pair(y, x) : Value.pair(x, y) }
    list = lambda { |x,y| isYAxis ? [y, x] : [x, y] }

    # Draw axis line
    #debug @length, isYAxis, otherLength, label
    o = arrow(Value.origin, pair.call(@length.add(@axis.getOvershoot), 0))
    @axis.getPostAxisFuncs.each { |f| o = f.call(o) }
    @rootPicNode.appendChild(@writer, o.print(@writer, @childrenStyle))

    # Print ticks
    if @axis.getTickStyle then
      tickStartValue = @axis.getTickStartValue || @range[0]
      # Determine how to space the ticks
      if @axis.getTickIncrValue then
        tickIncrValue = @axis.getTickIncrValue.to_f
        numTicks = ((@range[1]-tickStartValue) / tickIncrValue).floor
        #puts [tickStartValue, @range[1]-tickStartValue, tickIncrValue, numTicks].inspect
      elsif @axis.getNumTicks
        numTicks = @axis.getNumTicks
        tickIncrValue = 1.0*(@range[1]-tickStartValue) / numTicks
      else
        raise 'Either tickIncrValue or numTicks must be specified'
      end

      # First draw them, and then label them.
      [:drawTick, :labelTick].each { |which|
        t0 = @axis.getTickIncludeAxis ? 0 : 1
        (t0..numTicks).each { |i| # For each tick...
          value = tickIncrValue*i+tickStartValue
          x = valueToLength(value)
          displayValue = @axis.getExpValue ? Math.exp(value) : value

          if which == :drawTick
            if @axis.getTickStyle == :short
              # Ticks stick out of the graph a little bit
              tickObj = edge(pair.call(x, 0), pair.call(x, @axis.getTickLength.negate))
            elsif @axis.getTickStyle == :long
              # Ticks go all the way across the graph
              tickObj = edge(pair.call(x, 0), pair.call(x, otherLength))
            else
              raise "Unknown tick style: #{@axis.getTickStyle}"
            end
            tickObj.color(@axis.getTickColor)
            tickPicNode = tickObj.print(@writer, @childrenStyle)
            @rootPicNode.prependChild(@writer, tickPicNode)
            updateLayer(tickPicNode, *list.call(x, nil))
          elsif which == :labelTick
            if @axis.getLabelTicks
              if @tickLabels
                text = @tickLabels[i-1]
              elsif @axis.getSciNotation
                text = sprintf "%.#{@axis.getRoundPlaces}e", displayValue
                man, exp = text.split(/e/); man = man.to_f; exp = exp.to_i
                m = roundExcess(man, @axis.getRoundPlaces)
                if @axis.getSciNotation == :math
                  if (m-1).abs < 0.1
                    text = "$10^{#{exp}}$"
                  else
                    text = "$#{m} \\times 10^{#{exp}}$"
                  end
                else
                  text = "#{m}e#{exp}"
                end
              elsif @axis.getAbbrevLarge
                if displayValue.abs < 1e3 then
                  c = ''
                elsif displayValue.abs < 1e6 then
                  c = 'K'
                  displayValue /= 1e3
                else
                  c = 'M'
                  displayValue /= 1e6
                end
                text = round(displayValue, @axis.getRoundPlaces).to_s+c
              else
                text = round(displayValue, @axis.getRoundPlaces).to_s
              end
              o = overlay(_(text).scale(@axis.getTickLabelScale))
              printObjAtLayer(o, @axis.getTickLabelPadding, *list.call(x, nil))
            end
          end
        }
        flushLayer
      }
    end

    # Axes labels
    if label # y-axis
      o = _(label).dscale(@axis.getLabelScale)
      o.bold if @axis.getLabelBold
      o.rotate(90) if @axis.getRotateAxisLabel
      printObjAtLayer(o, @axis.getLabelPadding, *list.call(@length.div(2), nil))
    end
    flushLayer
  end
end

############################################################
# Dynamic state of a graph while printing it.
# Includes the dynamic state of its axes.
class GraphPrintState
  attr_accessor :legendRows, :xstate, :ystate

  def initialize(writer, childrenStyle, rootPicNode, graph)
    @writer = writer
    @childrenStyle = childrenStyle
    @rootPicNode = rootPicNode
    @graph = graph

    @legendRows = [] # List of [icon, description] pairs.
    @xstate = AxisPrintState.new(writer, childrenStyle, rootPicNode, graph.xaxis)
    @ystate = AxisPrintState.new(writer, childrenStyle, rootPicNode, graph.yaxis)
  end
  
  def getColor(r); @graph.getColors[r % @graph.getColors.size] end

  def addToLegend(marker, description)
    raise "Null-description not allowed" unless description
    @legendRows << [marker, description]
  end

  def createLegend
    table(*legendRows).ospace.border(@graph.getLegendBorder).opaque.space.
      justify('c', 'cl').scale(@graph.getLegendScale)
  end

  def printAllElse
    @xstate.printAllElse(false, @ystate.getLength, @graph.getDataTable.getColName)
    @ystate.printAllElse(true, @xstate.getLength, @graph.getDataTable.getCellName)

    # Legend
    legendPosition = @graph.getLegendPosition
    if legendPosition && legendPosition[0] && legendRows.size > 0 then
      # Create the legend
      legend = createLegend
      legendPicNode = legend.print(@writer, @childrenStyle)

      # Find the position for the legend
      legendPaddingPair = Value.pair(@graph.getLegendPadding, @graph.getLegendPadding)
      halfLegendDim = @writer.store(Value.pair(legendPicNode.width.div(2), legendPicNode.height.div(2)))
      lowerLeft = @writer.store(halfLegendDim.add(legendPaddingPair))
      upperRight = @writer.store(Value.pair(@xstate.getLength, @ystate.getLength).sub(halfLegendDim).sub(legendPaddingPair))
      pt = @writer.store(Value.rectllur(lowerLeft, upperRight).getPoint(*legendPosition))
      dpt = @writer.store(pt.sub(legendPicNode.center))

      # Put it there
      legendPicNode.shift(@writer, dpt)
      @rootPicNode.appendChild(@writer, legendPicNode)
    end
  end
end

############################################################
=begin
The base class provides the following functionality
 - Drawing ticks and labels.
 - Adding stuff to a legend.
The derived class must override printToState
=end
class Graph < Obj
  attr_accessor :xaxis, :yaxis
  
  def getDataTable; @dataTable end
  
  def colors(*v);         @colors = v;         self end # The colors to use for each 
  def legendPosition(*v); @legendPosition = v; self end # Specified in terms of (xi, yi)
  def legendScale(v);     @legendScale = v;    self end
  def legendBorder(v);    @legendBorder = v;  self end
  def legendPadding(v);   @legendPadding = v;  self end
  def indices(*v);        @indices = v;        self end # For colors and createPointMarker, use indices instead of 0, 1, 2 (so we can be consistent across graphs)

  def errorBarThickness(v); @errorBarThickness = v; self end # Thickness of the lines used to draw the error bar
  def hortErrorBarWidth(v); @hortErrorBarWidth = v; self end # Width of the little horizontal serif on the error bar
  def vertErrorBarPostFunc(&v); @vertErrorBarPostFunc = v; self end # Call this on the vertical part of the bar
  def hortErrorBarPostFunc(&v); @hortErrorBarPostFunc = v; self end # Call this on the horizontal part of the bar

  def getColors; @colors end
  def getLegendPosition; @legendPosition end
  def getLegendScale; @legendScale end
  def getLegendBorder; @legendBorder end
  def getLegendPadding; @legendPadding end
  def getIndices; @indices end

  def xtickIncludeAxis(v=true); @xaxis.tickIncludeAxis(v); self end
  def ytickIncludeAxis(v=true); @yaxis.tickIncludeAxis(v); self end
  def xtickStartValue(v); @xaxis.tickStartValue(v); self end
  def ytickStartValue(v); @yaxis.tickStartValue(v); self end
  def xtickIncrValue(v); @xaxis.tickIncrValue(v); self end
  def ytickIncrValue(v); @yaxis.tickIncrValue(v); self end
  def xnumTicks(v); @xaxis.numTicks(v); self end
  def ynumTicks(v); @yaxis.numTicks(v); self end
  def xtickStyle(v); @xaxis.tickStyle(v); self end
  def ytickStyle(v); @yaxis.tickStyle(v); self end
  def xtickColor(v); @xaxis.tickColor(v); self end
  def ytickColor(v); @yaxis.tickColor(v); self end
  def xtickLength(v); @xaxis.tickLength(v); self end
  def ytickLength(v); @yaxis.tickLength(v); self end
  def xlabelTicks(v=true); @xaxis.labelTicks(v); self end
  def ylabelTicks(v=true); @yaxis.labelTicks(v); self end
  def xtickLabelPadding(v); @xaxis.tickLabelPadding(v); self end
  def ytickLabelPadding(v); @yaxis.tickLabelPadding(v); self end
  def xtickLabelScale(v); @xaxis.tickLabelScale(v); self end
  def ytickLabelScale(v); @yaxis.tickLabelScale(v); self end
  def xlabelPadding(v); @xaxis.labelPadding(v); self end
  def ylabelPadding(v); @yaxis.labelPadding(v); self end
  def xlabelScale(v); @xaxis.labelScale(v); self end
  def ylabelScale(v); @yaxis.labelScale(v); self end
  def xlabelBold(v); @xaxis.labelBold(v); self end
  def ylabelBold(v); @yaxis.labelBold(v); self end
  def xrange(*v); @xaxis.range(*v); self end
  def yrange(*v); @yaxis.range(*v); self end
  def xlength(v); @xaxis.length(v); self end
  def ylength(v); @yaxis.length(v); self end
  def xovershoot(v); @xaxis.overshoot(v); self end
  def yovershoot(v); @yaxis.overshoot(v); self end
  def xrotateAxisLabel(v=true); @xaxis.rotateAxisLabel(v); self end
  def yrotateAxisLabel(v=true); @yaxis.rotateAxisLabel(v); self end
  def xpostAxis(&f); @xaxis.postAxisFuncs(func); self end
  def ypostAxis(&f); @yaxis.postAxisFuncs(func); self end
  def xroundPlaces(v); @xaxis.roundPlaces(v); self end
  def yroundPlaces(v); @yaxis.roundPlaces(v); self end
  def xsciNotation(v=true); @xaxis.sciNotation(v); self end
  def ysciNotation(v=true); @yaxis.sciNotation(v); self end
  def xabbrevLarge(v=true); @xaxis.abbrevLarge(v); self end
  def yabbrevLarge(v=true); @yaxis.abbrevLarge(v); self end
  def xexpValue(v=true); @xaxis.expValue(v); self end
  def yexpValue(v=true); @yaxis.expValue(v); self end

  def initialize(dataTable)
    super()
    @dataTable = dataTable
    @xaxis = Axis.new
    @yaxis = Axis.new.rotateAxisLabel

    @colors = [blue, green, red, magenta, brown]
    @legendPosition = [+1, +1]
    @legendScale = 0.5
    @legendPadding = u(0.3)
    @legendBorder = 1
    @errorBarThickness = 1
    @hortErrorBarWidth = u(0.1)
  end

  def getLegend(&postFunc)
    overlay.postProcessor { |writer,rootObj|
      legend = @state.createLegend
      legend = postFunc.call(legend) if postFunc
      rootObj.postAdd(writer, legend)
    }
  end

  def drawErrorBar(xpt, r, c, writer, childrenStyle, rootPicNode, state)
    errorBars = @dataTable.getErrorBars
    return unless errorBars
    min, max = errorBars[r][c]
    return unless min && max
    minpt = xpt.add(Value.ypair(state.ystate.valueToLength(min)))
    maxpt = xpt.add(Value.ypair(state.ystate.valueToLength(max)))
    verte = edge(minpt, maxpt).thickness(@errorBarThickness)
    verte = @vertErrorBarPostFunc.call(verte) if @vertErrorBarPostFunc
    rootPicNode.appendChild(writer, verte.print(writer, childrenStyle)) if verte
    [minpt, maxpt].each { |pt|
      p1 = pt.sub(Value.xpair(@hortErrorBarWidth.mul(0.5)))
      p2 = pt.add(Value.xpair(@hortErrorBarWidth.mul(0.5)))
      horte = edge(p1, p2).thickness(@errorBarThickness)
      horte = @hortErrorBarPostFunc.call(horte) if @hortErrorBarPostFunc
      rootPicNode.appendChild(writer, horte.print(writer, childrenStyle)) if horte
    }
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    childrenStyle = style.createChildrenStyle
    rootPicNode = initPicNode(writer, style, Value.nullPicture)
    preInitState()
    @state = GraphPrintState.new(writer, childrenStyle, rootPicNode, self)
    printToState(writer, childrenStyle, rootPicNode, @state)
    finishPicNode(writer, style)
  end
end

############################################################
# Each group of bars is a row.
class BarGraph < Graph
  def barWidth(v);          @barWidth = v;          self end # Could be determined by x.length and number of bars as well
  def innerBarPadding(v);   @innerBarPadding = v;   self end # Amount of space between bars within the same group
  def outerBarPadding(v);   @outerBarPadding = v;   self end # Amount of space between groups of bars
  def rGhosts(v);           @rGhosts = v;           self end # Which rows to show
  def cGhosts(v);           @cGhosts = v;           self end # Which columns to show
  def colorCols(v=true);    @colorCols = v;         self end # Colors apply to columns rather than rows
  def barPostFunc(&f);      @barPostFunc = f;       self end # Can apply to a bar with arguments (top middle point,r,c)

  def initialize(dataTable)
    super(dataTable)
    @barWidth = u(0.5)
    @innerBarPadding = u(0)
    @outerBarPadding = u(0.75)
    @yaxis.range(0) # Default: start at 0
    @xaxis.tickStyle(nil) # No ticks
    @rGhosts = []
    @cGhosts = []
  end

  def preInitState; end

  def printToState(writer, childrenStyle, rootPicNode, state)
    state.ystate.range(
      @dataTable.getContents.map{|row| row.min}.min.to_f,
      @dataTable.getContents.map{|row| row.max}.max.to_f)

    # We're going to increment x as we print out more bars
    x = writer.store(@outerBarPadding)

    # For each column (group of bars)
    (0...@dataTable.getNumCols).each { |c|
      # Print label of column c in the middle of the group
      raise "Missing column labels" unless @dataTable.getColLabels
      xx = x.add(@barWidth.mul(@dataTable.getNumRows)) # x after the group
      if not @cGhosts[c]
        state.xstate.printObjAtLayer(_(@dataTable.getColLabels[c]).scale(@xaxis.getTickLabelScale),
          @xaxis.getLabelPadding, Value.mean(x, xx), nil)
      end

      # For each row (individual bars inside a group)
      (0...@dataTable.getNumRows).each { |r|
        color = state.getColor(@colorCols ? c : r)
        value = @dataTable.getContents[r][c]

        if (not @rGhosts[r]) && (not @cGhosts[c]) && value > state.ystate.getRange[0]
          # Draw the bar
          barHeight = state.ystate.valueToLength(value)

          # Bar interior
          robj = rect(@barWidth, barHeight).label("bar(#{r},#{c})")
          robj.shift(Value.xpair(x)).fill.color(color) # Set bar properties
          rootPicNode.appendChild(writer, robj.print(writer, childrenStyle))

          # Bar boundary
          robj = rect(@barWidth, barHeight)
          robj.shift(Value.xpair(x)) # Set bar properties
          rootPicNode.appendChild(writer, robj.print(writer, childrenStyle))

          # Draw error bars
          errorBars = @dataTable.getErrorBars
          if errorBars
            min, max = errorBars[r][c]
            xpt = Value.xpair(x.add(@barWidth.mul(0.5))) # Middle of the bar
            drawErrorBar(xpt, r, c, writer, childrenStyle, rootPicNode, state)
          end

          if @barPostFunc
            xpt = Value.pair(x.add(@barWidth.mul(0.5)), barHeight) # Middle of the bar
            o = @barPostFunc.call(xpt,r,c)
            rootPicNode.appendChild(writer, o.print(writer, childrenStyle)) if o
          end
        end

        writer.incr(x, @barWidth)
        writer.incr(x, @innerBarPadding) if r < @dataTable.getNumRows
      }
      writer.incr(x, @outerBarPadding)
    }
    state.xstate.flushLayer

    # Add to the legend
    (0...@dataTable.getNumRows).each { |r|
      next if @rGhosts[r]
      color = state.getColor(r)
      z = u(0.2)
      o = overlay(rect(z, z).fill.color(color), rect(z, z))
      state.addToLegend(o, @dataTable.getRowLabels[r]) if @dataTable.getRowLabels
    }

    state.xstate.length(x) # Now we know the length
    state.printAllElse
  end
end
def barGraph(dataTable); BarGraph.new(dataTable) end

############################################################
# Each line is a row
# Column name is x-axis name
# Cell name is y-axis name
class LineGraph < Graph
  def createPointMarker(&f); @createPointMarker = f; self end # Returns a point marker
  def modifyLine(&f); @modifyLine = f; self end # Takes a line segment and modifies it
  def pointScale(v); @pointScale = v; self end
  def lineThickness(v); @lineThickness = v; self end
  def useRowPairs(*v); @useRowPairs = v; self end
  def useAdjRowPairs(v=true); @useAdjRowPairs = v; self end # row pairs = [[0,1],[2,3],...]
  def withPoints(v=true); @withPoints = v; self end
  def withLines(v=true); @withLines = v; self end
  def useColLabels(v=true); @useColLabels = v; self end
  def pointMarkerInterval(v); @pointMarkerInterval = v; self end # Number of points between point markers
  def markerChars(*v); @markerChars = v; self end

  def self.char2marker(c)
    e = lambda { |x1,y1,x2,y2|
      f = 4
      edge("(#{x1*f},#{y1*f})", "(#{x2*f},#{y2*f})").thickness(2)
    }
    case c
      when '|' then overlay(e.call(0,+1,0,-1))
      when '-' then overlay(e.call(+1,0,-1,0))
      when 'x' then overlay(e.call(-1,-1,+1,+1), e.call(-1,+1,+1,-1))
      when '+' then overlay(e.call(-1,0,+1,0), e.call(0,-1,0,+1))
      when '*' then overlay(e.call(-1,-1,+1,+1), e.call(-1,+1,+1,-1), e.call(0,+1,0,-1), e.call(+1,0,-1,0))
      when 'o' then overlay(e.call(-1,-1,-1,+1), e.call(-1,+1,+1,+1), e.call(+1,+1,+1,-1), e.call(+1,-1,-1,-1))
      else raise "Unknown marker character: #{c}"
    end
  end

  def initialize(dataTable)
    super(dataTable)

    @createPointMarker = lambda { |i| LineGraph.char2marker(@markerChars[i%5]) }
    @markerChars = ['|', 'x', '*', 'o', '+']
    @modifyLine = lambda { |i,x| x }

    @pointScale = 1
    @lineThickness = 2
    @withLines = true
    @withPoints = true
  end

  def preInitState
    if not @useRowPairs
      if @useColLabels
        # All columns are dependent, independent is integer
        @useRowPairs = (0...@dataTable.getNumRows).map {|r| [nil, r]}
      elsif @useAdjRowPairs
        n = @dataTable.getNumRows
        raise "Number of rows needs to be even to pair up adjacent ones, but is #{n}" unless n % 2 == 0
        @useRowPairs = (0...n/2).map { |i| [2*i,2*i+1] }
      else
        # Assume first column is independent variable and all else is dependent
        @useRowPairs = (1...@dataTable.getNumRows).map {|r| [0, r]}
      end
    end
    if @useColLabels
      xtickStartValue(0)
      xtickIncrValue(1)
      xrange(0.5, @dataTable.getColLabels.size+0.5)
    end
  end

  def getWithLines(i); @withPoints.is_a?(Array) ? @withLines[i] : @withLines end
  def getWithPoints(i); @withPoints.is_a?(Array) ? @withPoints[i] : @withPoints end
  def getLineThickness(i); @lineThickness.is_a?(Array) ? @lineThickness[i] : @lineThickness end

  def printToState(writer, childrenStyle, rootPicNode, state)
    state.xstate.tickLabels(@dataTable.getColLabels) if @useColLabels

    state.xstate.range(
      @useRowPairs.map {|rx,ry| rx ? @dataTable.getContents[rx].min : 1}.min.to_f,
      @useRowPairs.map {|rx,ry| rx ? @dataTable.getContents[rx].max : @dataTable.getContents[ry].size }.max.to_f)
    state.ystate.range(
      @useRowPairs.map {|rx,ry| @dataTable.getContents[ry].min}.min.to_f,
      @useRowPairs.map {|rx,ry| @dataTable.getContents[ry].max}.max.to_f)

    @useRowPairs.each_with_index { |rxy,i| rx, ry = rxy
      idx = @indices ? @indices[i] : i
      # Create the points
      xvalues = rx ? @dataTable.getContents[rx] : [*(1..@dataTable.getContents[ry].size)] # If null, assume integers
      yvalues = @dataTable.getContents[ry]
      points = [xvalues, yvalues].transpose.map { |x,y|
        Value.pair(state.xstate.valueToLength(x), state.ystate.valueToLength(y))
      }
      color = state.getColor(idx)

      # Remove points out of range (note: changes indices)
      yrange = state.ystate.getRange
      points = points.map_with_index { |p,j|
        yvalues[j] < yrange[0] || yvalues[j] > yrange[1] ? nil : p # Ignore values which are out of range
      }.compact

      # Draw lines and points
      if getWithLines(i)
        o = path(*points).thickness(getLineThickness(i)).color(color)
        o = @modifyLine.call(idx, o)
        rootPicNode.appendChild(writer, o.print(writer, childrenStyle))
      end
      if getWithPoints(i)
        points.each_with_index { |p,j|
          next unless ((not @pointMarkerInterval) || j % @pointMarkerInterval == 0)
          o = @createPointMarker.call(idx)
          if o
            o.scale(@pointScale).color(color).shift(p).label("pt(#{ry},#{j})")
            rootPicNode.appendChild(writer, o.print(writer, childrenStyle))
          end

          drawErrorBar(Value.xpair(p.xpart), ry, j, writer, childrenStyle, rootPicNode, state)
        }
      end

      # Add to the legend
      contents = []
      contents << @modifyLine.call(idx, hedge(u(0.5)).thickness(3).color(color)) if getWithLines(i)
      o = @createPointMarker.call(idx)
      contents << o.color(color).scale(1.0/@legendScale) if o && getWithPoints(i)
      o = overlay(*contents).center
      state.addToLegend(o, @dataTable.getRowLabels[ry]) if @dataTable.getRowLabels
    }

    state.printAllElse
  end
end

def lineGraph(dataTable); LineGraph.new(dataTable) end
