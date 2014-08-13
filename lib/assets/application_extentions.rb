#Extentions to base Ruby class Array
class Array
  
  #Joins the array elements with a comma and replaces the last comma with 'and'
  #==== Examples
  # ['a', 'b', 'c'].and_join # => 'a, b and c'
  # ['a', 'b'].and_join # => 'a and b'
  # ['a'].and_join # => 'a'
  def and_join    
    self.compact.join(", ").reverse.sub(",","dna ").reverse
    #takes array and joins with a comma.  The resultant string is then reversed and the first comma is replaced with 'dna ' 
    #'dna' is 'and' backwards, but is also a nice tribute to genomics and Douglas N. Adams.
    #the resultant string is then reversed again so now the right way round and the last comma has been replaced with 'and '
  end

  #Joins the array elements with a comma and replaces the last comma with 'or'
  #==== Examples
  # ['a', 'b', 'c'].or_join # => 'a, b or c'
  # ['a', 'b'].or_join # => 'a or b'
  # ['a'].or_join # => 'a'
  def or_join    
    self.compact.join(", ").reverse.sub(",","ro ").reverse
    #as and_join but uses 'or ' instead.  ['this', 'that', 'those'] => "this, that or those"
  end

  #sums the Array using the absolute values 
  def abs_sum
    self.compact.map{|i| i.respond_to?(:abs) ? BigDecimal.new(i.abs.to_s) : 0}.sum
    #values are converted into BigDecimals so as not to be summing floats
    #which goes wrong in C based languages (and others) 0.2+0.7=> 0.8999999999999999 
  end
end


#Extentions to base Ruby class Array
class Fixnum

  #returns a string that appends st, nd, rd, th to the integer
  #1st 2nd 3rd 4th 5th 11th 12th 111th 121st etc
  def as_nth
    t = self.to_s.each_char.to_a #split number into digits
    if t.size >= 2 # in order to deal with rule exceptions (11, 12, 13, 111, 112, 113 211, 212,213 etc)
      celf = [t[t.size-2],t[t.size-1]].join.to_i #get last two digits as integer
      return "#{self}th" if celf.eql?(11) || celf.eql?(12) || celf.eql?(13) #return 'th' if 11, 12 or 13
    end
    s = { 1 => "st", 2 => "nd", 3 => "rd"} #define endings which differ
    ((4..9).map{|f| f} << 0).each{ |i| s.merge!(i => "th") } #add to those the th endings
    ending = s[t.last.to_i] #select ending based on last digit of number
    "#{self}#{ending}"
  end 
end


class String

  def for_count count
    return self.singularize if count.eql?(1)
    return self.pluralize
  end

end

