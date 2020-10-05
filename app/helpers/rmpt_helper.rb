module RmptHelper
  def rmpt_test_status(status)
    "<span class='rmpt-ut-status-#{status}'>#{l("label_rmpt_test_status_#{status}")}</span>".html_safe
  end

  def rmpt_render_test_line(test, attempts, options={})
    test_attempts = ''
    best_attempt = nil
    last_attempt = nil
    cnt = test.attributes['attempts_used'].to_i
    render_buttons = options[:render_buttons]
    render_categories = options[:render_categories]
    render_user = options[:render_user]
    child_css = options[:child_css]
    css = options[:css]

    (attempts || []).each_with_index do |ut, index|
      last_attempt = ut if last_attempt.blank?

      if best_attempt.blank? && ut.result_ratio == test.attributes['max_result_ratio']
        best_attempt = ut
      end

      if options[:is_report].present? && options[:is_report] || ut.present? && ut.has_access_result?(User.current)
        link_modal = link_to('<span></span>'.html_safe, { controller: :rmpt, action: :result_answers, id: ut.id, is_report: options[:is_report] }, class: 'acl_ajax_edit no_line rm-icon fa-file-text-o', remote: true, title: l(:text_rmpt_show_t_results))
      end

      test_attempts << "<tr class='#{child_css} acl-expander-data'>"
      test_attempts << "<td class='rmpt-ut-f-name' colspan='#{render_categories ? 2 : 1}'></td>"
      test_attempts << "<td class='rmpt-ut-f-attempts'><span class='rmpt-acl-expander-placeholder'></span>#{cnt - index} #{link_modal || ""}</td>"
      test_attempts << "<td class='rmpt-ut-f-status'>#{rmpt_test_status(ut.status)}</td>"
      test_attempts << "<td class='rmpt-ut-f-start_at'>#{ut.start_at.present? ? format_time(ut.start_at) : '&times;'}</td>"
      test_attempts << "<td class='rmpt-ut-f-time'>#{ut.end_at.present? ? Rmpt::Utils.convert_seconds_to_day_time_string((ut.end_at - ut.start_at).to_i, "<span class='acl-unit'>#{l(:label_rmpt_days_unit_short)}</span>") : '&times;'}</td>"
      test_attempts << "<td class='rmpt-ut-f-ratio'>#{ut.result_ratio.present? ? "#{rmp_number_text(ut.result_ratio)}<span class='acl-unit'>%</span> (#{ut.q_count_correct.to_i} / #{ut.q_count_total.to_i})" : '&times;'}</td>"
      test_attempts << "<td colspan='#{render_buttons ? 2 : 1}'></td>"
      test_attempts << '</tr>'
    end


    html = "<tbody class='acl-expander'><tr id='rmpt-t-#{test.id}-#{test.attributes['user_id']}' class='#{css}'>"

    if render_user
      html << "<td class='rmpt-ut-f-name'>#{link_to_user render_user}</td>"
    else
      html << "<td class='rmpt-ut-f-name'>#{test.name}</td>"
    end

    if render_categories
      html << "<td class='rmpt-ut-f-category'>#{test.attributes['cat_name'] || '&times;'}</td>"
    end
    html << '<td class="rmpt-ut-f-attempts">'
    if test.attributes['attempts_used'].to_i > 0
      html << '<span class="acl-expander-handler"></span>'
    end
    html << rmp_number_text(test.attributes['attempts_used']).to_s
    html << ' / '
    html << rmp_number_text(test.attempts, '∞').to_s
    if test.attempts.present? && test.attributes['extra_attempts'].to_i > 0
      html << "<span class='rmpt-ut-extra-attempts'> + #{test.attributes['extra_attempts'].to_i}</span>"
    end
    if test.attempts.present? && test.attributes['attempts_used'].to_i >= test.total_attempts && test.manageable?
      html << ' '
      html << link_to('', { controller: :rmpt_tests, action: :extra_attempt, id: test.id, user_id: test.attributes['user_id'] }, class: 'in_link no_line rm-icon rm-nom fa-gift acl_ajax_edit rmpt-ut-extra-attempt', title: l(:label_rmpt_extra_attempt_add), data: { width: '450px' })
    end
    html << '</td>'
    if best_attempt.present?
      html << "<td class='rmpt-ut-f-status'>#{rmpt_test_status(best_attempt.status)}</td>"
      html << "<td class='rmpt-ut-f-start_at'>#{best_attempt.start_at.present? ? format_time(best_attempt.start_at) : '&times;'}</td>"
      html << '<td class="rmpt-ut-f-time">'
      html << (best_attempt.end_at.present? ? Rmpt::Utils.convert_seconds_to_day_time_string((best_attempt.end_at - best_attempt.start_at).to_i, "<span class='acl-unit'>#{l(:label_rmpt_days_unit_short)}</span>") : '&times;')
      html << '</td>'
      html << '<td class="rmpt-ut-f-ratio">'
      if best_attempt.result_ratio.present?
        html << "#{rmp_number_text(best_attempt.result_ratio)}<span class='acl-unit'>%</span> (#{best_attempt.q_count_correct.to_i} / #{best_attempt.q_count_total.to_i})"
      else
        html << '&times;'
      end
      html << '</td>'
    else
      html << "<td class='rmpt-ut-f-status'>#{rmpt_test_status(RmptUserTest::STATUS_BLANK)}</td>"
      html << '<td class="rmpt-ut-f-start_at">&times;</td>'
      html << '<td class="rmpt-ut-f-time">&times;</td>'
      html << '<td class="rmpt-ut-f-ratio">&times;</td>'
    end
    html << "<td class='rmpt-ut-f-due'>#{test.attributes['due'].present? ? format_date(test.attributes['due']) : '∞'}</td>"

    if render_buttons
      html << '<td class="acl-table-buttons">'
      if last_attempt.present? && [RmptUserTest::STATUS_BLANK, RmptUserTest::STATUS_STARTED].include?(last_attempt.status)
        html << link_to("<span>#{l(:label_rmpt_user_test_action_continue)}</span>".html_safe, prepare_rmpt_path(test), class: 'no_line rm-icon fa-reply')
      elsif test.has_attempts?(User.current)
        if last_attempt.blank?
          html << link_to("<span>#{l(:label_rmpt_user_test_action_begin)}</span>".html_safe, prepare_rmpt_path(test), class: 'no_line rm-icon fa-play-circle-o')
        elsif test.can_retry?(last_attempt)
          html << link_to("<span>#{l(:label_rmpt_user_test_action_repeat)}</span>".html_safe, prepare_rmpt_path(test), class: 'no_line rm-icon fa-repeat')
        else
          html << l(:label_rmpt_retry_available_in)
          html << ' '
          html << Rmpt::Utils.convert_seconds_to_day_time_string(test.retry_time_left(last_attempt), "<span class='acl-unit'>#{l(:label_rmpt_days_unit_short)}</span>")
        end
      else
        html << '&times;'
      end
      html << '</td>'
    end

    html << '</tr>'

    html << test_attempts
    html << '</tbody>'
    html.html_safe
  end
end