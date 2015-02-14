# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
(($) ->

  # Open list save form
  $(document).on "click", ".lists .list_save a", ->
    $list = $(this).closest('.lists')
    $list.find(".list_form").show().find("[name='list[name]']").focus()
    $list.find(".list_save").hide()
    false
  
  $(document).on "click", "[data-toggle='offcanvas']", ->
    $("#left").toggleClass("menu-open")
    $("#right").toggleClass("menu-open")

) jQuery
