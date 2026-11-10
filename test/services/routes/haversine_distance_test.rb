# frozen_string_literal: true

require 'test_helper'

class HaversineDistanceTest < Minitest::Test
  def setup
    # Praça da Sé, São Paulo - SP
    @se_lat = -23.550520
    @se_lng = -46.633308

    # MASP - Av. Paulista, São Paulo - SP (~2.65 km da Sé)
    @masp_lat = -23.561414
    @masp_lng = -46.655881
  end

  def test_identical_coordinates_return_zero_distance
    distance = Routes::HaversineDistance.call(
      origin_lat: @se_lat,
      origin_lng: @se_lng,
      target_lat: @se_lat,
      target_lng: @se_lng
    )

    assert_in_delta 0.0, distance, 0.001
  end

  def test_real_world_distance_between_se_and_masp
    distance = Routes::HaversineDistance.call(
      origin_lat: @se_lat,
      origin_lng: @se_lng,
      target_lat: @masp_lat,
      target_lng: @masp_lng
    )

    # Distância real aproximada é ~2.63 km a 2.67 km
    assert_in_delta 2650.0, distance, 60.0
  end

  def test_distance_between_with_hash_inputs
    first = { latitude: @se_lat, longitude: @se_lng }
    second = { 'lat' => @masp_lat, 'lng' => @masp_lng }

    distance = Routes::HaversineDistance.distance_between(first, second)
    assert_in_delta 2650.0, distance, 60.0
  end

  def test_invalid_coordinates_return_nil
    # Coordenadas nulas
    assert_nil Routes::HaversineDistance.call(origin_lat: nil, origin_lng: @se_lng, target_lat: @masp_lat, target_lng: @masp_lng)

    # Coordenada (0, 0) - ponto nulo do oceano atlântico considerado inválido no sistema
    assert_nil Routes::HaversineDistance.call(origin_lat: 0.0, origin_lng: 0.0, target_lat: @masp_lat, target_lng: @masp_lng)

    # Coordenadas fora dos limites do globo terrestre
    assert_nil Routes::HaversineDistance.call(origin_lat: 95.0, origin_lng: @se_lng, target_lat: @masp_lat, target_lng: @masp_lng)
    assert_nil Routes::HaversineDistance.call(origin_lat: @se_lat, origin_lng: 195.0, target_lat: @masp_lat, target_lng: @masp_lng)
  end

  def test_assess_proximity_ranges
    # <= 150m: Próximo / on_site
    on_site = Routes::HaversineDistance.assess_proximity(120.0)
    assert_equal 'Próximo', on_site[:label]
    assert_equal :success, on_site[:color]
    assert_equal :on_site, on_site[:status]

    # <= 500m: Nas proximidades / nearby
    nearby = Routes::HaversineDistance.assess_proximity(420.0)
    assert_equal 'Nas proximidades', nearby[:label]
    assert_equal :info, nearby[:color]
    assert_equal :nearby, nearby[:status]

    # <= 1500m: Distante / distant
    distant = Routes::HaversineDistance.assess_proximity(1200.0)
    assert_equal 'Distante', distant[:label]
    assert_equal :warning, distant[:color]
    assert_equal :distant, distant[:status]

    # > 1500m: Muito distante / far_away
    far_away = Routes::HaversineDistance.assess_proximity(2500.0)
    assert_equal 'Muito distante', far_away[:label]
    assert_equal :error, far_away[:color]
    assert_equal :far_away, far_away[:status]

    # nil ou indisponível
    unavailable = Routes::HaversineDistance.assess_proximity(nil)
    assert_equal 'Indisponível', unavailable[:label]
    assert_equal :default, unavailable[:color]
    assert_equal :unavailable, unavailable[:status]
  end

  def test_format_meters
    assert_equal '85 m', Routes::HaversineDistance.format_meters(85.3)
    assert_equal '1,5 km', Routes::HaversineDistance.format_meters(1500.0)
    assert_equal '12,4 km', Routes::HaversineDistance.format_meters(12430.0)
    assert_equal '-', Routes::HaversineDistance.format_meters(nil)
  end

  def test_audit_feedback_with_valid_and_missing_coordinates
    feedback_coord = { latitude: @se_lat, longitude: @se_lng }
    customer_coord = { latitude: @masp_lat, longitude: @masp_lng }

    result = Routes::HaversineDistance.new.audit_feedback(
      feedback_coord: feedback_coord,
      customer_coord: customer_coord
    )

    assert result[:valid]
    assert_nil result[:reason]
    assert_in_delta 2650.0, result[:meters], 60.0
    assert_equal 'Muito distante', result[:assessment][:label]

    # Sem localização do vendedor
    missing_feedback = Routes::HaversineDistance.new.audit_feedback(
      feedback_coord: nil,
      customer_coord: customer_coord
    )
    refute missing_feedback[:valid]
    assert_equal 'Sem localização do vendedor', missing_feedback[:reason]
    assert_nil missing_feedback[:meters]
  end
end

