(($) ->
  
  window.crm ||= {}

  crm.text_with_autocomplete = (el_id) ->
    unless $("#text_with_autocomplete_" + el_id)[0]  
      $('#' + el_id).autocomplete
        minLength: 2
        source: (request, response) ->
          $.ajax
            url: $('#' + el_id).data('autocompleteurl')
            dataType: "json"
            data:
              name: request.term
            success: (data) ->
              response(data)
) jQuery