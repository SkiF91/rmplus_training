module Rmpt::Testable
  include RmptHelper

  def min_pass=(value)
    if value.present?
      self.min_pass_percent = nil
    end

    write_attribute :min_pass, value
  end

  def min_pass_percent=(value)
    if value.present?
      self.min_pass = nil
    end

    write_attribute :min_pass_percent, value
  end

  def timelimit_total=(value)
    if value.present?
      self.timelimit_q = nil
      if value.is_a?(String)
        value = Time.parse(value).seconds_since_midnight
      end
    end

    write_attribute :timelimit_total, value
  end

  def timelimit_q=(value)
    if value.present?
      self.timelimit_total = nil
      if value.is_a?(String)
        value = Time.parse(value).seconds_since_midnight
      end
    end

    write_attribute :timelimit_q, value
  end

  def can_resubmit=(value)
    write_attribute :can_resubmit, value
    if self.can_resubmit?
      self.show_q_result = false
    end
    self.can_resubmit?
  end

  def show_q_result=(value)
    if self.can_resubmit?
      value = false
    end
    write_attribute :show_q_result, value
  end

  def show_t_result=(value)
    write_attribute :show_t_result, value
  end

  def min_pass_text
    if self.min_pass_percent.present?
      self.min_pass_percent
    elsif self.min_pass.present? && self.min_pass.to_i <= self.q_count_total.to_i
      self.min_pass
    else
      self.q_count_total
    end
  end
end