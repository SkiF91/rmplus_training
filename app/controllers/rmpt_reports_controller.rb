class RmptReportsController < ApplicationController
  self.main_menu = false
  before_action :require_login
  before_action :authorized_globaly?

  helper :rmpt

  def report
    @group_by = params[:group_by].to_s
    @group_by = 'user' unless %w(user test).include?(@group_by)
    @page = params[:page].to_i
    @page = 1 if @page <= 0
    @limit = per_page_option.to_i
    @limit = 10 if @limit <= 0

    scope = RmptTest.manageable(User.current).enrolled_with_attempts_info

    @user_ids = Array.wrap(params[:user_ids]) - ['', nil]
    if @user_ids.present?
      scope = scope.where('u.id IN (?)', @user_ids.map(&:to_i))
    end
    @test_ids = Array.wrap(params[:test_ids]) - ['', nil]
    if @test_ids.present?
      scope = scope.where("#{RmptTest.table_name}.id IN (?)", Array.wrap(@test_ids).map(&:to_i))
    end
    @dep_ids = Array.wrap(params[:department_ids]) - ['', nil]
    if @dep_ids.present?
      scope = scope.where("u.user_department_id IN (?)", Array.wrap(@dep_ids).map(&:to_i))
    end

    @status_ids = Array.wrap(params[:status_ids]).map(&:to_i)
    if @status_ids.present?
      if @status_ids.include?(RmptUserTest::STATUS_FAILED)
        @status_ids << RmptUserTest::STATUS_TIMELIMIT_EXPIRED
      end

      if @status_ids.include?(RmptUserTest::STATUS_BLANK)
        scope = scope.where("min_status in (#{@status_ids.join(',')}) or min_status IS NULL")
      else
        scope = scope.where("min_status in (#{@status_ids.join(',')})")
      end
    end

    @count = scope.size
    @paginator = Redmine::Pagination::Paginator.new(@count, @limit, @page)

    scope = scope.joins("LEFT JOIN #{RmptCategory.table_name} cat on cat.id = #{RmptTest.table_name}.category_id
                         LEFT JOIN #{UserDepartment.table_name} dep on dep.id = u.user_department_id
                         LEFT JOIN #{UserDepartmentTree.table_name} dep_t on dep_t.id = dep.id
                         LEFT JOIN #{UserTitle.table_name} u_title on u_title.id = u.user_title_id
                        ")
                 .select('dep.id as dep_id,
                          dep.name as dep_name,
                          u_title.name as title_name,
                          cat.id as cat_id,
                          cat.name as cat_name
                         ')

    if @group_by == 'user'
      scope = scope.order(Arel.sql('case when dep_t.id is null then 0 else 1 end,
                           dep_t.lft
                          '))
                   .order(*User.fields_for_order_statement('u'))
    else
      scope = scope.order(Arel.sql("case when cat.id is null then 0 else 1 end, cat.lft, #{RmptTest.table_name}.name"))

    end

    scope = scope.order(Arel.sql("case when #{RmptTest.table_name}.attempts is not null and c_ut.cnt >= #{RmptTest.table_name}.attempts + COALESCE(ex_att.attempts, 0) then 0 else 1 end,
                         max_passed"))
                 .order(*User.fields_for_order_statement('u'))
                 .order(Arel.sql("st.due,
                         #{RmptTest.table_name}.name
                        "))


    if params[:export].to_i == 0
      scope = scope.limit(@limit).offset(@paginator.offset)
    end

    test_ids = []
    user_ids = []
    scope.each do |t|
      test_ids << t.id
      user_ids << t.attributes['user_id'].to_i
    end

    if test_ids.present?
      test_ids = test_ids.uniq
      user_ids = user_ids.uniq

      @users = User.where(id: user_ids + [0]).inject({}) { |h, u| h[u.id] = u; h }

      @user_attempts = RmptUserTest.preload(:questions, :user)
                                   .where(user_id: user_ids, test_id: test_ids + [0])
                                   .order(Arel.sql('case when start_at is null then 0 else 1 end ASC, start_at DESC'))
                                   .inject({}) { |h, it| (h["#{it.test_id}-#{it.user_id}"] ||= []) << it; h }
    end

    @report_data = scope
    @user_attempts ||= {}

    if request.xhr?
      render partial: "#{@group_by}s_list"
    else
      if params[:export].to_i == 1
        xlsx = generate_tests_xlsx
        send_data(xlsx.delete(:data).read, xlsx)
      end
    end
  end

  private

  def generate_tests_xlsx
    date = Time.now.strftime('%Y-%m-%d %H%M%S').to_s
    xlsx = Axlsx::Package.new

    col_header = xlsx.workbook.styles.add_style(alignment: { horizontal: :left }, sz: 11, b: true, border: Axlsx::STYLE_THIN_BORDER)
    record = xlsx.workbook.styles.add_style(alignment: { horizontal: :left }, border: Axlsx::STYLE_THIN_BORDER)

    xlsx.workbook.add_worksheet(name: date) do |sheet|
      sheet.add_row([
        l(:label_rmpt_user),
        '',
        '',
        l(:label_rmpt_test),
        l(:field_rmpt_test_category),
        l(:label_rmpt_attempts),
        '',
        l(:label_rmpt_test_status),
        l(:field_rmpt_user_test_start_at),
        l(:label_rmpt_user_test_time_used),
        l(:field_rmpt_user_test_result_ratio),
        '',
        '',
        l(:label_rmpt_test_due)
      ], style: col_header, widths: [:auto, 20, 20, :auto, nil, 5, 5, :auto, 20, 20, 5, 5, 5, 20])

      sheet.merge_cells('A1:C1')
      sheet.merge_cells('F1:G1')
      sheet.merge_cells('K1:M1')

      @report_data.each do |t|
        best_attempt = nil
        (@user_attempts["#{t.id}-#{t.attributes['user_id']}"] || []).each_with_index do |ut, index|
          if best_attempt.blank? && ut.result_ratio == t.attributes['max_result_ratio']
            best_attempt = ut
          end
        end

        row = [@users[t.attributes['user_id']].name,
               t.attributes['dep_name'],
               t.attributes['title_name'],
               t.name,
               t.category.try(:name) || 'x',
               rmp_number_text(t.attributes['attempts_used'], 'x'),
               rmp_number_text(t.total_attempts, '∞')
        ]
        if best_attempt.present?
          row << l("label_rmpt_test_status_#{best_attempt.status}")
          row << (best_attempt.start_at.present? ? format_time(best_attempt.start_at) : 'x')
          if best_attempt.expired?
            row << l(:label_rmpt_time_expired)
          else
            row << (best_attempt.end_at.present? ? Rmpt::Utils.convert_seconds_to_day_time_string((best_attempt.end_at - best_attempt.start_at).to_i, l(:label_rmpt_days_unit_short)) : 'x')
          end
          if best_attempt.result_ratio.present?
            row << rmp_number_text(best_attempt.result_ratio)
            row << best_attempt.q_count_correct.to_i
            row << best_attempt.q_count_total.to_i
          else
            row << 'x'
            row << 'x'
            row << 'x'
          end
        else
          l("label_rmpt_test_status_#{RmptUserTest::STATUS_BLANK}")
          row << 'x'
          row << 'x'
          row << 'x'
          row << 'x'
          row << 'x'
          row << 'x'
        end

        row << (t.attributes['due'].present? ? format_date(t.attributes['due']) : '∞')

        sheet.add_row(row, style: record, widths: [:auto, 20, 20, :auto, nil, 5, 5, :auto, 20, 20, 5, 5, 5, 20])
      end

    end

    xlsx.use_shared_strings = true

    return {
      data: xlsx.to_stream,
      filename: "test_report_#{date.tr('- :', '')}.xlsx",
      type: "application/vnd.openxmlformates-officedocument.spreadsheetml.sheet"
    }
  end
end