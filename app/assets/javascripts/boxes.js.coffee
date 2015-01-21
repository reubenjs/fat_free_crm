# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
(($) ->
  # Add collapse and remove events to boxes
  $(document).on "click", "[data-widget='collapse']", ->  
    
    # Find the box parent        
    box = $(this).parents(".box").first()
    # Find the body and the footer
    bf = box.find(".box-body, .box-footer")
    if (!box.hasClass("collapsed-box"))
      box.addClass("collapsed-box")
      # Convert minus into plus
      $(this).children(".fa-minus").removeClass("fa-minus").addClass("fa-plus")
      bf.slideUp()
    else
      box.removeClass("collapsed-box")
      # Convert plus into minus
      $(this).children(".fa-plus").removeClass("fa-plus").addClass("fa-minus")
      bf.slideDown()
  
  $(document).on "click", "[data-widget='remove']", ->
    # Find the box parent        
    box = $(this).parents(".box").first()
    box.slideUp()
    
  $(document).on "click", ".accordion-toggle", -> 
    title = $(this).parents(".box-title").first()
    if $(this).hasClass("collapsed")
      title.children(".intro").removeClass("hidden")
    else
      title.children(".intro").addClass("hidden")
  
  $(document).ajaxComplete ->
    $('input').iCheck
      checkboxClass: 'icheckbox_minimal'
      radioClass: 'iradio_minimal'
    
    $("input[id$='access_shared']:radio").on 'ifChanged', ->
      box = $(this).parents(".box-content").first()
      if $(this).is(":checked")
        box.find("#people").first().removeClass("hidden")
      else
        box.find("#people").first().addClass("hidden")
    
) jQuery
