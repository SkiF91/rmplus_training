class RmptQuestionsController < ApplicationController
  self.main_menu = false
  before_action :require_login
  before_action :authorized_globaly?
  before_action :find_rmpt_question, only: [:edit, :update, :destroy, :reorder, :clear_statistic]

  helper :attachments

  def new
    @question = RmptQuestion.new(test_id: params[:test_id])
  end

  def create
    @question = RmptQuestion.new
    @question.safe_attributes = params[:rmpt_question]
    @question.save_attachments(params[:attachments] || (params[:rmpt_question] && params[:rmpt_question][:uploads]))
    if @question.save
      render json: {
        id: @question.id,
        text_inline: @question.text_inline,
        correct_answers: @question.correct_answers_inline,
        randomize: @question.randomize?,
        del_message: l(:text_are_you_sure),
        del_label: l(:button_delete),
        edit_label: l(:button_edit)
      }
    else
      render json: { errors: @question.errors.full_messages }
    end
  end

  def update
    @question.save_attachments(params[:attachments] || (params[:rmpt_question] && params[:rmpt_question][:uploads]))
    @question.safe_attributes = params[:rmpt_question]
    if @question.save
      render json: {
          id: @question.id,
          text_inline: @question.text_inline,
          correct_answers: @question.correct_answers_inline,
          randomize: @question.randomize?,
          del_message: l(:text_are_you_sure),
          del_label: l(:button_delete),
          edit_label: l(:button_edit),
          count_touch: @question.count_touch,
          correct_count: @question.correct_count,
          time_touch: @question.time_touch,
          confirm_text: l(:text_rmpt_are_you_sure_stat),
          title_stat_text: l(:text_rmpt_clear_stat)
      }
    else
      render json: { errors: @question.errors.full_messages }
    end
  end

  def destroy
    @question.destroy
  end

  def reorder
    max_pos = @question.test.questions.size
    new_pos = params[:position].to_i
    new_pos = 0 if new_pos < 0
    new_pos = max_pos if new_pos > max_pos
    old_pos = @question.position.to_i
    from_pos = new_pos > old_pos ? old_pos : new_pos
    to_pos = new_pos > old_pos ? new_pos : old_pos
    @question.test.questions.where('position >= ? and position <= ?', from_pos, to_pos)
                            .update_all("position = case when id = #{@question.id} then #{new_pos} else position #{new_pos > old_pos ? '-' : '+'} 1 end")
    head :ok
  end

  def preview
    if params[:question_id].present?
      return unless find_rmpt_question
    else
      @question = RmptQuestion.new
    end

    @question.safe_attributes = params[:rmpt_question]

    @user_test = RmptUserTest.new(user: User.current)
    @user_question = @question.copy_to_user
    @user_question.test = @user_test
    @user_question.attachments = @question.attachments
    @user_question.save_attachments(params[:attachments] || (params[:rmpt_question] && params[:rmpt_question][:uploads]))

    render partial: 'preview'
  end

  def clear_statistic
    @question.update_columns(count_touch: nil, correct_count: 0, time_touch: nil)
    @question.answers.update_all(count_touch: nil)
  end

  private

  def find_rmpt_question
    @question = RmptQuestion.find(params[:id] || params[:question_id])
    unless @question.test.manageable?
      render_403
    end
    true
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end