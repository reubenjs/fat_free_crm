$ ->
  $('#contacts-table').dataTable
    processing: true
    serverSide: true
    ajax: $('#contacts-table').data('source')
    pagingType: 'full_numbers'
    # optional, if you want full pagination controls.
    # Check dataTables documentation to learn more about
    # available options.