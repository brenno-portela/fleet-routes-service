# frozen_string_literal: true

module Routes
  # Serviço responsável por consolidar e calcular métricas de telemetria GPS,
  # comparando o trajeto e tempo planejado versus o realizado pela equipe de campo.
  class TelemetryCalculator
    class << self
      def format_distance(meters)
        new.format_distance(meters)
      end

      def format_duration(seconds)
        new.format_duration(seconds)
      end

      def format_variance(percent)
        new.format_variance(percent)
      end

      def variance_color(percent)
        new.variance_color(percent)
      end

      def variance_percent(actual:, planned:)
        new.variance_percent(actual: actual, planned: planned)
      end

      def visit_duration_seconds(check_in_at:, check_out_at:)
        new.visit_duration_seconds(check_in_at: check_in_at, check_out_at: check_out_at)
      end
    end

    def format_distance(meters)
      return '-' if meters.nil?

      val = Float(meters, exception: false)
      return '-' if val.nil? || !val.finite?

      if val < 1_000.0
        "#{val.round} m"
      else
        km = val / 1_000.0
        "#{format('%.1f', km).tr('.', ',')} km"
      end
    end

    def format_duration(seconds)
      return '-' if seconds.nil?

      val = Float(seconds, exception: false)
      return '-' if val.nil? || !val.finite?

      rounded = [0, val.round].max
      hours = rounded / 3_600
      minutes = (rounded % 3_600) / 60
      secs = rounded % 60

      if hours.positive?
        "#{hours}h #{format('%02d', minutes)} min"
      elsif minutes.positive?
        "#{minutes} min"
      else
        "#{secs} s"
      end
    end

    def format_variance(percent)
      return 'Sem comparativo' if percent.nil?

      val = Float(percent, exception: false)
      return 'Sem comparativo' if val.nil? || !val.finite?

      return 'Dentro do previsto' if val.abs < 5.0

      formatted = format('%.0f', val.abs)
      direction = val.positive? ? 'acima' : 'abaixo'
      "#{formatted}% #{direction} do previsto"
    end

    def variance_color(percent)
      return :info if percent.nil?

      val = Float(percent, exception: false)
      return :info if val.nil? || !val.finite?

      if val <= 5.0
        :success
      elsif val <= 20.0
        :warning
      else
        :error
      end
    end

    def variance_percent(actual:, planned:)
      return nil if actual.nil? || planned.nil?

      act = Float(actual, exception: false)
      plan = Float(planned, exception: false)

      return nil if act.nil? || plan.nil? || !act.finite? || !plan.finite? || plan.zero?

      ((act - plan) / plan) * 100.0
    end

    def visit_duration_seconds(check_in_at:, check_out_at:)
      t_in = parse_time(check_in_at)
      t_out = parse_time(check_out_at)

      return nil if t_in.nil? || t_out.nil? || t_out < t_in

      (t_out - t_in).round
    end

    private

    def parse_time(value)
      return nil if value.nil?
      return value if value.is_a?(Time)
      return value.to_time if value.respond_to?(:to_time)

      if value.is_a?(Numeric)
        # Suporte a timestamps em milissegundos (JS) ou segundos (Ruby)
        seconds = value > 10_000_000_000 ? value / 1_000.0 : value.to_f
        return Time.at(seconds)
      end

      Time.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end

