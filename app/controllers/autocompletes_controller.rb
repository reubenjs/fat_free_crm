class AutocompletesController < ApplicationController
  def get_results
    if params[:id] && params[:name]
      if list = Autocomplete.find_by_name(params[:id])
        
        #construct regex /.*(?=.*TERM1.*)(?=.*TERM2.*) ... .*/
        r = ".*"
        search_terms = params[:name].split(" ").each do |t|
          r += "(?=.*#{t}.*)"
        end
        r += ".*"
      
        result = list.terms.select{ |s| s =~ /#{r}/i  }
      
        result.collect do |t|
          { value: t }
        end
        
        render json: result
        
      else
        render json: "list not found", status: 404
      end
    else
      render json: "list and search term(s) required", status: 500
    end
  end
end