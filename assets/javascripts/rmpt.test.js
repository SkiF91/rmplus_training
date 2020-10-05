RMPlus.TR = RMPlus.TR || {};
RMPlus.TR.Test = (function(my) {
  my = my || {};

  my.current_test_id = null;
  my.current_q_num = 1;
  my.q_timelimit = false;

  my.processing_url = function() {
    return RMPlus.Utils.relative_url_root + '/rmpt/' + my.current_test_id + '/processing';
  };

  my.apply_timer = function () {
    var $sec = $('#rmpt-utp-timelimit').find('.rmpt-utp-timelimit-sec');

    if ($sec.length === 0) {
      return;
    }

    var value = parseInt($sec.attr('data-sec'));

    my.timer = RMPlus.Utils.set_timer(value, {
      scope: $sec,
      tick: function(seconds) {
        this.html(RMPlus.Utils.seconds_to_string(seconds, { day_include: true, truncate_zeros: true, days_lbl: 'д.' }));
      },
      complete: function() {
        this.html(RMPlus.Utils.seconds_to_string(0, { day_include: true, truncate_zeros: true, days_lbl: 'д.' }));

        var data = { q_num: my.current_q_num };
        if (my.timelimit_type === 'total') {
          data.complete = true;
        } else {
          data.rmpt = data.rmpt || {};
          data.rmpt.timeout = true;
        }
        my.process_test(my.processing_url(), 'POST', data);
      }
    });
  };

  my.process_test = function (url, method, data) {
    var $utp_container = $('#rmpt-utp-question-container');
    $utp_container.find('.acl-fullscreen-loading-mask').remove();
    $utp_container.prepend("<div class='acl-fullscreen-loading-mask'><div class='form_loader big_loader'></div></div>");

    var skip_mask_deleting = false;
    $.ajax({
      method: method,
      url: url,
      data: data
    }).done(function (data) {
      var $err = $('#rmpt-utp-errors').html('');
      $('#rmpt-utp-question').find('.rmpt-utp-action-submit').removeClass('I');

      if (my.timer) {
        clearInterval(my.timer);
      }

      if (data.redirect_to) {
        skip_mask_deleting = true;
        window.location = data.redirect_to;
      } else if (data.errors) {
        if (!Array.isArray(data.errors)) {
          data.errors = [data.errors];
        }
        $err.html("<div id='errorExplanation'><ul><li>" + data.errors.join('</li><li>') + '</li></ul>');
        $('html').animate({ scrollTop: $err.offset().top - 30 }, 200, null, function() { $err.effect('highlight') });

        if (data.next_num) {
          $('#rmpt-utp-q-' + data.next_num).addClass('rmpt-utp-selectable');
          $('#rmpt-utp-question').find('.rmpt-utp-action-skip').removeClass('I');
          $('#rmpt-utp-question').find('.rmpt-utp-action-submit').addClass('I');
        }
      } else if (data.status) {
        // 404, 403
      } else {
        my.current_q_num = data.question.num;

        var $t = $('#rmpt-utp-timelimit');
        if (data.timelimit_left || data.timelimit_left === 0) {
          $t.find('.rmpt-utp-timelimit-sec').attr('data-sec', data.timelimit_left);
          my.apply_timer();
        } else {
          $t.remove();
        }

        var $p = $('#rmpt-utp-progress');
        $p.find('.rmpt-utp-count-completed').html(data.progress);
        $p.find('.rmpt-utp-progressbar-value').css({ width: (data.total <= 0 ? '100' : (data.progress / data.total * 100)) + '%' });

        var $s = $('#rmpt-utp-sheet');

        $s.find('li').removeClass('rmpt-utp-current').removeClass('rmpt-utp-result-wrong').removeClass('rmpt-utp-result-correct').removeClass('rmpt-utp-selectable').removeClass('rmpt-utp-completed');
        $s.find('#rmpt-utp-q-' + data.question.num).addClass('rmpt-utp-current');

        if (data.hasOwnProperty('questions')) {
          var q, has_selectable = false;
          for (var sch = 0, l = data.questions.length; sch < l; sch ++) {
            q = data.questions[sch];

            if (q.correct === true || q.correct === false) {
              $s.find('#rmpt-utp-q-' + q.num).addClass('rmpt-utp-result-' + (q.correct ? 'correct' : 'wrong'));
            }

            if (q.selectable) {
              if (!q.completed && q.num !== data.question.num) {
                has_selectable = true;
              }
              $s.find('#rmpt-utp-q-' + q.num).addClass('rmpt-utp-selectable');
            }

            if (q.completed || q.expired) {
              $s.find('#rmpt-utp-q-' + q.num).addClass('rmpt-utp-completed');
            }
          }

          if (has_selectable && data.total - data.progress > 1) {
            $('.rmpt-utp-action-skip').removeClass('I');
          } else {
            $('.rmpt-utp-action-skip').addClass('I');
          }
        }

        var $q = $('#rmpt-utp-question');
        $q.find('.rmpt-question-header-num').html(data.question.num);
        $q.find('#rmpt-utp-q-num').val(data.question.num);
        $q.find('.rmpt-q-text').html(data.question.text);

        $q.find('.rmpt-q-answer-options .rmpt-block-header').attr('data-header', data.question.qtype_text);
        var $a = $q.find('.rmpt-q-answer-options ul');

        var a_html = '',
            a;
        for (var sch = 0, l = data.question.answers.length; sch < l; sch ++) {
          a = data.question.answers[sch];
          a_html += '<li>';
          a_html += '<div class="rmpt-q-answer-field">';
          if (a.hasOwnProperty('correct')) {
            a_html += '<span class="rmpt-q-answer-result' + (a.correct ? ' rm-icon rm-nom ' + (a.selected ? 'fa-check-circle-o' : 'fa-check') : '') + '"></span>';
          }
          a_html += '<input type="' + (data.question.qtype_single ? 'radio' : 'checkbox') + '" name="rmpt[answer][]" class="rmpt-q-answer-input" value="' + a.num + '"' + (a.selected ? ' checked="checked"' : '') + '>';
          a_html += '</div>';
          a_html += '<div class="rmpt-q-answer-text">' + a.text + '</div>';
          a_html += '</li>';
        }
        $a.html(a_html);
      }
    }).fail(function (data) {
    //  404 403 etc
    }).always(function () {
      if (!skip_mask_deleting) {
        $('#rmpt-utp-question-container').find('.acl-fullscreen-loading-mask').remove();
      }
    });
  };

  return my;
})(RMPlus.TR.Test);

$(document).ready(function () {
  $(document.body).on('click', '.rmpt-q-answer-options li', function(e) {
    if ($(e.target).is('input')) {
      return;
    }
    e.stopPropagation();
    $(this).find('input').trigger('click');
    return false;
  });

  $(document.body).on('click', '.rmpt-utp-action-submit', function() {
    var data = $('#rmpt-utp-question').serializeHash();

    RMPlus.TR.Test.process_test(RMPlus.TR.Test.processing_url(), 'POST', data);
    return;
  });

  $(document.body).on('click', '.rmpt-utp-action-skip', function() {
    var $target = $('#rmpt-utp-sheet').find('.rmpt-utp-current').nextAll('.rmpt-utp-selectable:not(.rmpt-utp-completed):first');
    if ($target.length === 0) {
      $target = $('#rmpt-utp-sheet').find('.rmpt-utp-selectable:not(.rmpt-utp-completed):first');
    }

    var num = parseInt($target.attr('data-num') || '');

    if (!num || isNaN(num) || num < 0) {
      $(this).addClass('I');
    } else {
      RMPlus.TR.Test.process_test(RMPlus.TR.Test.processing_url(), 'GET', { q_num: num });
    }
    return false;
  });

  $(document.body).on('click', '#rmpt-utp-sheet li', function () {
    var $this = $(this);
    var num = parseInt($this.attr('data-num') || '');

    if (!num || isNaN(num) || num < 0) {
      $(this).removeClass('rmpt-utp-selectable');
    } else {
      RMPlus.TR.Test.process_test(RMPlus.TR.Test.processing_url(), 'GET', { q_num: num });
    }
    return false;
  });

  $(document.body).on('click', '.rmpt-utp-action-complete', function() {
    RMPlus.TR.Test.process_test(RMPlus.TR.Test.processing_url(), 'GET', { complete: true });
    return false;
  });
});