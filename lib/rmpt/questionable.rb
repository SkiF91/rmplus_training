module Rmpt::Questionable
  def self.included(base)
    base.class_eval do
      after_save :store_answers
    end
  end
  def text_inline
    self.text.to_s.truncate(50)
  end

  def correct_answers_inline
    self.answers.map { |a| a.correct? ? a.text : nil }.compact
  end

  def qtype_text
    l("label_rmpt_question_qtype_#{self.qtype}")
  end

  def qtype_header_text
    l("label_rmpt_question_qtype_#{self.qtype}_header")
  end

  def type_single?
    self.qtype == RmptQuestion::QTYPE_SINGLE
  end

  def type_multiple?
    self.qtype == RmptQuestion::QTYPE_MULTIPLE
  end

  def answers_attributes=(values)
    klass = self.class.reflections['answers'].try(:klass) || RmptAnswer

    @was_answer_assign = true
    @answers = []
    Array.wrap(values).each do |v|
      @answers << klass.new(v.merge(question: self))
    end
  end

  def dirty_answers
    if @answers.present?
      @answers
    else
      self.answers
    end
  end

  def store_answers
    if @answers
      if self.type_single?
        was_correct = false
        @answers.each do |answ|
          answ.correct = false if was_correct && answ.correct?
          was_correct = true if answ.correct?
        end
      end
      self.answers = @answers
    end
  end
end