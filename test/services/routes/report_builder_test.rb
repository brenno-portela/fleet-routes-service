# frozen_string_literal: true

require 'test_helper'

class Routes::ReportBuilderTest < Minitest::Test
  def setup
    @base_date = Date.today

    # Cria rotas com diferentes status
    @route_completed = Route.create!(
      name: 'Rota Concluída',
      seller_uid: 'seller_001',
      seller_name: 'João Silva',
      seller_email: 'joao@teste.com',
      status: Route::STATUS_COMPLETED,
      due_date: @base_date,
      target_completion_percent: 90,
      state: 'SP',
      estimated_distance_meters: 50_000
    )

    @route_in_progress = Route.create!(
      name: 'Rota em Andamento',
      seller_uid: 'seller_002',
      seller_name: 'Maria Santos',
      seller_email: 'maria@teste.com',
      status: Route::STATUS_IN_PROGRESS,
      due_date: @base_date - 1.day,
      target_completion_percent: 90,
      state: 'RJ',
      estimated_distance_meters: 30_000
    )

    @route_planned = Route.create!(
      name: 'Rota Planejada',
      seller_uid: 'seller_001',
      seller_name: 'João Silva',
      status: Route::STATUS_PLANNED,
      due_date: @base_date + 1.day,
      target_completion_percent: 80,
      state: 'SP',
      estimated_distance_meters: 20_000
    )

    # Adiciona paradas à rota concluída
    @stop_visited = @route_completed.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_VISITED
    )

    @stop_not_visited = @route_completed.route_stops.create!(
      customer_id: 'cust_002',
      customer_name: 'Cliente B',
      latitude: -23.56052,
      longitude: -46.643308,
      order: 2,
      status: RouteStop::STATUS_NOT_VISITED
    )

    # Adiciona paradas à rota em andamento
    @stop_pending = @route_in_progress.route_stops.create!(
      customer_id: 'cust_003',
      customer_name: 'Cliente C',
      latitude: -23.57052,
      longitude: -46.653308,
      order: 1,
      status: RouteStop::STATUS_PENDING
    )

    # Adiciona frequências de visitação (stop_attendances)
    @attendance_completed = @stop_visited.stop_attendances.create!(
      check_in_at: Time.now - 2.hours,
      check_out_at: Time.now - 1.hour,
      status: StopAttendance::STATUS_VISITED
    )

    @attendance_not_visited = @stop_not_visited.stop_attendances.create!(
      check_in_at: Time.now,
      status: StopAttendance::STATUS_NOT_VISITED
    )
  end

  def test_aggregates_summary_kpis_correctly
    report = Routes::ReportBuilder.call

    summary = report[:summary]

    # Verifica contagens
    assert_equal 3, summary[:total_routes]
    assert_equal 1, summary[:completed_routes]

    # Verifica taxa de conclusão: 1 de 3 = 33.33%
    assert_in_delta 33.33, summary[:completion_rate_percent], 0.01

    # Verifica paradas
    assert_equal 3, summary[:total_stops]
    assert_equal 1, summary[:visited_stops]

    # Verifica cobertura de feedback: 2 paradas reportadas de 3 = 66.67%
    assert_in_delta 66.67, summary[:feedback_coverage_percent], 0.01

    # Verifica distância planejada
    total_planned = 50_000 + 30_000 + 20_000
    assert_equal total_planned.to_f, summary[:total_planned_distance_meters]

    # Verifica duração média
    assert_equal 3600, summary[:average_visit_duration_seconds]
  end

  def test_filters_by_date_range
    # Filtro por data exata
    report = Routes::ReportBuilder.call(filters: { date_from: @base_date, date_to: @base_date })
    assert_equal 2, report[:routes].count
    assert_equal 2, report[:summary][:total_routes]

    # Filtro por data anterior
    report = Routes::ReportBuilder.call(filters: { date_from: @base_date - 1.day, date_to: @base_date - 1.day })
    assert_equal 1, report[:routes].count
    assert_equal @route_in_progress.id, report[:routes].first.id

    # Filtro por data posterior
    report = Routes::ReportBuilder.call(filters: { date_from: @base_date + 1.day })
    assert_equal 1, report[:routes].count
    assert_equal @route_planned.id, report[:routes].first.id
  end

  def test_filters_by_status_and_seller
    # Filtro por status único
    report = Routes::ReportBuilder.call(filters: { status: Route::STATUS_COMPLETED })
    assert_equal 1, report[:routes].count
    assert_equal @route_completed.id, report[:routes].first.id

    # Filtro por status múltiplo
    report = Routes::ReportBuilder.call(
      filters: { status: [Route::STATUS_COMPLETED, Route::STATUS_PLANNED] }
    )
    assert_equal 2, report[:routes].count

    # Filtro por vendedor
    report = Routes::ReportBuilder.call(filters: { seller_uid: 'seller_001' })
    assert_equal 2, report[:routes].count
    report[:routes].each do |route|
      assert_equal 'seller_001', route.seller_uid
    end

    # Filtro por estado
    report = Routes::ReportBuilder.call(filters: { state: 'SP' })
    assert_equal 2, report[:routes].count
  end

  def test_groups_seller_performance_metrics
    report = Routes::ReportBuilder.call

    sellers = report[:sellers]
    assert_equal 2, sellers.count

    seller_001 = sellers.find { |s| s[:seller_uid] == 'seller_001' }
    seller_002 = sellers.find { |s| s[:seller_uid] == 'seller_002' }

    # Verifica seller_001: 2 rotas, 1 concluída
    assert_equal 'João Silva', seller_001[:seller_name]
    assert_equal 2, seller_001[:route_count]
    assert_equal 1, seller_001[:completed_route_count]

    # seller_001 tem 2 paradas (1 visited, 1 not_visited)
    assert_equal 2, seller_001[:total_stops]
    assert_equal 1, seller_001[:visited_stops]

    # Verifica seller_002: 1 rota, 0 concluídas
    assert_equal 'Maria Santos', seller_002[:seller_name]
    assert_equal 1, seller_002[:route_count]
    assert_equal 0, seller_002[:completed_route_count]
    assert_equal 1, seller_002[:total_stops]
    assert_equal 0, seller_002[:visited_stops]
  end

  def test_handles_empty_dataset_without_zero_division_errors
    # Limpa todas as rotas
    Route.destroy_all

    # Deve retornar um relatório sem erros
    report = Routes::ReportBuilder.call

    summary = report[:summary]
    assert_equal 0, summary[:total_routes]
    assert_equal 0, summary[:completed_routes]
    assert_equal 0.0, summary[:completion_rate_percent]
    assert_equal 0, summary[:total_stops]
    assert_equal 0, summary[:visited_stops]
    assert_equal 0.0, summary[:stop_completion_percent]
    assert_equal 0.0, summary[:feedback_coverage_percent]
    assert_equal 0.0, summary[:average_visit_duration_seconds]

    assert_empty report[:sellers]
    assert_empty report[:routes]
  end

  def test_filters_by_search_text
    report = Routes::ReportBuilder.call(filters: { search: 'Cliente A' })

    # Deve encontrar a rota que contém Cliente A
    assert_equal 1, report[:routes].count
    assert_equal @route_completed.id, report[:routes].first.id

    # Busca por nome de rota
    report = Routes::ReportBuilder.call(filters: { search: 'Concluída' })
    assert_equal 1, report[:routes].count
    assert_equal @route_completed.id, report[:routes].first.id
  end

  def test_eager_loads_associations
    # Verifica que as associações são carregadas
    report = Routes::ReportBuilder.call
    routes = report[:routes]

    # Não deve fazer query adicional ao acessar route_stops
    routes.each do |route|
      assert_includes route.association(:route_stops).loaded?, true
      assert_includes route.association(:stop_attendances).loaded?, true
      assert_includes route.association(:visit_events).loaded?, true
    end
  end

  def test_call_class_method_delegates_to_instance
    report = Routes::ReportBuilder.call(filters: { status: Route::STATUS_COMPLETED })

    assert_equal 1, report[:routes].count
    assert report[:summary].is_a?(Hash)
    assert report[:sellers].is_a?(Array)
  end

  def test_handles_routes_without_stops
    # Cria uma rota sem paradas
    route_empty = Route.create!(
      name: 'Rota Vazia',
      seller_uid: 'seller_003',
      seller_name: 'Pedro Costa',
      status: Route::STATUS_ASSIGNED,
      due_date: @base_date,
      target_completion_percent: 90,
      state: 'MG'
    )

    report = Routes::ReportBuilder.call

    summary = report[:summary]
    # Total de 4 rotas agora (3 + 1 nova)
    assert_equal 4, summary[:total_routes]
    # Total de 3 paradas ainda (rota vazia não tem paradas)
    assert_equal 3, summary[:total_stops]
  end

  def test_calculates_completion_rates_correctly
    # Cria uma rota com 4 paradas, 3 visitadas
    route = Route.create!(
      name: 'Rota Teste Taxa',
      seller_uid: 'seller_test',
      seller_name: 'Teste',
      status: Route::STATUS_IN_PROGRESS,
      due_date: @base_date,
      target_completion_percent: 90,
      state: 'SP'
    )

    3.times do |i|
      route.route_stops.create!(
        customer_id: "cust_test_#{i}",
        customer_name: "Cliente Teste #{i}",
        latitude: -23.55052 + (i * 0.01),
        longitude: -46.633308,
        order: i + 1,
        status: RouteStop::STATUS_VISITED
      )
    end

    route.route_stops.create!(
      customer_id: 'cust_test_not_visited',
      customer_name: 'Cliente Não Visitado',
      latitude: -23.58052,
      longitude: -46.633308,
      order: 4,
      status: RouteStop::STATUS_PENDING
    )

    report = Routes::ReportBuilder.call(filters: { seller_uid: 'seller_test' })

    summary = report[:summary]
    # 3 visitadas de 4 = 75%
    assert_in_delta 75.0, summary[:stop_completion_percent], 0.01
  end
end
