############################################################

# Can specify the property in several ways
# Given a cell located at (r, c), return the property.
# defaultIsR: whether the default orientation is row (instead of column)
class Property
  attr_accessor :value, :rValue, :cValue, :rcValue

  def initialize(defaultIsR)
    @defaultIsR = defaultIsR
    @value       = nil # (*, *) -> value
    @rValue      = []  # (r, *) -> value
    @cValue      = []  # (*, c) -> value
    @rcValue     = []  # (r, c) -> value
  end
  def put(r, c, v)
    #debug r, c, v
    if r == nil && c == nil then
      if v.is_a?(Array) then
        if @defaultIsR then @rValue = v
        else                @cValue = v
        end
      else
        @value = v
      end
    elsif r == nil     then @cValue[c] = v
    elsif c == nil     then @rValue[r] = v
    else                    (@rcValue[r] = @rcValue[r] || [])[c] = v
    end
  end
  def putAfter(r, c, dr, dc, v)
    # Hack
    (0...10).each { |i| put(r && (r+dr*i), c && (c+dc*i), v) }
  end
  def get(r, c)
    if r == nil && c == nil then @value
    elsif r == nil          then @cValue[c] || @value
    elsif c == nil          then @rValue[r] || @value
    else                        (@rcValue[r] || [])[c] || @rValue[r] || @cValue[c] || @value
    end
  end
  def getMarg(isR, i); isR ? get(i, nil) : get(nil, i) end
  def incorporate!(prop)
    @value   = prop.value
    @rValue  = prop.rValue
    @cValue  = prop.cValue
    @rcValue = prop.rcValue
  end
end

# A style specifies either the horizontal (c) or vertical (r) placement
# of each cell in a table.
# Some properties such as length must be constant for each row or column.
# Others, such as justification and offset, can vary across every cell.
# How do we specify a cell-specific property conveniently?
# We might want to say that all the cells in the table have the same property,
# or that just the cells is a particular row or column,
# or a custom thing.
# For uniformity, we give all properties this flexibility,
# even if some specific settings are infeasible.
class DimStyle # One dimension of the table style (row or column)
  attr_accessor :length, :justify, :offset, :margin, :expand, :totalLength, :outerMargin, :numGhosts

  def initialize(style, defaultIsR)
    @margin        = Property.new(defaultIsR) # Only one global value used, not cell specific values
    @length        = Property.new(defaultIsR) 
    @offset        = Property.new(defaultIsR) 
    @justify       = Property.new(defaultIsR) 
    @expand        = Property.new(defaultIsR) # Whether to fill up the cell
    @totalLength   = nil
    @outerMargin   = nil
    @numGhosts     = [0, 0] # [number of left ghosts, number of right ghosts]
    incorporate!(style)
  end

  def incorporate!(style)
    return self unless style
    @margin.incorporate!(style.margin)
    @length.incorporate!(style.length)
    @offset.incorporate!(style.offset)
    @justify.incorporate!(style.justify)
    @expand.incorporate!(style.expand)
    @totalLength = style.totalLength || @totalLength
    @outerMargin = style.outerMargin || @outerMargin
    @numGhosts = style.numGhosts || @numGhosts
    self
  end

  def DimStyle.parseJustify(v) # e.g., v = "ccclr"
    return v unless v.is_a?(String)
    v = v.split(//).map { |x|
      case x
      when "c" then :center
      when "l" then :left
      when "r" then :right
      else raise 'Unknown: #{x}'
      end
    }
    v.size > 1 ? v : v[0] # If single element, just make it not an array
  end
end

class TableStyle
  attr_reader :rdim, :cdim
  attr_accessor :border, :borderColor, :borderDashed, :borderRounded, :bgColor, :opaque, :rdivider, :cdivider

  def initialize(style=nil);
    @rdim = DimStyle.new(nil, true)
    @cdim = DimStyle.new(nil, false)
    incorporate!(style)
  end

  def incorporate!(style)
    return self unless style
    rdim.incorporate!(style.rdim)
    cdim.incorporate!(style.cdim)
    @border = style.border || @border
    @borderColor = style.borderColor || @borderColor
    @borderDashed = style.borderDashed || @borderDashed
    @borderRounded = style.borderRounded || @borderRounded
    @bgColor = style.bgColor || @bgColor
    @opaque = style.opaque || @opaque
    @rdivider = style.rdivider || @rdivider
    @cdivider = style.cdivider || @cdivider
    self
  end
end

############################################################

class DeltaTableStyle
  def center;        @cjustify = :center; self end # Justification
  def left;          @cjustify = :left;   self end
  def right;         @cjustify = :right;  self end

  def change(style, r, c)
    style.cdim.justify.putAfter(r, c, 1, 0, @cjustify) if @cjustify
  end
end
def center;      DeltaTableStyle.new.center         end
def left;        DeltaTableStyle.new.left           end
def right;       DeltaTableStyle.new.right          end

############################################################
class Table < Obj
  def contents # Skip styles
    @contents.find_all { |row| row.is_a?(Array) }.map { |row|
      row.find_all { |obj| obj.is_a?(Obj) } }
  end

  def initialize(contents)
    super()
    @tableStyle = TableStyle.new
    @contents = filterObjArgs(contents).map { |row|
      row.is_a?(Array) ? filterObjArgs(row) : row
    }

    # Check that each row has the same number of columns
    numCols = nil
    @contents.each_with_index { |row,r|
      next unless row.is_a?(Array)
      # TODO: handle DormantContents classes
      currNumCols = row.map {|cell| modifier?(cell) ? 0 : 1}.sum # Count number of elements in the row
      if numCols != nil && numCols != currNumCols
        raise "All rows in a table must have the same number of columns, but row #{r} has #{currNumCols} columns and row 0 has #{numCols}"
      end
      row.each { |cell|
        if not (aboutStyle?(cell) || cell.is_a?(DeltaTableStyle) || cell.is_a?(Obj)) then
          raise "Expected style or object, but got #{cell.class}"
        end
      }
      numCols = currNumCols
    }

    # Set defaults
    margin(u(0.1), u(0.1))
    bgColor(white)
  end

  def print(writer, style)
    style = style.createEffectiveStyle(@style, @ignoreSpatialStyles)
    childrenStyle = style.createChildrenStyle # Style for children
    auxStyle = style.createChildrenStyle # For bounding box

    # Interpret dormant contents
    @newContents = []
    @contents.each { |row|
      if row.is_a?(DormantContents) then
        # The contents should return a list of rows
        @newContents += filterObjArgs(row.getContents)
      else
        @newContents << row
      end
    }
    @contents = @newContents

    writer.comment("Table.print")

    # Make a picture for each cell
    tableStyle = TableStyle.new(@tableStyle)
    picNodes = [] # Matrix of picture nodes
    @contents.each { |row|
      if aboutStyle?(row) then
        childrenStyle.incorporateExternalStyle!(row)
      elsif row.is_a?(DeltaTableStyle) then
        row.change(tableStyle, picNodes.size, nil)
      elsif row.is_a?(Array) then
        picNodes << (picNodes2 = [])
        # childrenStyle2 has scope only on the cells in the row
        # Don't call createChildrenStyle because applyStyle later
        # once to the table, not to every row
        childrenStyle2 = childrenStyle.createDuplicateStyle
        row.each { |cell|
          if aboutStyle?(cell) then
            childrenStyle2.incorporateExternalStyle!(cell)
          elsif cell.is_a?(DeltaTableStyle) then
            cell.change(tableStyle, picNodes.size, picNodes2.size)
          elsif cell.is_a?(Obj) then
            #puts childrenStyle2.getLevel, cell
            picNode = cell.print(writer, childrenStyle2)
            picNodes2 << picNode
          else
            raise "Unexpected type: #{cell.class}, wanted object or modifier"
          end
        }
      else
        raise "Unexpected type: #{row.class}, want array or modifier"
      end
    }

    # Check that each row has the same number of columns
    picNodes.each_index { |i|
      if picNodes[0].size != picNodes[i].size then
        raise "Two rows have different number of elements (row 0: #{picNodes[0].size}, row #{i}: #{picNodes[i].size})"
      end
    }

    def computeLengths(writer, dimStyle, picNodes, isR)
      if isR then
        specifiedLengths = (0...picNodes.size).map { |r| dimStyle.length.get(r, nil) }
      else
        specifiedLengths = (0...picNodes.size).map { |c| dimStyle.length.get(nil, c) }
      end

      totalLength = Value.zero # sum
      lengths = (0...picNodes.size).map { |i|
        maxLength = Value.zero # max
        if specifiedLengths[i] then # If length is specified, use it
          maxLength = specifiedLengths[i]
          #maxLength = Value.numeric(specifiedLengths[i])
        else # Otherwise, use the maximum length over the cells
          picNodes[i].each { |cell| # cell is a picNode
            len = isR ? cell.pic.height : cell.pic.width
            off = dimStyle.offset.getMarg(isR, i)
            if off && dimStyle.justify.getMarg(isR, i) != :center then
              len = len.add(off)
            end
            maxLength = Value.max(maxLength, len)
          }
        end
        maxLength = writer.store(maxLength)
        totalLength = totalLength.add(maxLength)
        maxLength
      }
      totalLength = writer.store(totalLength)

      # If the total length is specified,
      # There might be extra space left over;
      # distribute it evenly across the positions with unspecified lengths
      numSpecified = specifiedLengths.compact.size # Number of lengths specified
      totalPadding = dimStyle.totalLength ?
        dimStyle.totalLength.sub(totalLength).sub((dimStyle.margin.value || Value.zero).mul(lengths.size-1)) : 0
        #"(#{dimStyle.totalLength} - #{totalLength} - (#{(lengths.size-1)}*#{dimStyle.margin.value || 0}))" : 0
      isExpand = (0...picNodes.size).map { |i|
        # We can expand this cell if the length is unspecified, the expand flag is on,
        # and there will be room to expand
        dimStyle.totalLength && (not specifiedLengths[i]) && dimStyle.expand.getMarg(isR, i)
      }
      numExpand = isExpand.map { |e| e || nil }.compact.size
      pad = writer.store(totalPadding.div(numExpand)) if numExpand > 0
      extraPaddings = isExpand.map { |e| e ? pad : Value.zero }
      extraPaddings << (numExpand > 0 ? 0 : totalPadding) # Leftover padding

      [totalLength, lengths, extraPaddings]
    end

    # Compute actual width of each column and height of each row
    writer.comment("Table.print: compute lengths")
    totalRLength, rlengths, extraRPaddings = computeLengths(writer, tableStyle.rdim, picNodes, true)
    totalCLength, clengths, extraCPaddings = computeLengths(writer, tableStyle.cdim, picNodes.transpose, false)

    # Now actually draw it
    rootPicNode = initPicNode(writer, style, Value.nullPicture)
    z = writer.store(Value.origin) # Current position

    zUpperLeft = nil # Bounding box for non-ghost cells
    zLowerRightX = zLowerRightY = nil
    gr0, gr1 = tableStyle.rdim.numGhosts
    gc0, gc1 = tableStyle.cdim.numGhosts

    #p [picNodes.size, 'extra_r', extraRPaddings[-1]]

    picNodes.each_with_index { |row,r|
      writer.comment("Table.print: row #{r}")
      h = w = nil
      nr = picNodes.size
      nc = row.size
      raise "No rows" if nr == 0
      raise "No cols" if nc == 0
      raise "Too many ghosts: #{gr0+gr1} < #{nr}, #{gc0+gc1} < #{nc}" unless gr0+gr1 < nr && gc0+gc1 < nc

      # Margins
      rm = tableStyle.rdim.margin.value
      cm = tableStyle.cdim.margin.value
      rm = u(0) if rm == 0
      cm = u(0) if cm == 0
      paddedTotalRLength = totalRLength.add(rm.mul(nr-1))
      paddedTotalCLength = totalCLength.add(cm.mul(nc-1))

      # Draw horizontal dividers
      if tableStyle.rdivider && r > 0
        p = z.yadd(rm.mul(0.5))
        e = edge(p, p.xadd(paddedTotalCLength))
        e = tableStyle.rdivider.call(e,r)
        rootPicNode.appendChild(writer, e.print(writer, auxStyle)) if e
      end

      row.each_with_index { |cell,c|
        zUpperLeft = writer.store(z) if gr0 == r && gc0 == c

        # Draw vertical dividers
        if tableStyle.cdivider && r == 0 && c > 0
          p = z.xadd(cm.mul(0.5).negate).yadd(rm.mul(0.5))
          e = edge(p, p.yadd(paddedTotalRLength.add(rm.mul(0.5)).negate))
          e = tableStyle.cdivider.call(e,c)
          rootPicNode.appendChild(writer, e.print(writer, auxStyle)) if e
        end

        h = rlengths[r].add(extraRPaddings[r])
        w = clengths[c].add(extraCPaddings[c])

        # Figure out justification
        d = w.sub(cell.pic.width) # Extra space
        coffset = tableStyle.cdim.offset.get(r, c)
        case tableStyle.cdim.justify.get(r, c)
          when :left   then dx = coffset || Value.zero
          when :right  then dx = coffset ? d.sub(coffset) : d
          when :center then dx = d.mul(0.5)
          else              dx = coffset || Value.zero
        end
        d = h.sub(cell.pic.height)
        roffset = tableStyle.rdim.offset.get(r, c)
        case tableStyle.rdim.justify.get(r, c)
          when :left   then dy = roffset || Value.zero
          when :right  then dy = roffset ? d.sub(roffset) : d
          when :center then dy = d.mul(0.5)
          else              dy = roffset || Value.zero
        end

        # Put the cell at the desired location based on measurements
        cell.setULCorner(writer, z.add(Value.pair(dx, dy.negate)))
        rootPicNode.appendChild(writer, cell)

        writer.incrPair(z, w, Value.zero)
        zLowerRightX = writer.store(z.xpart) if gc1 == nc-c-1
        writer.incrPair(z, tableStyle.cdim.margin.value || 0, 0) if c < row.size-1
      }

      writer.decrPair(z, Value.zero, h)
      if r < picNodes.size-1 then
        zLowerRightY = writer.store(z.ypart) if gr1 == nr-r-1
        writer.decrPair(z, z.xpart, tableStyle.rdim.margin.value || 0)
      else # End of the table: place z at the lower-right corner of the box
        writer.incrPair(z, extraCPaddings[-1], 0)
        writer.decrPair(z, Value.zero, extraRPaddings[-1])
        zLowerRightY = writer.store(z.ypart) if gr1 == nr-r-1
      end
    }
    raise "No bounds" unless zUpperLeft && zLowerRightX && zLowerRightY

    # Draw bounding box around picture
    xmargin = tableStyle.cdim.outerMargin || Value.zero
    ymargin = tableStyle.rdim.outerMargin || Value.zero
    x1, y1 = zUpperLeft.xpart.sub(xmargin), zUpperLeft.ypart.add(ymargin)
    x2, y2 = zLowerRightX.add(xmargin), zLowerRightY.sub(ymargin)
    # These new picture nodes should be printed with Style.new,
    # because finishPicNode will apply the style.
    if tableStyle.opaque then
      # Blot out the background
      blot = rectllur(Value.pair(x1, y2), Value.pair(x2, y1)).color(tableStyle.bgColor).fill
      blot.rounded(tableStyle.borderRounded) if tableStyle.borderRounded
      rootPicNode.prependChild(writer, blot.print(writer, auxStyle))
    end
    if (tableStyle.border || 0) > 0 then
      # Draw a border
      border = rectllur(Value.pair(x1, y2), Value.pair(x2, y1)).color(tableStyle.borderColor).thickness(tableStyle.border)
      border.dashed(tableStyle.borderDashed) if tableStyle.borderDashed
      border.rounded(tableStyle.borderRounded) if tableStyle.borderRounded
      rootPicNode.appendChild(writer, border.print(writer, auxStyle))
    end
    writer.setBounds(rootPicNode.pic, x1, y1, x2, y2)

    writer.comment("Table.print: end")
    finishPicNode(writer, style)
  end

  # Convenient macros to change the tableStyle of the table
  def margin(vr, vc,  r=nil, c=nil);   rmargin(vr, r, c); cmargin(vc, r, c);    self end
  def rmargin(v,      r=nil, c=nil);   @tableStyle.rdim.margin.put(r, c, v);    self end
  def cmargin(v,      r=nil, c=nil);   @tableStyle.cdim.margin.put(r, c, v);    self end
  def space(v=u(0.2));                 rmargin(v); cmargin(v);                  self end
  def ospace(v=u(0.2));                outerMargin(v, v);                       self end
  def rlength(v,      r=nil, c=nil);   @tableStyle.rdim.length.put(r, c, v);    self end
  def clength(v,      r=nil, c=nil);   @tableStyle.cdim.length.put(r, c, v);    self end
  def roffset(v,      r=nil, c=nil);   @tableStyle.rdim.offset.put(r, c, v);    self end
  def coffset(v,      r=nil, c=nil);   @tableStyle.cdim.offset.put(r, c, v);    self end
  def justify(vr, vc, r=nil, c=nil);   rjustify(vr, r, c); cjustify(vc, r, c);  self end
  def rjustify(v,     r=nil, c=nil);   @tableStyle.rdim.justify.put(r, c, DimStyle.parseJustify(v)); self end
  def cjustify(v,     r=nil, c=nil);   @tableStyle.cdim.justify.put(r, c, DimStyle.parseJustify(v)); self end
  def center;                          rjustify('c'); cjustify('c');            self end
  def rexpand(v=true, r=nil, c=nil);   @tableStyle.rdim.expand.put(r, c, v);    self end
  def cexpand(v=true, r=nil, c=nil);   @tableStyle.cdim.expand.put(r, c, v);    self end
  def rTotalLength(v);                 @tableStyle.rdim.totalLength = v;        self end
  def cTotalLength(v);                 @tableStyle.cdim.totalLength = v;        self end
  def totalLength(vr, vc);             rTotalLength(vr); cTotalLength(vc);      self end
  def rOuterMargin(v);                 @tableStyle.rdim.outerMargin = v;        self end
  def cOuterMargin(v);                 @tableStyle.cdim.outerMargin = v;        self end
  def outerMargin(vr, vc);             rOuterMargin(vr); cOuterMargin(vc);      self end
  def rNumGhosts(v1=0, v2=0);          @tableStyle.rdim.numGhosts = [v1, v2];   self end
  def cNumGhosts(v1=0, v2=0);          @tableStyle.cdim.numGhosts = [v1, v2];   self end
  def border(v=1);                     @tableStyle.border = v;                  self end
  def borderColor(v);                  @tableStyle.borderColor = v;             self end
  def borderDashed(v='evenly');        @tableStyle.borderDashed = v;            self end
  def borderRounded(v);                @tableStyle.borderRounded = v;           self end
  def bgColor(v);                      @tableStyle.bgColor = v;                 self end
  def opaque(v=true);                  @tableStyle.opaque = v;                  self end

  def color(v); @contents.each do |x|  _(x).color(v); end; self; end

  # TODO
  def rdivider(v=lambda{|e,r|e});      @tableStyle.rdivider = v; self end
  def cdivider(v=lambda{|e,c|e});      @tableStyle.cdivider = v; self end

  def inspect; 'Table('+@contents.map{|row| '['+row.map {|o| o.inspect}.join(', ')+']'}.join(', ')+')' end
end
def table(*args);  Table.new(args) end
def rtable(*args) # args = rows
  process = lambda {|x| modifier?(x) ? x : [x]}
  Table.new(filterObjArgs(args).map {|x|
    if x.is_a?(DormantContents) then
      x.post{|contents| filterObjArgs(contents).map {|x| process.call(x)}}
    else
      process.call(x)
    end
  })
end
def ctable(*args) # args = cols
  Table.new([filterObjArgs(args)])
end
