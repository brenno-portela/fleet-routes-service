# frozen_string_literal: true

require 'test_helper'

class RouteTest < Minitest::Test
  def setup
    @valid_attributes = {
      name: 'Rota Centro-Sul 10/11',
      seller_uid: 'seller_123',
      seller_name: 'Carlos Vendedor',
      seller_email: 'carlos@exemplo.com',
      status: Route::STATUS_ASSIGNED,
      due_date: Date.today,
      target_completion_percent: 90,
      state: 'SP'
    }
  end

  def test_valid_route_creation
    route = Route.new(@valid_attributes)
    assert route.valid?
    assert route.save
  end

  def test_requires_mandatory_fields
    route = Route.new
    refute route.valid?
    assert_includes route.errors[:name], "can't be blank"
    assert_includes route.errors[:seller_uid], "can't be blank"
  end

  def test_status_inclusion_validation
    route = Route.new(@valid_attributes.merge(status: 'invalid_status'))
    refute route.valid?
    assert_includes route.errors[:status], 'is not included in the list'
  end

  def test_target_completion_percent_range
    route_low = Route.new(@valid_attributes.merge(target_completion_percent: 0))
    refute route_low.valid?

    route_high = Route.new(@valid_attributes.merge(target_completion_percent: 101))
    refute route_high.valid?

    route_valid = Route.new(@valid_attributes.merge(target_completion_percent: 85))
    assert route_valid.valid?
  end

  def test_origin_coordinates_validation
    # Coordenadas válidas
    route = Route.new(@valid_attributes.merge(origin_latitude: -23.55052, origin_longitude: -46.633308))
    assert route.valid?

    # Coordenadas fora do limite do globo
    route_invalid = Route.new(@valid_attributes.merge(origin_latitude: 95.0, origin_longitude: -46.633308))
    refute route_invalid.valid?
    assert_includes route_invalid.errors[:origin_coordinates], 'devem ser uma latitude e longitude terrestres válidas e não nulas'
  end

  def test_cascade_destruction_of_stops_and_events
    route = Route.create!(@valid_attributes)
    stop = route.route_stops.create!(
      customer_id: 'cust_1',
      customer_name: 'Cliente Alpha',
      latitude: -23.55,
      longitude: -46.63,
      order: 1,
      status: RouteStop::STATUS_ASSIGNED
    )
    event = route.visit_events.create!(
      event_type: VisitEvent::EVENT_LOCATION_SAMPLE,
      latitude: -23.551,
      longitude: -46.631,
      recorded_at: Time.now
    )

    assert_equal 1, RouteStop.where(route_id: route.id).count
    assert_equal 1, VisitEvent.where(route_id: route.id).count

    route.destroy

    assert_equal 0, RouteStop.where(route_id: route.id).count
    assert_equal 0, VisitEvent.where(route_id: route.id).count
  end

  def test_recorded_execution_audit_lock
    route = Route.create!(@valid_attributes.merge(status: Route::STATUS_ASSIGNED))
    refute route.recorded_execution?

    # Se a rota mudar para in_progress, a trava é ativada
    route.status = Route::STATUS_IN_PROGRESS
    assert route.recorded_execution?

    # Se a rota voltar para assigned, mas uma de suas paradas foi visitada
    route.status = Route::STATUS_ASSIGNED
    stop = route.route_stops.create!(
      customer_id: 'cust_1',
      customer_name: 'Cliente Alpha',
      latitude: -23.55,
      longitude: -46.63,
      order: 1,
      status: RouteStop::STATUS_VISITED
    )
    assert route.recorded_execution?
  end

  def test_completion_percent_and_target_calculation
    route = Route.create!(@valid_attributes.merge(target_completion_percent: 80))
    # 2 paradas visitadas de 4 paradas totais = 50%
    route.route_stops.create!(customer_id: 'c1', customer_name: 'C1', latitude: -23.55, longitude: -46.63, order: 1, status: RouteStop::STATUS_VISITED)
    route.route_stops.create!(customer_id: 'c2', customer_name: 'C2', latitude: -23.56, longitude: -46.64, order: 2, status: RouteStop::STATUS_VISITED)
    route.route_stops.create!(customer_id: 'c3', customer_name: 'C3', latitude: -23.57, longitude: -46.65, order: 3, status: RouteStop::STATUS_ASSIGNED)
    route.route_stops.create!(customer_id: 'c4', customer_name: 'C4', latitude: -23.58, longitude: -46.66, order: 4, status: RouteStop::STATUS_NOT_VISITED)

    assert_equal 50, route.completion_percent
    # 4 paradas * 80% = 3.2 -> ceil = 4 paradas
    assert_equal 4, route.calculate_target_completed_stops
  end
end

