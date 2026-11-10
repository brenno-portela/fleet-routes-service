# frozen_string_literal: true

require 'test_helper'

class TelemetryCalculatorTest < Minitest::Test
  def test_format_distance
    assert_equal '450 m', Routes::TelemetryCalculator.format_distance(450.4)
    assert_equal '1,8 km', Routes::TelemetryCalculator.format_distance(1820.0)
    assert_equal '-', Routes::TelemetryCalculator.format_distance(nil)
    assert_equal '-', Routes::TelemetryCalculator.format_distance('invalid')
  end

  def test_format_duration
    assert_equal '42 s', Routes::TelemetryCalculator.format_duration(42)
    assert_equal '15 min', Routes::TelemetryCalculator.format_duration(900)
    assert_equal '1h 25 min', Routes::TelemetryCalculator.format_duration(5100)
    assert_equal '-', Routes::TelemetryCalculator.format_duration(nil)
  end

  def test_variance_percent_calculation
    # Real 120 vs Planejado 100 -> +20%
    variance = Routes::TelemetryCalculator.variance_percent(actual: 120, planned: 100)
    assert_in_delta 20.0, variance, 0.001

    # Real 80 vs Planejado 100 -> -20%
    variance_below = Routes::TelemetryCalculator.variance_percent(actual: 80, planned: 100)
    assert_in_delta(-20.0, variance_below, 0.001)

    # Planejado zero ou nil deve retornar nil
    assert_nil Routes::TelemetryCalculator.variance_percent(actual: 100, planned: 0)
    assert_nil Routes::TelemetryCalculator.variance_percent(actual: 100, planned: nil)
  end

  def test_format_variance
    assert_equal 'Sem comparativo', Routes::TelemetryCalculator.format_variance(nil)
    assert_equal 'Dentro do previsto', Routes::TelemetryCalculator.format_variance(3.2)
    assert_equal 'Dentro do previsto', Routes::TelemetryCalculator.format_variance(-4.5)
    assert_equal '15% acima do previsto', Routes::TelemetryCalculator.format_variance(15.2)
    assert_equal '18% abaixo do previsto', Routes::TelemetryCalculator.format_variance(-18.0)
  end

  def test_variance_color
    assert_equal :info, Routes::TelemetryCalculator.variance_color(nil)
    assert_equal :success, Routes::TelemetryCalculator.variance_color(4.0)
    assert_equal :warning, Routes::TelemetryCalculator.variance_color(15.0)
    assert_equal :error, Routes::TelemetryCalculator.variance_color(25.0)
  end

  def test_visit_duration_seconds
    t_start = Time.new(2026, 11, 10, 10, 0, 0, '-03:00')
    t_end = Time.new(2026, 11, 10, 10, 45, 0, '-03:00')

    duration = Routes::TelemetryCalculator.visit_duration_seconds(
      check_in_at: t_start,
      check_out_at: t_end
    )
    assert_equal 2700, duration

    # Testando com milissegundos (formato vindo do app Android / Firebase)
    ms_start = t_start.to_i * 1000
    ms_end = t_end.to_i * 1000
    duration_ms = Routes::TelemetryCalculator.visit_duration_seconds(
      check_in_at: ms_start,
      check_out_at: ms_end
    )
    assert_equal 2700, duration_ms

    # Se check_out for anterior ao check_in, retorna nil
    invalid = Routes::TelemetryCalculator.visit_duration_seconds(
      check_in_at: t_end,
      check_out_at: t_start
    )
    assert_nil invalid
  end
end

