class RmptTestsController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :authorized_globaly?
  before_action :find_rmpt_test, only: [:edit, :update, :destroy, :participants, :patterns_preview, :extra_attempt, :import]

  helper :attachments
  helper :group_sets
  helper :rmpt

  def index
    if params[:category_id]
      if params[:category_id].to_i == -1
        @cat_blank = true
      else
        @cat = RmptCategory.where(id: params[:category_id]).first
      end
    end
    @categories_tree = RmptCategory.all.order(:lft)

    @tests = RmptTest.joins("LEFT JOIN #{RmptCategory.table_name} c ON c.id = #{RmptTest.table_name}.category_id
                             LEFT JOIN #{User.table_name} a ON a.id = #{RmptTest.table_name}.author_id
                            ")
                     .preload(:category, :author)
                     .manageable(User.current)
                     .order(Arel.sql('case when c.id is null then 0 else 1 end ASC, c.lft ASC'))

    sort_field = 'id asc'
    @sort = (params[:sort] || {})
    if @sort.respond_to?(:to_unsafe_hash)
      @sort = @sort.to_unsafe_hash
    end
    @sort = {} unless @sort.is_a?(Hash)

    if @sort[:f].present?
      direction = @sort[:d].to_s.downcase
      direction = 'asc' if direction.blank? || !%w(asc desc).include?(direction)

      if @sort[:f] == 'name'
        sort_field = "#{RmptTest.table_name}.name #{direction}"
      elsif @sort[:f] == 'author'
        sort_field = User.fields_for_order_statement('a').join(" #{direction}, ") + " #{direction}"
      end
    end
    @tests = @tests.order(Arel.sql(sort_field))

    if @cat.present?
      @tests = @tests.where('c.lft >= ? and c.rgt <= ?', @cat.lft, @cat.rgt)
    end

    if @cat_blank
      @tests = @tests.where('c.id is null')
    end

    if request.xhr?
      render partial: 'tests_list'
    end
  end

  def new
    @test = RmptTest.new
    @test.safe_attributes = params[:rmpt_test] || {}
  end

  def edit
    @test.fill_default_page_patterns
    @test.fill_default_group_set
  end

  def create
    @test = RmptTest.new
    @test.safe_attributes = params[:rmpt_test] || {}

    if @test.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to controller: :rmpt_tests, action: :edit, id: @test.id
    else
      render :new
    end
  end

  def update
    @test.fill_default_page_patterns
    @test.fill_default_group_set
    @test.safe_attributes = params[:rmpt_test]
    if @test.save
      flash[:notice] = l(:notice_successful_update)
    end

    render :edit
  end

  def destroy
    @test.destroy
    index
  end

  def participants
    p = params.to_unsafe_hash
    if request.delete?
      if p[:groupsets].present?
        @test.participants_delete_ids = p[:groupsets]
        if @test.save
          render json: {}
        else
          render json: { errors: @test.errors.full_messages }
        end
      else
        @test.group_set.rules_delete_ids = p[:gs_rules]
        if @test.group_set.save
          render json: {}
        else
          render json: { errors: @test.group_set.errors.full_messages }
        end
      end
    else
      if p[:groupsets].present?
        @test.participants_append_attributes = p[:groupsets]
        if @test.save
          render json: @test.appended_participants.inject({}) { |h, p| h[p.group_set_id] = { id: p.id, name: p.group_set.name }; h }
        else
          render json: { errors: @test.errors.full_messages }
        end
      else
        @test.group_set_attributes = p[:gs_rules]
        if @test.group_set.save
          @test.group_set.rules.reload
          render json: view_context.grouped_rules(@test.group_set.appended_rules)
        else
          render json: { errors: @test.group_set.errors.full_messages }
        end
      end
    end
  end

  def participants_autocomplete
    render json: GroupSetGlobal.sorted.where('name like ?', "%#{params[:q]}%").map { |t| [t.name, t.id, t.name] }
  end

  def patterns_preview
    user_test = @test.copy_to_user(User.current)

    @text = params[:text]
    @text = Rmpt::Utils::Macros::RmptUserMacros.instance.replace(@text, user_test)
    render layout: false
  end

  def extra_attempt
    @user = User.where(id: params[:user_id]).first
    if @user.present?
      @ex_attempt = @test.extra_attempts.where(user_id: @user.id).first_or_initialize
    else
      @ex_attempt = RmptExtraAttempt.new(test_id: @test.id)
    end
    if request.post?
      @ex_attempt.attempts = @ex_attempt.attempts.to_i + params[:attempts].to_i
      if @ex_attempt.save
        render json: { attempts: @ex_attempt.attempts, has_attempts: @test.has_attempts?(@user) }
      else
        render json: { attempts: 0 }
      end
    elsif request.delete?
      render json: { result: @ex_attempt.destroy }
    else
      render layout: false
    end
  end

  def ajax_users_list
    if params[:test_id].present?
      users = RmptTest.enrolled_users(User.current).where('et.id = ?', @test.id)
    else
      users = User.active.like(params[:q])
    end
    render json: users.sorted.limit(100).map { |u| { id: u.id, text: u.name } }
  end

  def import
    data = params[:file]
    if data.blank? || !data.respond_to?(:path) || data.path.blank?
      flash[:error] = l(:error_rmpt_import_sheet_undefined)
      redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
      return
    end

    filename = data.original_filename.strip
    mime_type = Redmine::MimeType.of(filename)

    if data.size > 5.megabytes
      flash[:error] = l(:error_rmpt_import_sheet_too_big, size: 5)
      redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
      return
    end

    if data.size <= 0
      flash[:error] = l(:error_rmpt_import_sheet_blank)
      redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
      return
    end

    if mime_type != 'text/csv' && mime_type != 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      flash[:error] = l(:error_rmpt_import_sheet_wrong_file)
      redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
      return
    end

    begin
      col_sep = l(:general_csv_separator)
      encoding = l(:general_csv_encoding)

      sheet = Roo::Spreadsheet.open(data.path, expand_merged_ranges: true, headers: false, return_headers: false, skip_blanks: false, csv_options: { col_sep: col_sep, encoding: encoding })
      if sheet.sheets.size == 0
        flash[:error] = l(:error_rmpt_import_sheet_blank)
        redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
        return
      end
    rescue Exception => ex
      flash[:error] = l(:error_rmpt_import_sheet_process)
      redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
      return
    end

    last_q_num = nil
    position = 0

    num = nil
    qtext = nil
    qtype = nil
    answers = []
    errors = []
    cnt = 0
    row_num = 0

    proc = Proc.new { |row|
      row_num += 1
      next if row_num == 1
      next if row.size < 5

      cells = []
      row.each do |cell|
        if cell.respond_to?(:value)
          cells << cell.value
        elsif cell.is_a?(Array)
          cells << cell[1]
        else
          cells << cell
        end
      end

      num = cells[0].present? ? cells[0] : num

      if last_q_num.present? && num != last_q_num
        if qtext.present? && qtype.present?
          qtype = qtype.blank? || qtype == 'один ответ' ? RmptQuestion::QTYPE_SINGLE : RmptQuestion::QTYPE_MULTIPLE
          q = RmptQuestion.new(test_id: @test.id, position: position, text: qtext, qtype: qtype, randomize: false)
          q.answers_attributes = answers
          unless q.save
            errors = q.errors.full_messages
            raise ActiveRecord::Rollback
          end
          cnt += 1
          position += 1
        end

        qtext = nil
        qtype = nil
        answers = []
      end

      last_q_num = num
      qtext = cells[1].present? ? cells[1].to_s : qtext
      qtype = cells[2].present? ? cells[2].to_s : qtype

      if cells[3].present?
        answers << { text: cells[3].to_s, correct: cells[4].to_s.to_i == 1 }
      end
    }

    sheet.sheet(0)

    RmptTest.transaction do
      if sheet.respond_to?(:each_row_streaming)
        sheet.each_row_streaming({ pad_cells: true }, &proc)
      else
        sheet.instance_variable_set :@header_line, 1
        sheet.each({}, &proc)
      end

      if errors.blank? && qtext.present? && qtype.present?
        qtype = qtype.blank? || qtype == l(:rmpt_label_import_qtype_single) ? RmptQuestion::QTYPE_SINGLE : RmptQuestion::QTYPE_MULTIPLE
        q = RmptQuestion.new(test_id: @test.id, position: position, text: qtext, qtype: qtype, randomize: false)
        q.answers_attributes = answers
        unless q.save
          errors = q.errors.full_messages
          raise ActiveRecord::Rollback
        end
        cnt += 1
      end
    end

    if errors.present?
      flash[:error] = '<ul><li>' + errors.join('</li><li>') + '</li></ul>'
    elsif cnt == 0
      flash[:error] = l(:label_rmpt_import_success_no)
    else
      flash[:notice] = l(:label_rmpt_import_success, count: cnt)
    end

    redirect_to controller: :rmpt_tests, action: :edit, id: @test.id, tab: params[:tab]
  end

  private

  def find_rmpt_test
    @test = RmptTest.find(params[:id])
    unless @test.manageable?
      render_403
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end