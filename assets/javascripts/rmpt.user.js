$(document).ready(function() {
  $(document.body).on('click', '.rmpt-ut-cat-expander', function() {
    var $tr = $(this).closest('tr');
    var parent_id = $tr.attr('data-id');
    if ($tr.hasClass('collapsed')) {
      $tr.removeClass('collapsed');
      $tr.closest('table').find('.ctp-' + parent_id).removeClass('closed');
    } else {
      $tr.addClass('collapsed');
      $tr.closest('table').find('.p-' + parent_id).addClass('closed');
      $tr.closest('table').find('.rmpt-ut-cat.p-' + parent_id).addClass('collapsed');
    }
    return false;
  });
});