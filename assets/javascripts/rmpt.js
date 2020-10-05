RMPlus.TR = (function (my) {
  var my = my || {};

  my.question_form = '';
  my.questions_total_count = null;

  my.category_form = '';
  my.ajax_test_id = 0;
  my.lbl_moving_category = '';
  my.lbl_moving_to_category = '';
  my.lbl_close = '';
  my.lbl_root = '';

  my.override_attachments_upload_blob = function() {
    var rmptOriginalUploadBlob = uploadBlob;
    uploadBlob = function (blob, uploadUrl, attachmentId, options) {
      var ajax = rmptOriginalUploadBlob.call(this, blob, uploadUrl, attachmentId, options);

      $('.rmpt-q-form td:last .acl-btn-flat').addClass('disabled');

      return ajax.always(function() {
        var form = $('.rmpt-q-submit-form');
        if (form.queue('upload').length == 0 && ajaxUpload.uploading == 1) {
          $('.rmpt-q-form td:last .acl-btn-flat').removeClass('disabled');
        }
      });
    };
  };

  my.add_answer_option = function($elem) {
    var $form = $elem.closest('.rmpt-q-form');
    var value = $elem.val();
    value = $.trim(value);
    if (!value) {
      return;
    }
    var type = $form.find('.rmpt-q-form-type').val();
    var $container = $form.find('.rmpt-q-form-answers-container');
    $elem.val('');

    var input_type = (type == 0 ? 'radio' : 'checkbox');
    var $drag_handler = $('<span class="rmpt-q-form-a-drag">≡</span>');
    var $correct = $('<input type="' + input_type + '" name="rmpt_question[answers_attributes][][correct]" title="' + $elem.attr('data-atitle') + '" value="true" class="rmpt-q-form-a-correct">');
    var $answer = $('<input type="text" name="rmpt_question[answers_attributes][][text]" class="rmpt-q-form-a-answer" title="' + $container.attr('data-edit') + '">');
    var $remove = $('<a href="#" class="no_line rm-icon rm-nom fa-trash rmpt-q-form-remove-answer" title="' + $container.attr('data-del') + '"></a>');
    $answer.val(value);

    var $tmp = $('<tr></tr>');
    $tmp.append($('<td></td>').append($drag_handler));
    $tmp.append($('<td></td>').append($correct));
    $tmp.append($('<td></td>').append($answer));
    $tmp.append('<td>&times;</td>');
    $tmp.append($('<td></td>').append($remove));
    $container.append($tmp);
  };

  my.change_answer_options_type = function ($elem) {
    var input_type = ($elem.val() == 0 ? 'radio' : 'checkbox');
    var was_checked = false;
    $elem.closest('.rmpt-q-form').find('.rmpt-q-form-answers-container .rmpt-q-form-a-correct').each(function() {
      var $this = $(this);
      var $new = $('<input type="' + input_type + '" name="rmpt_question[answers_attributes][][correct]" title="' + $this.attr('title') + '" value="true" class="rmpt-q-form-a-correct">');
      if ((input_type === 'checkbox' || !was_checked) && $this.prop('checked')) {
        was_checked = true;
        $new.prop('checked', true);
      }
      $this.replaceWith($new);
    });
  };

  my.make_questions_sortable = function ($container) {
    $container.sortable({
      cursor: 'move',
      delay: 0,
      handle: '.rmpt-q-drag',
      items: 'tr',
      axis: 'y',
      tolerance: 'pointer',
      start: function (event, ui) {
        ui.placeholder.html(ui.item.html()); // just to prevent table cells resize
        ui.placeholder.css({ visibility: 'visible' });
      },
      stop: function () {
        $('#rmpt-questions-list').removeAttr('style');
      },
      helper: function (e, tr) {
        $('#rmpt-questions-list').css({position: 'initial'});
        var cl = tr.clone();
        cl.removeAttr('id');
        cl.removeAttr('class');
        cl.addClass('rmpt-hover');
        cl.height(tr.outerHeight());
        cl.width(tr.outerWidth() + 1);
        cl.css({ left: tr.closest('table').offset().left });

        var $originals = tr.children();
        cl.children().each(function (index) {
          var it = $originals.eq(index);
          $(this).width(it.outerWidth());
        });
        return cl;
      },
      update: function(event, ui) {
        var id = ui.item.attr('id').split('-')[2];
        var url = RMPlus.Utils.relative_url_root + '/rmpt_questions/' + id + '/reorder';
        var pos = ui.item.closest('tbody').find('tr').index(ui.item);

        $('#rmpt-questions-list').append('<div class="acl-fullscreen-loading-mask"><div class="form_loader big_loader"></div></div>');
        $.ajax({
          type: 'POST',
          data: { position: pos },
          url: url
        }).always(function () {
          $('#rmpt-questions-list').find('.acl-fullscreen-loading-mask').remove();
        });
      }
    });
  };
  my.make_answers_sortable = function ($container) {
    $container.sortable({
      cursor: 'move',
      delay: 0,
      handle: '.rmpt-q-form-a-drag',
      items: 'tr',
      axis: 'y',
      tolerance: 'pointer',
      start: function (event, ui) {
        ui.placeholder.html(ui.item.html()); // just to prevent table cells resize
        ui.placeholder.find('td').css({ opacity: 0 });
        ui.placeholder.css({ visibility: 'visible' });
      },
      stop: function (e, ui) {
        $('#rmpt-questions-list').removeAttr('style');
      },
      beforeStop(e, ui) {
        ui.item.find('.rmpt-q-form-a-correct').prop('checked', ui.helper.find('.rmpt-q-form-a-correct').prop('checked'));
      },
      helper: function (e, tr) {
        $('#rmpt-questions-list').css({position: 'initial'});

        var cl = tr.clone();
        cl.removeAttr('id');
        cl.removeAttr('class');
        cl.addClass('rmpt-hover');
        cl.height(tr.outerHeight());
        cl.width(tr.outerWidth() + 1);
        cl.css({padding: 0});

        var $originals = tr.children();
        cl.children().each(function (index) {
          var it = $originals.eq(index);
          $(this).width(it.outerWidth());
        });

        cl.find('.rmpt-q-form-a-correct').attr('name', cl.find('.rmpt-q-form-a-correct').attr('name') + '_');
        return cl;
      }
    });
  };


  my.add_question_form = function(id, html) {
    $('#rmpt-errorExplanation').remove();
    $('.rmpt-q-form-cancel').trigger('click');
    $('#rmpt-questions-list').find('.nodata').addClass('I');
    var $form_container = $('#rmpt-questions-list').find('table').removeClass('I').addClass('rmpt-q-form-edit').find('tbody');

    if (id) {
      $('#rmpt-q-' + id).addClass('I').before(html);
    } else {
      $form_container.append(html);
      $('.rmpt-q-add').addClass('disabled');
    }


    $('.rmpt-q-form').effect('highlight');

    my.make_answers_sortable($('.rmpt-q-form-answers-container'));
    $form_container.find('textarea:visible').focus();
  };
  my.prepare_question_form = function(id) {
    $('#rmpt-errorExplanation').remove();
    var $form_container = $('#rmpt-q-' + id + '-new, #rmpt-q-' + id + '-edit');
    var $form = $form_container.find('form');

    var fields = [],
        $f = null;
    $form_container.find('textarea, select, input').each(function() {
      var $this = $(this);
      if ($this.closest('.rmpt-q-submit-form').length > 0) {
        return;
      }
      var vl = $(this).val();
      if (this.tagName == 'INPUT' && ($this.attr('type') == 'checkbox' || $this.attr('type') == 'radio') && !$this.prop('checked')) {
        vl = 'false';
      }
      $f = $('<input type="hidden" name="' + $this.attr('name') + '">');
      $f.val(vl);
      fields.push($f);
    });

    $form.find('.rmpt-q-form-field').remove();
    $form.append($('<div class="rmpt-q-form-field"></div>').append(fields));
  };
  my.send_question_form = function(id, url, before_ajax, success_callback, always_callback) {
    my.prepare_question_form(id);
    var $form = $('#rmpt-q-' + id + '-new, #rmpt-q-' + id + '-edit').find('form');

    if (before_ajax) {
      before_ajax.call(this);
    }
    if (!url) {
      url = $form.attr('action');
    }
    $.ajax({
      method: 'POST',
      url: url,
      data: $form.serialize()
    }).always(function() {
      if (always_callback) {
        always_callback.call(this);
      }
    }).done(function(data) {
      if (success_callback) {
        success_callback.call(this, data);
      }
    });
  };
  my.remove_question_form = function(id) {
    $('#rmpt-errorExplanation').remove();
    $('.rmpt-q-form').remove();
    $('.rmpt-q-add').removeClass('disabled');
    if (id) {
      $('#rmpt-q-' + id).removeClass('I');
    }
    var $q_container = $('#rmpt-questions-list');
    $q_container.find('table.rmpt-q-form-edit').removeClass('rmpt-q-form-edit');
    if ($q_container.find('table tbody tr').length == 0) {
      $q_container.find('.nodata').removeClass('I');
      $q_container.find('table').addClass('I');
    }
  };
  my.show_question_errors = function(errors) {
    $('#rmpt-errorExplanation').remove();

    if (!errors) {
      return;
    }
    var html = '<tr id="rmpt-errorExplanation"><td colspan="7"><ul>';
    for (var sch = 0, l = errors.length; sch < l; sch ++) {
      html += '<li>' + errors[sch] + '</li>';
    }
    html += '</ul></td></tr>';
    $('.rmpt-q-form').before(html);
  };
  my.show_question_line = function(data) {
    $('#rmpt-questions-list').find('.nodata').addClass('I');
    $('#rmpt-questions-list').find('table').removeClass('I');

    var stat = "&times;";
    if (data.count_touch) {
      var percent = (data.correct_count  / data.count_touch) * 100;
      stat = `${RMPlus.Utils.number_format(percent)}% (${data.correct_count || 0}/${data.count_touch}) `;
      stat += `<a class="rm-icon no_line fa-recycle" data-confirm="${data.confirm_text}" title="${data.title_stat_text}" data-remote="true" rel="nofollow" data-method="post" href="${RMPlus.Utils.relative_url_root}/rmpt_questions/${data.id}/clear_statistic"><span></span></a>`
    }
    var time_stat = "&times;";
    if (data.time_touch && data.count_touch) {
      var time_in_sec = data.time_touch / data.count_touch;
      time_stat = RMPlus.Utils.seconds_to_string(time_in_sec, { formated_time: true });
    }

    $('#rmpt-q-' + data.id).remove();
    RMPlus.TR.show_question_errors(null);
    var html = '<tr id="rmpt-q-' + data.id + '">';
    html += '<td class="rmpt-q-drag"><span>≡</span></td>';
    html += '<td><span>' + data.text_inline + '</span></td>';
    html += '<td><span>' + data.correct_answers.join(', ') + '</span></td>';
    html += '<td><span class="rm-icon ' + (data.randomize ? 'fa-check-square-o' : 'fa-square-o') + '"></span></td>';
    html += `<td class="rmpt_stat"><span>${stat}</span></td>`;
    html += `<td class="rmpt_stat">${time_stat}</td>`;
    html += '<td class="acl-table-buttons"><a href="' + RMPlus.Utils.relative_url_root + '/rmpt_questions/' + data.id + '/edit" class="in_link no_line rm-icon fa-pencil show_loader" data-remote="true">' + data.edit_label + '</a> ' +
                '<a href="' + RMPlus.Utils.relative_url_root + '/rmpt_questions/' + data.id + '" class="in_link no_line rm-icon fa-trash show_loader" data-remote="true" data-method="delete" data-confirm="' + data.del_message + '">' + data.del_label + '</a>' +
            '</td>';
    html += '</tr>';
    $('.rmpt-q-form').replaceWith(html);
    $('.rmpt-q-add').removeClass('disabled');
    $('#rmpt-q-' + data.id).effect('highlight');

    if ($('#rmpt-questions-list').find('table tr').length > 5) {
      $('.acl-btn-flat-delimiter:last').removeClass('I');
    }

    $('#rmpt-questions-list').find('table.rmpt-q-form-edit').removeClass('rmpt-q-form-edit');
  };
  my.remove_question_line = function(id, errors) {
    if (errors) {
      RMPlus.TR.show_question_errors(errors);
    } else {
      RMPlus.TR.show_question_errors(null);
      $('#rmpt-q-' + id).remove();
      if (!my.questions_total_count) {
        my.questions_total_count = 1;
      }
      my.questions_total_count--;
      if (my.questions_total_count < 0) {
        my.questions_total_count = 0;
      }

      var $container = $('#rmpt-questions-list');

      if (my.questions_total_count == 0) {
        $container.find('.nodata').removeClass('I');
        $container.find('table').addClass('I');
      }

      if (my.questions_total_count <= 6) {
        $container.closest('.tab-content').find('.acl-btn-flat-delimiter:last').addClass('I');
      }
    }
  };

  my.apply_autocomplete_groupsets = function($groupset) {
    var searcher = function () {
      var params = {};
      params.q = $.trim($groupset.val());

      var was = $groupset.attr('data-was');
      if ((was && was === params.q) || (!was && !params.q)) {
        return;
      }
      $groupset.attr('data-was', params.q);

      RMPlus.LDAP.GS.autocomplete_searcher($groupset, '/rmpt_tests/participants/autocomplete', params, function(data) {
        return !RMPlus.LDAP.GS.data.groupsets[data[1]];
      });

    };

    if (my.timer) {
      clearTimeout(my.timer);
    }

    my.timer = setTimeout(searcher, 300);
  };


  my.add_category_form = function(id, parent_id) {
    my.remove_category_form();
    var $list = $('#rmpt-categories-list');
    $list.find('.nodata').addClass('I');
    $list.find('.rmpt-c-container').removeClass('I');
    $list.addClass('rmpt-c-edit-mode').find('.rmpt-c-node').removeClass('rmpt-c-edit');

    var $form = $('<div class="rmpt-c-form">' + my.category_form + '</div>');
    var $name_field = $form.find('.rmpt-c-field-name');
    var $container;

    if (id) {
      $container = $('#rmpt-c-' + id);
      $container.addClass('rmpt-c-edit');
      $name_field.val($container.find('.rmpt-c-action-edit').attr('data-value'));
      $container.find('rmpt-c-form').remove();

      $form.find('form').attr('action', RMPlus.Utils.relative_url_root + '/rmpt_categories/' + id);
      $form.find('form').prepend('<input type="hidden" name="_method" value="patch">');
    } else {
      var $li = $('<li class="rmpt-c-new-item"></li>');
      $container = $('<div class="rmpt-c-node rmpt-c-edit"></div>');
      $li.append($container);
      if (parent_id) {
        $form.find('form').prepend('<input type="hidden" name="rmpt_category[parent_id]" value="' + parent_id + '">');
        var $p = $('#rmpt-c-' + parent_id).closest('li');
        if ($p.find('ul').length > 0) {
          $p.find('ul:first').append($li);
        } else {
          var $ul = $('<ul></ul>');
          $ul.append($li);
          $p.append($ul);
        }
      } else {
        $list.find('ul:first').append($li);
      }
    }
    $container.append($form);
    $name_field.filter(':visible').focus();
  };
  my.update_category_line = function(id, name, parent_id, left_id, right_id) {
    var $node = $('#rmpt-c-' + id);
    $node.find('.rmpt-c-action-edit').attr('data-value', name).html('<span>' + name + '</span>');

    my.move_category_node($node.closest('li'), { left_id: left_id, right_id: right_id, parent_id: parent_id });

    my.remove_category_form();
    $('html').animate({ scrollTop: $node.closest('li').offset().top - 30 }, 200, null, function() { $node.effect('highlight') });
  };
  my.create_category_line = function(id, name, parent_id, left_id, right_id) {
    var $container = $('<div id="rmpt-c-' + id + '" class="rmpt-c-node">' + $('#rmpt-c-item-pattern').html() + '</div>');
    $container.find('.rmpt-c-action-edit').html('<span>' + name + '</span>').attr('data-id', id).attr('data-value', name);
    $container.find('.rmpt-c-action-add-child').attr('href', RMPlus.Utils.relative_url_root + '/rmpt_categories/new?parent_id=' + id);
    $container.find('.rmpt-c-action-del').attr('href', RMPlus.Utils.relative_url_root + '/rmpt_categories/' + id);
    var $li = $('<li id="acl-tree-node-' + id + '"></li>');
    $li.append($container);

    my.move_category_node($li, { left_id: left_id, right_id: right_id, parent_id: parent_id });
    my.remove_category_form();
    my.make_categories_movable($li, $container);

    $('html').animate({ scrollTop: $li.offset().top - 30 }, 200, null, function() { $li.effect('highlight') });
  };
  my.remove_category_form = function() {
    $('.rmpt-c-form').remove();
    $('.rmpt-c-node').removeClass('rmpt-c-edit');
    $('.rmpt-categories-tree').removeClass('rmpt-c-edit-mode');
    $('.rmpt-c-new-item').remove();
    var $c_container = $('#rmpt-categories-list');
    $c_container.find('.rmpt-c-container > ul ul:empty').remove();

    if ($c_container.find('li').length === 0) {
      $c_container.find('.nodata').removeClass('I');
      $c_container.find('.rmpt-c-container').addClass('I');
    }
  };
  my.remove_category_line = function(id) {
    var $li = $('#acl-tree-node-' + id);
    $li.effect('highlight', 500, function() {
      $li.remove();
      my.remove_category_form();
    });
  };

  my.make_categories_movable = function ($drag, $drop) {
    ($drag || $("#rmpt-categories-list li")).draggable({
      cursor: 'move',
      handle: '.rmpt-c-drag',
      containment: 'document',
      revert: 'invalid',
      zIndex: 9900,
      start: function(event, ui) {
        $(event.target).addClass('rmpt-c-original-drag');
        $('#rmpt-categories-list').addClass('rmpt-c-dragging');
      },
      stop: function(event, ui) {
        $(event.target).removeClass('rmpt-c-original-drag');
        $('#rmpt-categories-list').removeClass('rmpt-c-dragging');
      },
      helper: function (e) {
        var $c = $(e.target).closest('li').clone();
        $c.addClass('rmpt-c-dragging');
        $c.removeAttr('id');
        $c.find('.rmpt-c-node').removeAttr('id');
        $c.find('div.rmpt-c-node-btns').remove();
        return $c;
      }
    });

    ($drop || $(".rmpt-c-node")).droppable({
      tolerance: "pointer",
      over: function(event, ui) {
        $(event.target).addClass('rmpt-c-droppable');
      },
      out: function(event, ui) {
        $(event.target).removeClass('rmpt-c-droppable');
      },
      drop: function(event, ui) {
        $(".rmpt-c-node").removeClass('rmpt-c-droppable');
        $('#rmpt-categories-list').removeClass('rmpt-c-dragging').find('li').removeClass('rmpt-c-original-drag');

        var $drop = $(event.target);
        var $drag = ui.draggable;
        my.move_category($drag, $drop);
      }
    });
  };

  my.move_category = function ($source, $drop) {
    $source.removeClass('rmpt-c-original-drag').css({ top: 0, left: 0 });

    var $target_elem = $drop.find('.rmpt-c-action-edit');
    var $source_elem = $source.find('.rmpt-c-node:first .rmpt-c-action-edit');

    var target_parent_id = $target_elem.attr('data-id') || '';
    var source_id = $source_elem.attr('data-id');
    var source_parent_id = $source.parent().closest('li').find('.rmpt-c-node:first .rmpt-c-action-edit').attr('data-id') || '';

    if (target_parent_id === source_parent_id) {
      return;
    }

    $source.addClass('rmpt-c-moving');

    if (!confirm(my.lbl_moving_category + ' "' + $source_elem.attr('data-value') + '" ' + my.lbl_moving_to_category + ' "' + ($target_elem.attr('data-value') || my.lbl_root) + '" ?' )) {
      $source.removeClass('rmpt-c-moving');
      return;
    }

    $('#rmpt-categories-list').prepend("<div class='acl-fullscreen-loading-mask'><div class='form_loader big_loader'></div></div>");
    $.ajax({
      method: 'POST',
      url: RMPlus.Utils.relative_url_root + '/rmpt_categories/' + source_id + '/move/ ' + target_parent_id
    }).done(function (data) {
      if (data) {
        if (data.errors) {
          my.show_category_errors(data.errors);
        } else {
          my.move_category_node($source, data);
        }
        $source.removeClass('rmpt-c-moving');
      }
    }).always(function () {
      $('.acl-fullscreen-loading-mask').remove();
    });
  };

  my.move_category_node = function($source, data) {
    if (data.left_id) {
      $('#rmpt-c-' + data.left_id).closest('li').after($source);
    } else if (data.right_id) {
      $('#rmpt-c-' + data.right_id).closest('li').before($source);
    } else if (data.parent_id) {
      var $li = $('#acl-tree-node-' + data.parent_id).closest('li');
      var $ul = $li.find('ul:first');
      if ($ul.length === 0) {
        $ul = $('<ul></ul>');
        $li.append($ul);
      }
      $ul.append($source);
    } else {
      $('#rmpt-categories-list').find('ul:first').append($source);
    }

    $('#rmpt-categories-list').find('.rmpt-c-container > ul ul:empty').remove();
  };


  my.show_category_errors = function(html) {
    var $modal = $('#rmpt-c-errors');
    if ($modal.length === 0) {
      $modal = $('<div id="rmpt-c-errors" class="modal fade" aria-hidden="true" data-width="600px" style="z-index: 1060;"></div>');
    }
    $modal.html('<div class="modal-body">' + html + '</div><div class="modal-footer"><button type="button" class="acl-btn-flat rm-icon fa-sign-out" data-dismiss="modal" aria-hidden="true"><span>' + my.lbl_close + '</span></button></div>');
    $(document.body).prepend($modal);
    $modal.modal('show');
    $('.acl-fullscreen-loading-mask').remove();
  };

  my.make_select2_ajaxable = function () {
    $('.rmpt-select2-ajaxable').not('.select2-hidden-accessible').each(function () {
      var $this = $(this);
      var multiple = $this.prop('multiple');
      var url = $this.attr('data-ajax-url');

      $this.select2({
        dataAdapter: $.fn.select2.amd.require('select2/data/ajax-adapter-with-defaults'),
        dropdownAdapter: $.fn.select2.amd.require('select2/dropdown/instructions'),
        minimumInputLength: 3,
        selectOnClose: false,
        multiple: multiple,
        escapeMarkup: function (m) { return m; },
        width: '400px',
        placeholder: ' ',
        allowClear: true,
        ajax: {
          url: url,
          dataType: 'json',
          delay: 200,
          cache: true,
          data: function (params) {
            return { q: params.term };
          },
          processResults: function(data, params) {
            return { results: data };
          },
          templateSelection: function(state) { return state.text.substring(state.text.indexOf("┕")); }
        }
      });
    });
  };

  return my;
})(RMPlus.TR || {});

$(document).ready(function() {

  $(document.body).on('change', '#rmpt_test_can_resubmit', function () {
    $('#rmpt_test_show_q_result').prop('checked', false).prop('disabled', this.checked);
  });

  $(document.body).on('click', '.rmpt-new-test', function () {
    var cat_id = $('.acl-tree-list li a.selected').attr('data-id');
    if (cat_id) {
      window.location = this.href + '?rmpt[category_id]=' + cat_id;
      return false;
    }
  });


  $(document.body).on('change', '.rmpt-switcher', function() {
    if (!this.checked) {
      return;
    }
    var $this = $(this);
    var class_name = 'rmpt-' + $this.attr('name').replace('_', '-');

    $this.closest('.rmpt-switcher-container').find('.' + class_name).addClass('I').find('input').prop('disabled', true);
    $this.closest('.rmpt-switcher-container').find('.' + class_name + '-' + $(this).val()).removeClass('I').find('input').prop('disabled', false);
  });

  $(document.body).on('change', '.rmpt-disabler', function() {
    var $this = $(this);
    var name = 'rmpt_test[' + $this.attr('name') + ']';
    $this.closest('.rmpt-disabler-container').find('[name^="' + name + '"]').prop('disabled', this.checked);
  });

  // $(document.body).on('change input keyup', '#rmpt_test_q_count', function() {
  //   if (RMPlus.TR.questions_total_count == 0) {
  //     this.value = '';
  //     $(this).prop('disabled', true);
  //     $('#q_count').prop('checked', true);
  //   } else if (RMPlus.TR.questions_total_count && this.value > RMPlus.TR.questions_total_count) {
  //     this.value = RMPlus.TR.questions_total_count;
  //   }
  // });

  $(document.body).on('keydown keyup', '.rmpt-q-form-answer', function(e) {
    if (e.keyCode == 13) {
      RMPlus.TR.add_answer_option($(this));

      e.stopPropagation();
      e.preventDefault();
      return false;
    }
  });

  $(document.body).on('click', '.rmpt-q-form-add-answer', function() {
    RMPlus.TR.add_answer_option($(this).closest('.rmpt-q-form').find('.rmpt-q-form-answer'));
    return false;
  });

  $(document.body).on('click', '.rmpt-q-form-remove-answer', function() {
    $(this).closest('tr').remove();
    return false;
  });

  $(document.body).on('change', '.rmpt-q-form-a-answer', function() {
    if (!$.trim($(this).val())) {
      $(this).closest('tr').remove();
    }
  });

  $(document.body).on('keydown keyup', '.rmpt-q-form-a-answer', function(e) {
    if (e.keyCode == 13) {
      if (e.type == 'keyup') {
        var $next = $(this).closest('tr').next('tr').find('.rmpt-q-form-a-answer');
        if ($next.length == 1) {
          $next.focus();
        }
      }
      e.stopPropagation();
      e.preventDefault();
      return false;
    }
  });

  $(document.body).on('change', '.rmpt-q-form-type', function() {
    RMPlus.TR.change_answer_options_type($(this));
  });

  $(document.body).on('click', '.rmpt-q-form-label', function() {
    $(this).find('input[type=checkbox]').trigger('click');
  });
  $(document.body).on('click', '.rmpt-q-form-label *', function(e) {
    e.stopPropagation();
  });

  $(document.body).on('click', '.rmpt-q-form-submit', function() {
    var $this = $(this);
    var id = $this.attr('data-id');
    RMPlus.TR.send_question_form(id, null, function() {
      $(document.body).data('ajax_emmiter', $this);
      $this.closest('.rmpt-q-form').addClass('rmpt-submitting');
    },
    function(data) {
      if (!data) {
        return;
      }
      if (data.errors) {
        RMPlus.TR.show_question_errors(data.errors);
      } else {
        RMPlus.TR.questions_total_count = (RMPlus.TR.questions_total_count || 0) + 1;
        RMPlus.TR.show_question_line(data);
      }
    },
    function() {
      $this.closest('.rmpt-q-form').removeClass('rmpt-submitting');
    }
    );
  });
  $(document.body).on('click', '.rmpt-q-form-cancel', function() {
    var $this = $(this);
    var id = $this.attr('data-id');
    RMPlus.TR.remove_question_form(id);
  });

  $(document.body).on('click', '.rmpt-q-form-edit tr.rmpt-q-form .attachments .icon-attachment', function() {
    var $question = $(this).closest('.rmpt-q-form').find('.rmpt-q-form-question');

    if (RMPlus.Usability) {
      RMPlus.Usability.pasteImageName($question.get(0), $(this).text())
    } else {
      $question.val($question.val() + ' !' + $(this).text() + '!');
    }
    return false;
  });

  $(document.body).on('click', '.rmpt-q-form-preview', function() {
    var $this = $(this);
    var id = $this.attr('data-id');
    var $modal;
    RMPlus.TR.send_question_form(id, $this.attr('data-url'), function() {
      $modal = RMPlus.Utils.create_bootstrap_modal($this, true);
      $modal.modal('show');
    },
    function(data) {
      $modal.html(data);
    });

    return false;
  });

  $(document.body).on('click', '.rmpt-q-answer-text', function () {
    if ($(this).closest('.rmpt-question-body').hasClass('rmpt-q-mode-test')) {
      $(this).closest('li').find('.rmpt-q-answer-input').trigger('change');
    }
  });

  $(document.body).on('click', '.rmpt-q-add', function() {
    RMPlus.TR.add_question_form(null, RMPlus.TR.question_form);
  });

  $('.rmpt-disabler, .rmpt-switcher').trigger('change');

  $(document.body).on('click', '.rmpt-patterns-preview', function() {
    var $this = $(this);
    var text = $this.closest('td').find('textarea').val();
    var $modal = RMPlus.Utils.create_bootstrap_modal($this, true);
    $modal.modal('show');

    $.ajax({
      method: 'POST',
      url: this.href,
      data: { text: text }
    }).done(function (data) {
      $modal.html(data);
    }).fail(function () {
      $modal.html('');
    });

    return false;
  });



  $(document.body).on('keyup change input', '.ldap-gs-groupsets-filter', function() {
    RMPlus.TR.apply_autocomplete_groupsets($(this));
  });


  $(document.body).on('click', '.rmpt-c-add', function() {
    RMPlus.TR.add_category_form();
    return false;
  });
  $(document.body).on('click', '.rmpt-c-action-edit', function() {
    RMPlus.TR.add_category_form(this.getAttribute('data-id'));
    return false;
  });

  $(document.body).on('submit', '.rmpt-c-form form', function() {
    $(this).closest('.rmpt-c-form').append('<div class="acl-fullscreen-loading-mask"><div class="form_loader loader"></div></div>');
  });

  $(document.body).on('click', '.rmpt-c-action-cancel', function () {
    RMPlus.TR.remove_category_form();
  });

  $(document.body).on('click', '.rmpt-c-action-add-child', function () {
    RMPlus.TR.add_category_form(null, $(this).closest('.rmpt-c-node').find('.rmpt-c-action-edit').attr('data-id'));
    return false;
  });

  $(document.body).on('submit', '#rmpt-add-extra-attempt', function () {
    var $form = $(this);

    $(document.body).data('ajax_emmiter', $form.find('[type=submit]'));
    $.ajax({
      method: 'POST',
      url: this.action,
      data: $form.serialize()
    }).done(function(data) {
      if ($form.find('select').length === 0) {
        var test_id = $form.attr('data-test-id');
        var user_id = $form.find('[name="user_id"]').val();
        var $td = $('#rmpt-t-' + test_id + '-' + user_id).find('.rmpt-ut-f-attempts');
        if ($td.find('.rmpt-ut-extra-attempts').length === 0) {
          if (data.attempts) {
            $td.append('<span class="rmpt-ut-extra-attempts"> + ' + data.attempts + '</span>');
            if (data.has_attempts) {
              $td.find('.rmpt-ut-extra-attempt').remove();
              $td.closest('tr').removeClass('rmpt-rep-attempts-expired');
            } else {
              $td.append(' ');
              $td.append($td.find('.rmpt-ut-extra-attempt').remove());
            }
          }
        } else {
          if (data.attempts) {
            $td.find('.rmpt-ut-extra-attempts').html(' + ' + data.attempts.toString());
            if (data.has_attempts) {
              $td.find('.rmpt-ut-extra-attempt').remove();
              $td.closest('tr').removeClass('rmpt-rep-attempts-expired');
            } else {
              $td.append(' ');
              $td.append($td.find('.rmpt-ut-extra-attempt').remove());
            }
          } else {
            $td.find('.rmpt-ut-extra-attempts').remove();
          }
        }
      }
      $('.modal').modal('hide');
    });
    return false;
  });

  $(document.body).on('click', '.rmpt-t-remove, .rmpt-t-resort', function() {
    var $this = $(this);
    if ($this.attr('data-confirm') && !confirm($this.attr('data-confirm'))) {
      return false;
    }

    $('.acl-split-container .acl-fullscreen-loading-mask').remove();
    $('.acl-split-container').prepend("<div class='acl-fullscreen-loading-mask'><div class='form_loader big_loader'></div></div>");

    $.ajax({
      method: $this.attr('data-type') || 'GET',
      url: this.href,
      context: this
    }).done(function(data) {
      $('.acl-split-right').html('').append(data);
    }).always(function() {
      $('.acl-fullscreen-loading-mask').remove();
    });
    return false;
  });

  $(document.body).on('click', '.show-q-result', function() {
    var num = $(this).attr('data-num');
    $('.rmpt-utp-result-container').html('<div class="big_loader form_loader"></div>');
    $.ajax({
      method: 'GET',
      url: RMPlus.Utils.relative_url_root + '/rmpt/' + RMPlus.TR.ajax_test_id + '/result_answers',
      data: { num: num },
    }).done(function(data){
      $('.rmpt-utp-result-container').html(data);
    }).always(function() {
      $('.big_loader .form_loader').remove();
    });

    $('.rmpt-utp-selectable').removeClass('rmpt-utp-current');
    $(`#rmpt-utp-q-${num}`).toggleClass('rmpt-utp-current');
  });
});