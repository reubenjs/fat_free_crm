(($) ->
  window.crm ||= {}

  crm.init_draggables = ->
    $('.draggable').draggable(
      #revert: true
      handle: '.gravatar'
      scroll: true
      helper: "clone"
      opacity: 0.6
    )
  
  crm.init_droppables = ->
    $('.droppable').droppable(
      hoverClass: "dropover"
      tolerance: "pointer"
      drop: (event, ui) ->
        $.post( window.crm.base_url + "/" + this.id.split("_")[0] + "s/" + this.id.split("_").pop() + "/move_contact"
          {
            contact_id: ui.draggable.attr('id').split("_").pop()
          }
        )
    )

  $(document).ready ->
    crm.init_draggables()
    crm.init_droppables()
  
  $(document).ajaxComplete ->
    crm.init_draggables()
    crm.init_droppables()

) jQuery
