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
require 'seedable'
class FormType < ActiveRecord::Base
  include Seedable
  
  has_many(:forms)
  
  default_scope(order("name"))
  
  def self.generate
    seed(:name, :name => "Type 1")
    seed(:name, :name => "Type 2")
  end
  
  def self.select_options
    all.collect{|ft| [ft.name, ft.id]}
  end
end
