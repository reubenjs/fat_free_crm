# Copyright (c) 2008-2014 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------

# Any select box with 'select2' class will be transformed
(($) ->

  window.crm ||= {}

  crm.make_select2 = ->
    $(".select2").not(".select2-container, .select2-offscreen").each ->
    #$(".select2").each ->
      $(this).select2 'width':'100%'

    $(".select2_tag").not(".select2-container, .select2-offscreen").each ->
    #$(".select2_tag").each ->
      $(this).select2
        'width':'resolve'
        tags: $(this).data("tags")
        placeholder: $(this).data("placeholder")
        multiple: $(this).data("multiple")
        
    $(".select2_ajax").not(".select2-container, .select2-offscreen").each ->
      $(this).select2
        width: "100%"
        ajax:
          url: $(this).data('url')
          dataType: 'json'
          delay: 250
          data: (params) ->
            queryParams =
              auto_complete_query: params # search term
            return queryParams

          results: (data) ->
  
            # parse the results into the format expected by Select2.
            # since we are using custom formatting functions we do not need to
            # alter the remote JSON data
            results: data

          cache: true
        initSelection: (element, callback) ->
          # the input tag has a value attribute preloaded that points to a preselected repository's id
          # this function resolves that id attribute to an object that select2 can render
          # using its formatResult renderer - that way the repository name is shown preselected
          id = $(element).val()
          if id isnt ""
            $.ajax($(element).data('url') + "?auto_complete_id=" + id,
              dataType: "json"
            ).done (data) ->
              callback data[0]
              return

          return
              
        minimumInputLength: 2
        #templateResult: formatRepo # omitted for brevity, see the source of this page
        #templateSelection: formatRepoSelection # omitted for brevity, see the source of this page

  $(document).ready ->
    crm.make_select2()

  $(document).ajaxComplete ->
    crm.make_select2()

) jQuery
