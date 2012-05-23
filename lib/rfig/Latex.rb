# Make it easier to write Latex in Ruby

class LatexValue
  def initialize(value); @value = value end

  def sub(i); lv("#{@value}_{#{i}}") end
  def sup(i); lv("#{@value}^{#{i}}") end
  def m; lv("$#{@value}$") end

  # Apply some Latex function to this
  def f(funcName); lv("\\#{funcName}{{#{@value}}}") end

  # Standard Latex functions
  def ensuremath; f('ensuremath') end
  def text; f('text') end
  def color(color); f(color) end
  def mathbb; f('mathbb') end
  def mathbf; f('mathbf') end
  def mathcal; f('mathcal') end
  def boldmath; f('boldmath') end
  def mbox; f('mbox') end
  def mathop; f('mathop') end
  def xrightarrow; f('xrightarrow') end

  def padSpace; lv("\\,#{@value}\\,") end

  def to_s; @value end
end
def lv(value); LatexValue.new(value) end

class Latex
  # Define new latex commands
  def newCommand(name, body, numArgs=0)
    numArgSpec = numArgs > 0 ? "[#{numArgs}]" : ""
    lv("\\newcommand\\#{name}#{numArgSpec}{#{body}}")
  end
  def renewCommand(name, body, numArgs=0)
    numArgSpec = numArgs > 0 ? "[#{numArgs}]" : ""
    lv("\\renewcommand\\#{name}#{numArgSpec}{#{body}}")
  end
  def newMathCommand(name, body, numArgs=0)
    newCommand(name, lv(body).ensuremath, numArgs)
  end
  def newTextCommand(name, body, numArgs=0)
    newCommand(name, lv(body).text, numArgs)
  end
  def newColoredMathCommand(name, color, body, numArgs=0)
    newMathCommand(name, lv(body).color(color), numArgs)
  end

  def f(funcName, *args); lv("\\#{funcName}"+args.map{|a| "{#{a}}"}.join('')) end
  def stackrel(a, b); f('stackrel', a, b) end
end
