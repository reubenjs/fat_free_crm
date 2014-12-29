# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
class AutocompleteInput < SimpleForm::Inputs::Base
  def input
    field = get_field
    
    script = template.content_tag(:script, type: 'text/javascript') do
      template.cdata_section("crm.text_with_autocomplete('#{@builder.object.class.to_s.downcase}_#{attribute_name}');")
    end
    
    input_html_options.merge!('data-autocompleteUrl' => "/autocompletes/#{field.collection_string}/get_results")

    @builder.text_field(attribute_name, input_html_options) + script
  end
  
  
  
  
  
  private
  
  # Autocomplete latches onto the 'text_with_autocomplete' class.
  #------------------------------------------------------------------------------
  def input_html_classes
    super.push('text_with_autocomplete')
  end
  
  # Returns the field as field1
  #------------------------------------------------------------------------------
  def get_field
    @field1 ||= Field.where(:name => attribute_name).first
  end
  

  ActiveSupport.run_load_hooks(:fat_free_crm_autocomplete_input, self)
end
