# frozen_string_literal: true

require 'test_helper'

class Api::V1::RoutesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @base_date = Date.today

    @route_1 = Route.create!(
      name: 'Rota Centro',
      seller_uid: 'seller_001',
      seller_name: 'João Silva',
      seller_email: 'joao@teste.com',
      status: Route::STATUS_ASSIGNED,
      due_date: @base_date,
      target_completion_percent: 90,
      state: 'SP'
    )

    @route_2 = Route.create!(
      name: 'Rota Litoral',
      seller_uid: 'seller_002',
      seller_name: 'Maria Santos',
      seller_email: 'maria@teste.com',
      status: Route::STATUS_IN_PROGRESS,
      due_date: @base_date - 1.day,
      target_completion_percent: 85,
      state: 'RJ'
    )

    @stop_1 = @route_1.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_VISITED
    )

    @stop_2 = @route_1.route_stops.create!(
      customer_id: 'cust_002',
      customer_name: 'Cliente B',
      latitude: -23.56052,
      longitude: -46.643308,
      order: 2,
      status: RouteStop::STATUS_PENDING
    )

    @attendance_1 = @stop_1.stop_attendances.create!(
      check_in_at: Time.now - 2.hours,
      check_out_at: Time.now - 1.hour,
      status: StopAttendance::STATUS_VISITED
    )
  end

  def test_index_lists_routes_with_filters
    # Teste sem filtros
    get '/api/v1/routes'
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json.length

    # Filtro por status
    get '/api/v1/routes?status=assigned'
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal 'Rota Centro', json[0]['name']

    # Filtro por seller
    get '/api/v1/routes?seller_uid=seller_002'
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal 'Rota Litoral', json[0]['name']

    # Filtro por estado
    get '/api/v1/routes?state=SP'
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal 'SP', json[0]['state']
  end

  def test_show_returns_route_with_stops_and_telemetry
    get "/api/v1/routes/#{@route_1.id}"
    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal @route_1.id, json['id']
    assert_equal 'Rota Centro', json['name']
    assert_equal 'João Silva', json['seller_name']

    # Verifica presença de stops
    assert_not_empty json['stops']
    assert_equal 2, json['stops'].length
    assert_equal 'cust_001', json['stops'][0]['customer_id']

    # Verifica presença de attendances
    assert_not_empty json['attendances']

    # Verifica presença de telemetry
    assert_not_nil json['telemetry']
    assert json['telemetry'].key?('total_visit_duration_seconds')
  end

  def test_show_returns_404_for_non_existent_route
    get '/api/v1/routes/99999'
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not_nil json['error']
  end

  def test_update_modifies_route_successfully
    update_params = {
      route: {
        name: 'Rota Centro Atualizada',
        seller_uid: 'seller_001',
        due_date: @base_date + 1.day,
        target_completion_percent: 80,
        customers: [
          {
            customer_id: 'cust_001',
            customer_name: 'Cliente A',
            latitude: -23.55052,
            longitude: -46.633308
          }
        ]
      }
    }

    patch "/api/v1/routes/#{@route_1.id}", params: update_params, as: :json,
          headers: { 'X-User-UID' => 'user_123', 'X-User-Name' => 'Admin' }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 'Rota Centro Atualizada', json['name']
    assert_equal 80, json['target_completion_percent']
    assert_equal (@base_date + 1.day).strftime('%Y-%m-%d'), json['due_date']
  end

  def test_update_returns_403_or_422_when_audit_lock_triggered
    # Marca a rota como visitada (ativa audit lock)
    @route_1.update!(status: Route::STATUS_IN_PROGRESS)
    @stop_1.update!(status: RouteStop::STATUS_VISITED)

    # Tenta atualizar paradas (deve falhar por audit lock)
    update_params = {
      route: {
        seller_uid: 'seller_001',
        due_date: @base_date,
        customers: [
          {
            customer_id: 'cust_999',
            customer_name: 'Cliente Novo',
            latitude: -23.55052,
            longitude: -46.633308
          }
        ]
      }
    }

    patch "/api/v1/routes/#{@route_1.id}", params: update_params, as: :json

    # Deve retornar 422 (unprocessable_entity)
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json['error']
    assert_includes json['error'].downcase, 'auditoria'
  end

  def test_destroy_removes_route_and_associated_stops
    route_id = @route_1.id
    stop_id = @stop_1.id

    delete "/api/v1/routes/#{route_id}", as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal true, json['success']

    # Verifica que a rota foi deletada
    assert_nil Route.find_by(id: route_id)
    assert_nil RouteStop.find_by(id: stop_id)
  end

  def test_index_filters_by_date_range
    new_route = Route.create!(
      name: 'Rota Futura',
      seller_uid: 'seller_001',
      status: Route::STATUS_PLANNED,
      due_date: @base_date + 5.days,
      target_completion_percent: 90,
      state: 'SP'
    )

    get "/api/v1/routes?date_from=#{@base_date}&date_to=#{@base_date}"
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @route_1.id, json[0]['id']
  end

  def test_index_filters_by_search
    get '/api/v1/routes?search=Centro'
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal 'Rota Centro', json[0]['name']
  end

  def test_index_respects_limit_parameter
    get '/api/v1/routes?limit=1'
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 1, json.length
  end

  def test_index_includes_completion_metrics
    get '/api/v1/routes'
    assert_response :ok
    json = JSON.parse(response.body)

    route_json = json.find { |r| r['id'] == @route_1.id }
    assert_not_nil route_json
    assert_not_nil route_json['stops_count']
    assert_not_nil route_json['visited_stops_count']
    assert_not_nil route_json['completion_percent']
  end

  def test_show_includes_iso8601_timestamps
    get "/api/v1/routes/#{@route_1.id}"
    assert_response :ok
    json = JSON.parse(response.body)

    # Verifica formato ISO8601
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, json['created_at']
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, json['updated_at']
  end

  def test_update_with_invalid_assignment_returns_422
    update_params = {
      route: {
        seller_uid: 'seller_001',
        due_date: @base_date,
        customers: [] # Vazio é inválido
      }
    }

    patch "/api/v1/routes/#{@route_1.id}", params: update_params, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json['error']
  end

  def test_update_with_missing_route_parameter_returns_400
    patch "/api/v1/routes/#{@route_1.id}", params: {}, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not_nil json['error']
  end

  def test_show_includes_stops_ordered_by_order
    get "/api/v1/routes/#{@route_1.id}"
    assert_response :ok
    json = JSON.parse(response.body)

    stops = json['stops']
    assert_equal 2, stops.length
    assert_equal 1, stops[0]['order']
    assert_equal 2, stops[1]['order']
  end
end
