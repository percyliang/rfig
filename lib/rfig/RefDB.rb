############################################################
# Manages references and citations.
class RefDB
  # Example line:
  # ferguson73dp\tFerguson, 1973\tT. S. Ferguson. A Bayesian analysis of some nonparametric problems. Annals of Statistics, 1973.
  def initialize(inPath)
    @cites = {}
    @entries = {}
    IO.foreach(inPath) { |line|
      name, cite, entry = line.chomp.split("\t")
      @cites[name] = cite
      @entries[name] = entry
    }
  end
  def cite(*names) # => [Ferguson, 1973]
    hard = false
    '['+names.map { |name|
      name = name.to_s
      if @cites[name] then
        @cites[name].sub(/.&/, '\;\\\\&')
      elsif hard then
        raise "Unknown name: #{name}"
      elsif name =~ /^\{/
        name
      else
        "UNKNOWNCITE(#{name})"
      end
    }.join('; ')+']'
  end
  def emcite(name) # => Ferguson (1973)
    name = name.to_s
    if @cites[name] then
      @cites[name].sub(/.&/, '\;\\\\&').sub(/, (\d+)$/, ' (\1)')
    else
      "UNKNOWNCITE(#{name})"
    end
  end
  def entry(name, description=nil)
    @entries[name] + (description ? " \\brown{#{description}}" : "") or raise "Unknown name: #{name}"
  end
end

def initRefDB(inPath); $refDB = RefDB.new(inPath) end 
def cite(*names); $refDB.cite(*names) end
def emcite(name); $refDB.emcite(name) end
def refEntry(name, description=nil); $refDB.entry(name, description) end
