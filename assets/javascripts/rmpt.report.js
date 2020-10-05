$(document).ready(function () {
  $(document.body).on('click', 'a.rmpt-rep-reload', function() {
    $(this).trigger('submit');
    return false;
  });
  $(document.body).on('submit', '.rmpt-rep-reload', function() {
    this.removeAttribute('data-submitted');
    var url, data, page, per_page;

    page = $(this).attr('data-page');
    per_page = $(this).attr('data-per-page');

    $('#page').val(page ? page : 1);
    if (per_page) {
      $('#per_page').val(per_page);
    }

    $(this).find('#export').val('0');
    if (this.tagName === 'FORM') {
      if (this.getAttribute('data-sync')) {
        this.removeAttribute('data-sync');
        $(this).find('#export').val('1');
        return;
      }
      url = this.action;
      data = $(this).serialize();
    } else {
      url = this.action;
      data = $('form.rmpt-rep-reload').serialize();
    }

    $('.acl-fullscreen-loading-mask').remove();
    $('#rmpt-report-data').prepend('<div class="acl-fullscreen-loading-mask"><div class="form_loader big_loader"></div></div>');
    $.ajax({
      method: 'POST',
      url: url,
      data: data
    }).done(function (data) {
      $('#rmpt-report-data').html(data);
      $('html').animate({ scrollTop: 0 }, 200);
    }).always(function () {
      history.replaceState({},'', '?' + data.slice(data.indexOf('per_page'), data.length ));

      $('.acl-fullscreen-loading-mask').remove();
    });

    return false;
  });

  $(document.body).on('click', '.rmpt-rep-to-excel', function () {
    $(this).closest('form').attr('data-sync', 1);
  });
});

function getParameterByName(name, url) {
  if (!url) url = window.location.href;
  name = name.replace(/[\[\]]/g, '\\$&');
  var regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)'),
      results = regex.exec(url);
  if (!results) return null;
  if (!results[2]) return '';
  return decodeURIComponent(results[2].replace(/\+/g, ' '));
}