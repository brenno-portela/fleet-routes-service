# frozen_string_literal: true

require 'test_helper'

class Routes::UpdateAssignmentTest < Minitest::Test
  def setup
    @route_attrs = {
      name: 'Rota Teste',
      seller_uid: 'seller_123',
      seller_name: 'Carlos',
      seller_email: 'carlos@teste.com',
      status: Route::STATUS_ASSIGNED,
      due_date: Date.today,
      target_completion_percent: 90,
      state: 'SP'
    }

    @route = Route.create!(@route_attrs)

    @customer_1 = {
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      address: 'Rua A, 100',
      phone_number: '11999999999',
      email: 'clientea@teste.com'
    }

    @customer_2 = {
      customer_id: 'cust_002',
      customer_name: 'Cliente B',
      latitude: -23.56052,
      longitude: -46.643308,
      address: 'Rua B, 200',
      phone_number: '11988888888',
      email: 'clienteb@teste.com'
    }

    @customer_3 = {
      customer_id: 'cust_003',
      customer_name: 'Cliente C',
      latitude: -23.57052,
      longitude: -46.653308,
      address: 'Rua C, 300',
      phone_number: '11977777777',
      email: 'clientec@teste.com'
    }
  end

  def test_updates_administrative_details_successfully
    customers = [@customer_1, @customer_2]
    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'new_seller_456',
      seller_name: 'João',
      seller_email: 'joao@teste.com',
      due_date: Date.tomorrow,
      name: 'Rota Atualizada',
      target_completion_percent: 85,
      notes: 'Notas importantes',
      customers: customers,
      current_user_uid: 'user_123',
      current_user_name: 'Admin'
    )

    assert_equal 'Rota Atualizada', result.name
    assert_equal 'new_seller_456', result.seller_uid
    assert_equal 'João', result.seller_name
    assert_equal 'joao@teste.com', result.seller_email
    assert_equal Date.tomorrow, result.due_date
    assert_equal 85, result.target_completion_percent
    assert_equal 'Notas importantes', result.assignment_notes
    assert_equal 'user_123', result.last_edited_by_uid
    assert_equal 'Admin', result.last_edited_by_name
  end

  def test_reorders_and_updates_stops_on_unexecuted_route
    # Cria a rota com 2 paradas na ordem 1, 2
    @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )
    @route.route_stops.create!(
      customer_id: 'cust_002',
      customer_name: 'Cliente B',
      latitude: -23.56052,
      longitude: -46.643308,
      order: 2,
      status: RouteStop::STATUS_PENDING
    )

    # Atualiza para uma nova ordem: cust_002 primeiro, cust_003 segundo
    customers = [@customer_2, @customer_3]
    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.today,
      customers: customers
    )

    stops = result.route_stops.ordered
    assert_equal 2, stops.size

    # Verifica a reordenação
    assert_equal 'cust_002', stops[0].customer_id
    assert_equal 1, stops[0].order
    assert_equal 'cust_003', stops[1].customer_id
    assert_equal 2, stops[1].order

    # Verifica que cust_001 foi deletado
    assert_nil Route.find_by(id: @route.id)&.route_stops&.find_by(customer_id: 'cust_001')
  end

  def test_raises_audited_error_when_changing_stops_on_in_progress_route
    # Define a rota como in_progress (recorded_execution? retorna true)
    @route.update!(status: Route::STATUS_IN_PROGRESS)

    # Cria uma parada
    @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    # Tenta mudar as paradas
    customers = [@customer_2, @customer_3]

    error = assert_raises(Routes::AuditedRouteModificationError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: customers
      )
    end

    assert_includes error.message, 'check-in, feedback ou navegação'
  end

  def test_raises_audited_error_when_changing_seller_on_visited_route
    # Cria uma parada com status visited (recorded_execution? retorna true)
    @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_VISITED
    )

    # Tenta mudar o seller
    customers = [@customer_1]

    error = assert_raises(Routes::AuditedRouteModificationError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'new_seller_xyz',
        due_date: Date.today,
        customers: customers
      )
    end

    assert_includes error.message, 'auditoria'
  end

  def test_allows_admin_edit_on_executed_route_when_stops_and_seller_unchanged
    # Define a rota como executed
    @route.update!(status: Route::STATUS_IN_PROGRESS)

    # Cria uma parada
    @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    # Atualiza apenas campos administrativos, mantendo o mesmo seller e paradas
    customers = [@customer_1]
    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123', # mesmo seller
      due_date: Date.tomorrow,
      name: 'Rota com Edição Admin',
      target_completion_percent: 75,
      customers: customers
    )

    assert_equal 'Rota com Edição Admin', result.name
    assert_equal 75, result.target_completion_percent
    assert_equal Date.tomorrow, result.due_date

    # Verifica que as paradas não foram alteradas
    assert_equal 1, result.route_stops.size
    assert_equal 'cust_001', result.route_stops.first.customer_id
  end

  def test_raises_invalid_assignment_for_invalid_coordinates
    customers_invalid = [@customer_1.merge(latitude: 95.0)] # Latitude fora do intervalo

    error = assert_raises(Routes::InvalidAssignmentError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: customers_invalid
      )
    end

    assert_includes error.message, 'coordenadas válidas'
  end

  def test_raises_invalid_assignment_when_exceeding_24_customers
    customers = 25.times.map do |i|
      {
        customer_id: "cust_#{i}",
        customer_name: "Cliente #{i}",
        latitude: -23.55052 + (i * 0.01),
        longitude: -46.633308 + (i * 0.01)
      }
    end

    error = assert_raises(Routes::InvalidAssignmentError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: customers
      )
    end

    assert_includes error.message, '24 clientes'
  end

  def test_raises_invalid_assignment_for_duplicate_customer
    customers_dup = [@customer_1, @customer_1]

    error = assert_raises(Routes::InvalidAssignmentError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: customers_dup
      )
    end

    assert_includes error.message, 'duas vezes'
  end

  def test_raises_invalid_assignment_for_empty_customers
    error = assert_raises(Routes::InvalidAssignmentError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: []
      )
    end

    assert_includes error.message, 'pelo menos um cliente'
  end

  def test_raises_invalid_assignment_for_blank_seller_uid
    error = assert_raises(Routes::InvalidAssignmentError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: '',
        due_date: Date.today,
        customers: [@customer_1]
      )
    end

    assert_includes error.message, 'Seller'
  end

  def test_raises_invalid_assignment_for_blank_due_date
    error = assert_raises(Routes::InvalidAssignmentError) do
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: nil,
        customers: [@customer_1]
      )
    end

    assert_includes error.message, 'Due date'
  end

  def test_raises_route_not_found_error
    error = assert_raises(Routes::RouteNotFoundError) do
      Routes::UpdateAssignment.call(
        route_id: 99_999,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: [@customer_1]
      )
    end

    assert_includes error.message, 'not found'
  end

  def test_rolls_back_transaction_on_unexpected_error
    # Cria uma parada inicial
    @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    initial_name = @route.name

    # Mock um erro durante a atualização de paradas
    customers = [@customer_1, @customer_2]

    # Simula um erro durante o save via classe mock
    original_update = Route.method(:update!)
    Route.define_singleton_method(:update!) do |attrs|
      raise 'Simulated error'
    end

    begin
      Routes::UpdateAssignment.call(
        route: @route,
        seller_uid: 'seller_123',
        due_date: Date.today,
        customers: customers
      )
    rescue StandardError
      # Esperado
    ensure
      # Restaura o método original
      Route.define_singleton_method(:update!, original_update)
    end

    # Recarrega a rota do banco
    @route.reload

    # Verifica que a transação foi revertida (nome não mudou)
    assert_equal initial_name, @route.name
  end

  def test_uses_hash_with_string_keys_for_customers
    customers_string_keys = [
      {
        'customer_id' => 'cust_001',
        'customer_name' => 'Cliente A',
        'latitude' => -23.55052,
        'longitude' => -46.633308
      }
    ]

    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.today,
      customers: customers_string_keys
    )

    assert_equal 1, result.route_stops.size
    assert_equal 'cust_001', result.route_stops.first.customer_id
  end

  def test_creates_new_stops_for_added_customers
    # Cria uma parada inicial
    @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    # Atualiza com 3 clientes (mantém o primeiro e adiciona 2 novos)
    customers = [@customer_1, @customer_2, @customer_3]
    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.today,
      customers: customers
    )

    assert_equal 3, result.route_stops.size
    customer_ids = result.route_stops.ordered.map(&:customer_id)
    assert_equal %w[cust_001 cust_002 cust_003], customer_ids
  end

  def test_updates_estimate_fields_when_provided
    customers = [@customer_1, @customer_2]
    estimate = {
      distance_meters: 15_000,
      duration_seconds: 1800
    }

    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.today,
      customers: customers,
      estimate: estimate
    )

    assert_equal 15_000, result.estimated_distance_meters
    assert_equal 1800, result.estimated_duration_seconds
  end

  def test_calculates_target_completed_stops
    customers = 10.times.map do |i|
      {
        customer_id: "cust_#{i}",
        customer_name: "Cliente #{i}",
        latitude: -23.55052 + (i * 0.01),
        longitude: -46.633308 + (i * 0.01)
      }
    end

    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.today,
      customers: customers,
      target_completion_percent: 80
    )

    # 10 clientes * 80% = 8 paradas
    assert_equal 8, result.target_completed_stops
  end

  def test_defaults_route_name_to_date_format
    customers = [@customer_1]

    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.tomorrow,
      customers: customers,
      name: '' # força o padrão
    )

    assert_includes result.name, Date.tomorrow.to_s
  end

  def test_call_class_method_delegates_to_instance
    customers = [@customer_1]

    result = Routes::UpdateAssignment.call(
      route: @route,
      seller_uid: 'seller_123',
      due_date: Date.today,
      customers: customers
    )

    assert_equal @route.id, result.id
  end
end
