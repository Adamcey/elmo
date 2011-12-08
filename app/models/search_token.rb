# ELMO - Secure, robust, and versatile data collection.
# Copyright 2011 The Carter Center
#
# ELMO is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ELMO is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with ELMO.  If not, see <http://www.gnu.org/licenses/>.
# 
class SearchToken
  attr_reader :sql
  def initialize(str, klass)
    @str = str
    @klass = klass

    # if this token is a boolean operator, just echo it back
    if %w[and or not].include?(@str)
      @sql = @str 
      return 
    end
    
    # get the field spec from the target class
    @field_spec = @klass.search_fields
    
    # if this token begins or ends with a parenth, save it.
    @str.gsub!(/^(\()/, "")
    oparenth = $1 || ""
    @str.gsub!(/(\))$/, "")
    cparenth = $1 || ""
    
    # if this token contains a qualifier
    if @str.match(/^(\w+):(.+)$/)
      qualifier, term = $1.to_sym, $2
      # raise an error if the qualifier is invalid
      raise SearchError.new("Invalid search qualifier '#{qualifier}'") unless @field_spec[qualifier]
      @used_fields = [qualifier]
    else
      # else, search default fields (get all fields with default param set to true)
      @used_fields = @field_spec.reject{|k,v| !v[:default]}.keys
      term = @str
    end
    
    # if the term is a regular expression, set a flag and remove the /'s
    if term.match(/\/(.+)\//)
      raise SearchError.new("Regular expressions not allowed for #{@used_fields.first}") unless @field_spec[@used_fields.first][:regexp]
      regexp = true
      term = $1
    else
      regexp = false
    end
    
    # for each field, create a fragment
    fragments = []
    @used_fields.each do |field|
      lhs, op, rhs = @klass.query_fragment(field, term)
      # if the term is a regexp, the op must be 'rlike', so override it
      if regexp
        # get rid of the %'s if the op was 'like'
        rhs.gsub!(/(^%|%$)/, "") if op == "like"
        op = "rlike"
      end
      
      fragments << sanitize("#{lhs} #{op} ?", rhs)
    end
    
    # join fragments with 'or' (note this is only for one token.. actual boolean operators are separate)
    @sql = oparenth + "(" + fragments.join(' or ') + ")" + cparenth
  end
  def sanitize(*args)
    ActiveRecord::Base.__send__(:sanitize_sql, args, '')
  end
  # get the eager loaded associations needed for this token
  def eager
    @used_fields ? @used_fields.collect{|f| @field_spec[f][:eager]}.compact.flatten.uniq : []
  end
end
