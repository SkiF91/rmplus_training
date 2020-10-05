module Rmpt::Utils
  def self.convert_seconds_to_time_parts(seconds)
    return nil if seconds.blank?

    days = (seconds / 86400.0).to_i
    seconds -= days * 86400

    h = (seconds / 3600).to_i
    seconds -= h * 3600
    m = (seconds / 60).to_i
    seconds -= m * 60

    [days, h, m, seconds]
  end

  def self.convert_seconds_to_day_time_string(seconds, day_lbl)
    return nil if seconds.blank?
    parts = convert_seconds_to_time_parts(seconds)

    if parts[0] > 0
      "#{parts[0]} #{day_lbl} #{parts[1].to_s.rjust(2, '0')}:#{parts[2].to_s.rjust(2, '0')}:#{parts[3].to_s.rjust(2, '0')}"
    else
      "#{parts[1].to_s.rjust(2, '0')}:#{parts[2].to_s.rjust(2, '0')}:#{parts[3].to_s.rjust(2, '0')}"
    end
  end

  def self.convert_seconds_to_time_string(seconds)
    return nil if seconds.blank?

    parts = convert_seconds_to_time_parts(seconds)
    parts[1] = parts[1].to_i + parts[0] * 24
    parts[0] = nil

    "#{parts[1].to_s.rjust(2, '0')}:#{parts[2].to_s.rjust(2, '0')}:#{parts[3].to_s.rjust(2, '0')}"
  end
end