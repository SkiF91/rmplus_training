class RmptController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :find_rmpt_test, only: [:prepare, :processing]
  before_action :find_rmpt_user_test, only: [:result, :result_answers]

  helper :rmpt

  def index
    @q = params[:q]
    @q = 'on_me' if @q.blank?
    @q = 'on_me' unless %w(on_me completed overdue failed).include?(@q)

    @test_data = prepare_my_tests_data(@q)

    if request.xhr?
      render partial: 'rmpt/tests_list', locals: { test_data: @test_data }
    else
      @max_depth = RmptCategory.joins("LEFT JOIN #{RmptCategory.table_name} t on t.lft <= #{RmptCategory.table_name}.lft and t.rgt >= #{RmptCategory.table_name}.rgt")
                               .select("#{RmptCategory.table_name}.id, COUNT(1) as depth")
                               .group("#{RmptCategory.table_name}.id")
                               .order('depth DESC')
                               .first
      if @max_depth.present?
        @max_depth = @max_depth.attributes['depth'].to_i
      else
        @max_depth = 0
      end
    end
  end

  def prepare
    user_test = @test.started_user_attempt(User.current)
    if user_test.present? && user_test.status_started?
      redirect_to controller: :rmpt, action: :processing, id: @test.id
      return
    end

    if user_test.blank? && !@test.enrolled?(User.current)
      render_403
      return
    end

    @is_retry = @test.user_attempts(User.current).size > (user_test.present? ? 1 : 0)
    @text = @is_retry ? @test.page_pattern.retry_text : @test.page_pattern.start_text

    if user_test.present?
      @user_test = user_test
    else
      @user_test = @test.copy_to_user!(User.current)
    end

    @text = Rmpt::Utils::Macros::RmptUserMacros.instance.replace(@text, @user_test)
  end

  def result
    unless @user_test.has_access?(User.current)
      render_403
      return
    end

    if @user_test.status_blank?
      redirect_to controller: :rmpt, action: :prepare, id: @user_test.test_id
      return
    end
    if @user_test.status_started?
      redirect_to controller: :rmpt, action: :processing, id: @user_test.test_id
      return
    end

    if @user_test.expired?
      flash.now[:error] = l(:error_rmpt_user_test_timelimit_expired)
    end

    if @user_test.status_success?
      @text = @user_test.test.page_pattern.success_text
    else
      @text = @user_test.test.page_pattern.fail_text
    end

    @text = Rmpt::Utils::Macros::RmptUserMacros.instance.replace(@text, @user_test)
  end

  def result_answers
    unless @user_test.has_access_result?(User.current) || @user_test.test.manageable?
      render_403
      return
    end

    if params[:num].present?
      @q_num = params[:num]
      @question = @user_test.questions.where(num: @q_num).first
    else
      @question = @user_test.questions.first
    end
    @is_report = params[:is_report]
    render layout: false
  end

  def processing
    # не передаем id RmptUserTest, т.к. тест нельзя запустить несколько раз одновременно
    @user_test = @test.started_user_attempt(User.current)

    if @user_test.blank?
      # возможно тест просрочился или нет запущенного теста
      possible_attempt = @test.last_user_attempt(User.current)

      # просрочился
      if possible_attempt.present? && possible_attempt.expired?
        # попробуем закрыть
        if possible_attempt.complete_step!
          apply_processing({ redirect_to: url_for(controller: :rmpt, action: :result, id: possible_attempt.id) })
        else
          apply_processing({ errors: possible_attempt.errors.full_messages })
        end
        return
      end

      # нет запущенного
      if possible_attempt.blank?
        apply_processing({ errors: l(:notice_file_not_found), status: 404 })
      else
        apply_processing({ redirect_to: url_for(controller: :rmpt, action: :result, id: possible_attempt.id) })
      end

      return
    end

    # запускаем тест, если не был запущен... всегда при любом действии
    unless @user_test.ensure_start_step!
      apply_processing({ errors: @user_test.errors.full_messages, status: 403 })
      return
    end

    # если в тесте нет вопросов, то он завершится при запуске
    if @user_test.completed?
      apply_processing({ redirect_to: url_for(controller: :rmpt, action: :result, id: @user_test.id) })
      return
    end

    # пытаемся закрыть принудительно
    if params[:complete]
      if @user_test.complete_step!
        apply_processing({ redirect_to: url_for(controller: :rmpt, action: :result, id: @user_test.id) })
      else
        apply_processing({ errors: @user_test.errors.full_messages, status: 403 })
      end
      return
    end

    # передаем не id вопроса, а его порядковый номер
    @q_num = params[:q_num].to_i

    # либо действие (только через JS и POST), либо другое, что приравнивается к попытке получения инфы по вопросу
    if request.xhr? && request.post?
      res = @user_test.store_step!(@q_num, params[:rmpt] || {})

      if res.is_a?(Hash)
        if res[:next].present?
          question = @user_test.touch_step!(res[:next].num)
        else
          question = nil
        end
      else
        question = res
      end
    else
      question = @user_test.touch_step!(@q_num)
    end

    if question.present?
      @q_num = question.num
      @question = question
    end

    if question == false
      apply_processing({ errors: @user_test.errors.full_messages, next_num: @user_test.next_question.try(:num) })
    elsif question.present?
      @user_test.reload
      json_data = {
          mode: 'test',
          question: question_hash(question),
          progress: @user_test.q_count_completed,
          total: @user_test.q_count_total,
          timelimit_left: question.timelimit_left || @user_test.timelimit_left
      }
      questions = []
      @user_test.questions.each do |q|
        tmp = {
          id: q.id,
          num: q.num,
          selectable: q.selectable?,
          completed: q.completed? || q.expired?(false),
          expired: q.calc_expired?
        }

        if @user_test.show_q_result?
          tmp[:correct] = q.correct
        end
        questions << tmp
      end
      json_data[:questions] = questions

      apply_processing(json_data)
    else
      apply_processing({ redirect_to: url_for(controller: :rmpt, action: :result, id: @user_test.id) })
    end
  end

  private

  def find_rmpt_test
    @test = RmptTest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_rmpt_user_test
    @user_test = RmptUserTest.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def question_hash(question, correct=false)
    res = {
      id: question.id,
      num: question.num,
      text: view_context.textilizable(question, :text, attachments: question.saved_attachments),
      start_at: question.start_at,
      end_at: question.end_at,
      qtype: question.qtype,
      qtype_single: question.type_single?,
      qtype_text: question.qtype_header_text,
      completed: question.completed
    }
    if correct
      res[:answers] = question.answers.map { |a| { id: a.id, num: a.num, text: a.text, selected: a.selected?, correct: a.correct? } }
    else
      res[:answers] = question.answers.map { |a| { id: a.id, num: a.num, text: a.text, selected: a.selected? } }
    end

    res
  end

  def apply_processing(hash)
    if request.xhr?
      render json: hash
    elsif hash.present?
      if hash.has_key?(:redirect_to)
        redirect_to hash[:redirect_to]
      elsif hash.has_key?(:status) && hash[:status] == 403
        if hash[:errors].present?
          render_403 message: Array.wrap(hash[:errors]).join(', ')
        else
          render_403
        end
      elsif hash.has_key?(:status) && hash[:status] == 404
        if hash[:errors].present?
          render_404 message: Array.wrap(hash[:errors]).join(', ')
        else
          render_404
        end
      else
        @next_num = hash[:next_num]
        render layout: 'rmpt_test_processing'
      end
    else
      render layout: 'rmpt_test_processing'
    end
  end

  def prepare_my_tests_data(tp)
    scope = RmptTest.my_filtered(User.current, tp)

    used_cats = scope.except(:select)
                     .select("#{RmptTest.table_name}.category_id, COUNT(1) as cnt")
                     .group("#{RmptTest.table_name}.category_id")
                     .to_sql

    categories_scope = RmptCategory.joins("INNER JOIN #{RmptCategory.table_name} tc ON tc.lft >= #{RmptCategory.table_name}.lft and tc.rgt <= #{RmptCategory.table_name}.rgt
                                           INNER JOIN (#{used_cats}) uc ON uc.category_id = tc.id
                                          ")
                                   .select("#{RmptCategory.table_name}.*,
                                            COUNT(1) as occurs,
                                            SUM(uc.cnt) as tests_cnt,
                                            MAX(case when tc.id = #{RmptCategory.table_name}.id then 1 else 0 end) as has_tests,
                                            MAX(case when tc.parent_id = rmpt_categories.id then 1 else 0 end) as p_has_tests")
                                   .group("#{RmptCategory.table_name}.#{RmptCategory.column_names.join(", #{RmptCategory.table_name}.")}")
                                   .order("#{RmptCategory.table_name}.lft")

    scope = scope.joins("LEFT JOIN #{RmptCategory.table_name} cat on cat.id = #{RmptTest.table_name}.category_id")
                 .order(Arel.sql("case when cat.id is null then 0 else 1 end,
                         cat.lft,
                         case when c_ut.test_id is null then 0 else 1 end,
                         st.due,
                         #{RmptTest.table_name}.name
                        "))

    test_ids = scope.map(&:id).uniq
    if test_ids.blank?
      return { tests: scope }
    end
    user_attempts = RmptUserTest.preload(:questions, :user)
                                .where(user_id: User.current.id, test_id: test_ids + [0])
                                .order(Arel.sql('case when start_at is null then 0 else 1 end ASC, start_at DESC'))
                                .inject({}) { |h, it| (h[it.test_id] ||= []) << it; h }

    { categories: categories_scope, tests: scope, attempts: user_attempts }
  end
end