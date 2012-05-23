############################################################
# General utilities

$infty = 1000000

class Array
  def map_index
    a = []
    each_index { |i| a << yield(i) }
    a
  end
  def map_with_index
    a = []
    each_with_index { |x,i| a << yield(x, i) }
    a
  end

  def minIndex
    besti = -1
    (0...size).each { |i|
      besti = i if besti == -1 || self[i] < self[besti]
    }
    besti
  end

  def range; [min, max] end

  def incr(i, x=1); if at(i) then self[i] += x; else self[i] = x end end

  # For matrices
  def transpose
    return [] if size == 0
    (0...self[0].size).map { |c| (0...self.size).map { |r| self[r][c] } }
  end
  def col(i); a = []; each {|r| a << r[i]}; a end # Column i of a matrix
  def to_i; map{|x| x.to_i} end
  def to_f; map{|x| x.to_f} end

  def sum; s = 0; each{|x| s += x}; s end
  #def normalize; s = sum; map{|x| x/s} end
  def normalize; s = sum*1.0; each_index{|i| self[i] /= s}; self end # Match myutils.rb

  def or(a)
    (0...[size, a.size].max).map { |i| self[i] || a[i] }
  end
end

class Hash
  def isSubsetOf(h)
    each_key { |k| return false unless h[k] }
    true
  end
end

class IO
  def IO.writelines(file, lines)
    out = Kernel.open(file, "w")
    lines.each { |line| out.puts line }
    out.close
  end
end

#def round(x, n=4); n == 0 ? (x+0.5).to_i : (x*(10**n)+0.5).to_i/(10.0**n) end
def round(x, n=0) # Match myutils
  return (x+0.5).to_i if n == 0
  b = 1; n.times { b *= 10 }
  (x*b+0.5).to_i.to_f / b
end

def default(x, y); x != nil ? x : y end
def debug(*s); puts "DEBUG: #{s.inspect}" end

# Simple way to process command-line arguments
# Return [value1, ... valueK]; modifies args
# If remove, we remove the used arguments from args.
# Each element of names is either a string name
# or a tuple [name, type, default value, required].
def extractArgs(options)
  d = lambda { |x,y| x != nil ? x : y }
  args = options[:args] || ARGV
  remove = d.call(options[:remove], true)
  spec = options[:spec] || []
  recognizeAllOpts = d.call(options[:recognizeAllOpts], true)

  arr = lambda { |x| x.is_a?(Array) ? x : [x] }
  spec = spec.compact.map { |x| arr.call(x) }
  names = spec.map { |x| x[0] }
  types = spec.map { |x| x[1] || String }
  values = spec.map { |x| x[2] != nil ? arr.call(x[2]) : nil } # Default values, to be replaced
  requireds = spec.map { |x| x[3] }

  # Print help?
  args.each { |arg|
    if arg == '-help'
      puts 'Usage:'
      spec.each { |name,type,value,required|
        puts "  -#{name}: #{type} [#{value}]#{required ? ' (required)' : ''}"
      }
    end
  }
  
  newArgs = [] # Store the arguments that we don't remove
  i = nil
  verbatim = false
  persistentVerbatim = false
  args.each { |arg|
    if arg == '--' then
      verbatim = true
    elsif arg == '---' then
      persistentVerbatim = !persistentVerbatim
    elsif (not verbatim) && (not persistentVerbatim) && arg =~ /^-(.+)$/ then
      x = $1
      #i = names.index($1)
      # If $1 is the prefix of exactly one name in names, then use that
      matchi = [names.index(x)].compact # Try exact match first
      matchi = names.map_with_index { |name,j| name =~ /^#{x}/ ? j : nil }.compact if matchi.size == 0
      if recognizeAllOpts then
        if matchi.size == 0
          puts "No match for -#{x}"
          exit 1
        elsif matchi.size > 1
          puts "-#{x} is ambiguous; possible matches: "+matchi.map{|i| "-"+names[i]}.join(' ')
          exit 1
        end
      end
      i = (matchi.size == 1 ? matchi[0] : nil)

      values[i] = [] if i
      verbatim = false
    else
      values[i] << arg if i
      verbatim = false
    end
    newArgs << arg unless remove && i
  }
  args.clear
  newArgs.each { |arg| args << arg }

  (0...names.size).each { |i|
    if requireds[i] && (not values[i]) then
      puts "Missing required argument: -#{names[i]}"
      exit 1
    end
  }

  # Interpret values according to the types
  values.each_index { |i|
    next if values[i] == nil
    t = types[i]
       if t == String    then values[i] = values[i].join(' ')
    elsif t == Fixnum    then values[i] = values[i][0].to_i
    elsif t == Float     then values[i] = values[i][0].to_f
    elsif t == TrueClass then values[i] = (values[i].size == 0 || values[i][0].to_s == 'true')
    elsif t.is_a?(Array) then
      t = t[0]
         if t == String    then values[i] = values[i]
      elsif t == Fixnum    then values[i] = values[i].map { |x| x.to_i }
      elsif t == Float     then values[i] = values[i].map { |x| x.to_f }
      elsif t == TrueClass then values[i] = values[i].map { |x| x == 'true' }
      else "Unknown type: '#{types[i][0]}'"
      end
    else raise "Unknown type: '#{types[i]}'"
    end
  }

  values
end

# Responsible for calling system and running commands.
class ExternalCommand
  def ExternalCommand.exec(options)
    command = options[:command] or raise "Command not specified"
    args = options[:args] || []
    showCommand = options[:showCommand]
    abortIfFail = default(options[:abortIfFail], true)
    returnOutput = options[:returnOutput]

    # First see if the command is in the bin directory
    rfigCommand = (ENV['RFIG_DIR'] || File.expand_path(File.dirname(__FILE__)+"/../.."))+"/bin/"+command
    command = rfigCommand if File.exists?(rfigCommand)

    s = ([command] + args.map { |x| '"'+x.to_s+'"' }).join(' ')
    puts s if showCommand

    # Run
    return `#{s}` if returnOutput
    if system s then
      true
    else
      if abortIfFail
        puts "Command failed:\n#{s}"
        exit 1
      end
      false
    end
  end
end
