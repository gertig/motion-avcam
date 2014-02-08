class Utils

  def self.boolValue(val)
    case val
    when 0
      return false
    when 1
      return true
    when nil
      return false
    when true
      return true
    when false
      return false
    else
      return false
    end
  end

end