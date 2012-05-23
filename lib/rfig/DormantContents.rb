# Stores the information needed to create an object without actually executing
# any code.
class DormantContents
  # Returns a list of contents for the object.
  # Function to fetch the contents
  def initialize; @postFuncs = [] end
  def contents(&contentsFunc); @contentsFunc = contentsFunc; self end
  def post(&postFunc) @postFuncs << postFunc; self end

  def getContents
    x = @contentsFunc.call
    @postFuncs.each { |postFunc| x = postFunc.call(x) }
    x
  end
end

def contents(&contentsFunc); DormantContents.new.contents(&contentsFunc) end
