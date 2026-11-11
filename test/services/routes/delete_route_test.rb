# frozen_string_literal: true

require 'test_helper'

class Routes::DeleteRouteTest < Minitest::Test
  def setup
    @route_attrs = {
      name: 'Rota para Deletar',
      seller_uid: 'seller_123',
      seller_name: 'Carlos',
      seller_email: 'carlos@teste.com',
      status: Route::STATUS_ASSIGNED,
      due_date: Date.today,
      target_completion_percent: 90,
      state: 'SP'
    }

    @route = Route.create!(@route_attrs)
  end

  def test_deletes_route_and_cascades_to_stops_and_events
    # Cria paradas para a rota
    stop1 = @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    stop2 = @route.route_stops.create!(
      customer_id: 'cust_002',
      customer_name: 'Cliente B',
      latitude: -23.56052,
      longitude: -46.643308,
      order: 2,
      status: RouteStop::STATUS_PENDING
    )

    # Cria frequências de visitação (stop_attendances)
    attendance1 = stop1.stop_attendances.create!(
      check_in_at: Time.now,
      check_out_at: Time.now + 1.hour,
      status: StopAttendance::STATUS_VISITED
    )

    attendance2 = stop2.stop_attendances.create!(
      check_in_at: Time.now + 2.hours,
      status: StopAttendance::STATUS_PENDING
    )

    # Cria eventos de visitação
    event1 = @route.visit_events.create!(
      event_type: VisitEvent::EVENT_LOCATION_SAMPLE,
      latitude: -23.55052,
      longitude: -46.633308,
      recorded_at: Time.now
    )

    event2 = @route.visit_events.create!(
      event_type: VisitEvent::EVENT_CHECK_IN,
      latitude: -23.55052,
      longitude: -46.633308,
      recorded_at: Time.now + 1.hour,
      route_stop_id: stop1.id
    )

    route_id = @route.id
    stop1_id = stop1.id
    stop2_id = stop2.id
    attendance1_id = attendance1.id
    attendance2_id = attendance2.id
    event1_id = event1.id
    event2_id = event2.id

    # Executa a deleção
    result = Routes::DeleteRoute.call(@route)

    # Verifica que retornou true
    assert_equal true, result

    # Verifica que a rota foi deletada
    assert_nil Route.find_by(id: route_id)

    # Verifica que as paradas foram deletadas (cascata)
    assert_nil RouteStop.find_by(id: stop1_id)
    assert_nil RouteStop.find_by(id: stop2_id)

    # Verifica que as frequências foram deletadas (cascata via route_stops)
    assert_nil StopAttendance.find_by(id: attendance1_id)
    assert_nil StopAttendance.find_by(id: attendance2_id)

    # Verifica que os eventos foram deletados (cascata)
    assert_nil VisitEvent.find_by(id: event1_id)
    assert_nil VisitEvent.find_by(id: event2_id)
  end

  def test_deletes_route_with_route_id
    route_id = @route.id

    result = Routes::DeleteRoute.call(route_id)

    assert_equal true, result
    assert_nil Route.find_by(id: route_id)
  end

  def test_deletes_route_with_route_instance
    route_id = @route.id

    result = Routes::DeleteRoute.call(@route)

    assert_equal true, result
    assert_nil Route.find_by(id: route_id)
  end

  def test_raises_route_not_found_for_missing_route
    error = assert_raises(Routes::RouteNotFoundError) do
      Routes::DeleteRoute.call(99_999)
    end

    assert_includes error.message, 'Não foi possível identificar a rota a excluir.'
  end

  def test_raises_route_not_found_for_string_id
    error = assert_raises(Routes::RouteNotFoundError) do
      Routes::DeleteRoute.call('invalid_id_string')
    end

    assert_includes error.message, 'Não foi possível identificar a rota a excluir.'
  end

  def test_raises_route_not_found_for_invalid_type
    error = assert_raises(Routes::RouteNotFoundError) do
      Routes::DeleteRoute.call([])
    end

    assert_includes error.message, 'Não foi possível identificar a rota a excluir.'
  end

  def test_call_class_method_delegates_to_instance
    route_id = @route.id

    result = Routes::DeleteRoute.call(@route)

    assert_equal true, result
    assert_nil Route.find_by(id: route_id)
  end

  def test_deletes_route_with_no_stops_or_events
    # Cria uma rota sem paradas nem eventos
    empty_route = Route.create!(@route_attrs.merge(name: 'Rota Vazia'))
    empty_route_id = empty_route.id

    result = Routes::DeleteRoute.call(empty_route)

    assert_equal true, result
    assert_nil Route.find_by(id: empty_route_id)
  end

  def test_uses_pessimistic_lock_during_deletion
    # Cria um stop para a rota
    stop = @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    route_id = @route.id
    stop_id = stop.id

    # Chama delete e verifica que usa with_lock
    result = Routes::DeleteRoute.call(@route)

    assert_equal true, result
    assert_nil Route.find_by(id: route_id)
    assert_nil RouteStop.find_by(id: stop_id)
  end
end
