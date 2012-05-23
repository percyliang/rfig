############################################################
class DataTable
  def cellName(v); @cellName = v; self end
  def rowName(v); @rowName = v; self end
  def colName(v); @colName = v; self end
  def rowLabels(v); @rowLabels = v; self end
  def colLabels(v); @colLabels = v; self end
  def contents(v); @contents = v; self end
  def errorBars(v); @errorBars = v; self end

  def getCellName; @cellName end
  def getRowName; @rowName end
  def getColName; @colName end
  def getRowLabels; @rowLabels end
  def getColLabels; @colLabels end
  def getContents; @contents end
  def getErrorBars; @errorBars end

  def getNumRows; @contents.size end
  def getNumCols; @contents[0].size end

  def initialize(options)
    @cellName = options[:cellName]
    @rowName = options[:rowName]
    @colName = options[:colName]
    @rowLabels = options[:rowLabels]
    @colLabels = options[:colLabels]
    @contents = options[:contents]
    @errorBars = options[:errorBars]
    validate
  end
  def validate
    if @rowLabels && @rowLabels.size != getNumRows then
      raise "#{@rowLabels.size} row labels, but #{getNumRows} rows"
    end
    if @colLabels && @colLabels.size != getNumCols then
      raise "#{@colLabels.size} column labels, but #{getNumCols} columns"
    end
  end
end

############################################################
class LatexTable < Obj
  # Lines: between rows, between columns, border
  def initialize(dataTable)
    super()
    @rowRange = []
    @colRange = []
    @dataTable = dataTable
    @linesBetweenRows = true
    @linesBetweenCols = true
    @linesBorder = true
    @upperLeftIsColName = false
    @justify = nil
    @frontJustify = 'l'
  end

  def lines(v=true);        linesBetween(v); linesBorder(v);           self end
  def linesBetween(v=true); @linesBetweenRows = @linesBetweenCols = v; self end
  def linesBetweenRows(v=true); @linesBetweenRows = v; self end
  def linesBetweenCols(v=true); @linesBetweenCols = v; self end
  def linesBorder(v=true);  @linesBorder = v;                          self end
  def upperLeftIsColName(v=true); @upperLeftIsColName = v;             self end
  def justify(v); @justify = v; self end
  def frontJustify(v); @frontJustify = v; self end

  def getDataTable; dataTable end

  # Full range is [-1, n)
  def rowRange(v1, v2); @rowRange = [v1, v2]; self end
  def colRange(v1, v2); @colRange = [v1, v2]; self end

  def render
    r1, r2 = (@rowRange[0] || 0), (@rowRange[1] || @dataTable.getRowLabels.size)
    c1, c2 = (@colRange[0] || 0), (@colRange[1] || @dataTable.getColLabels.size)
    r1 = [r1, 0].max; c1 = [c1, 0].max
    raise 'Out of range' if r2 < 0 || c2 < 0

    justify = @justify ? @justify[c1...c2] : "c"*(c2-c1)
    align = (@frontJustify+justify)
    align = align.gsub(//, '|')[1..-2] if @linesBetweenCols # Put | between every column
    align = align[0..0]+"|"+align[1..-1] if c2-c1 > 1 # Always have this line separating labels
    align = "|"+align+"|" if @linesBorder # Border line
    out = []
    out << "\\begin{tabular}{#{align}}"
    out << '\hline' if @linesBorder # Border line
    upperLeftName = @upperLeftIsColName ? @dataTable.getColName : @dataTable.getRowName
    out << ([upperLeftName] + @dataTable.getColLabels[c1, c2]).join(' & ') + ' \\\\'
    out << '\hline' # Always have this line separating labels from data
    (r1...r2).each { |r|
      row = @dataTable.getContents[r]
      out << '\hline' if @linesBetweenRows
      if row
        out << ([@dataTable.getRowLabels[r]] + (c1...c2).map {|c| row[c].to_s}).join(' & ') + ' \\\\'
      else # Nil row means new a bar
        out << '\hline'
      end
    }
    out << '\hline' if @linesBorder
    out << '\end{tabular}'
    out.join("\n")
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    initFinishPicNode(writer, style, _(render))
  end
end
def latexTable(dataTable); LatexTable.new(dataTable) end

# Show one column at a time
def staggerCols(dataTable, baseLevel)
  overlay(*(0..dataTable.getColLabels.size).map {
    |c| latexTable(dataTable).colRange(-1, c).level(baseLevel+c) }
    ).pivot(-1, +1)
end
def staggerRows(dataTable, baseLevel)
  overlay(*(0..dataTable.getRowLabels.size).map {
    |r| latexTable(dataTable).rowRange(-1, r).level(baseLevel+r) }
    ).pivot(-1, +1)
end
