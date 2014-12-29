class Autocomplete < ActiveRecord::Base
  validates_presence_of :name
  validates_presence_of :terms
  validates_uniqueness_of :name
  
  serialize :terms, Array
  
  def terms_string=(value)
    self.terms = value.lines.map(&:squish).reject(&:blank?)
  end
  def terms_string
    terms.try(:join, "\n")
  end
end