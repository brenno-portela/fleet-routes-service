# frozen_string_literal: true

require 'test_helper'

class Api::V1::RouteReportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @base_date = Date.today

    @route_1 = Route.create!(
      name: 'Rota Centro',
      seller_uid: 'seller_001',
      seller_name: 'João Silva',
      status: Route::STATUS_COMPLETED,
      due_date: @base_date,
      target_completion_percent: 90,
      state: 'SP',
      estimated_distance_meters: 50_000
    )

    @route_2 = Route.create!(
      name: 'Rota Litoral',
      seller_uid: 'seller_002',
      seller_name: 'Maria Santos',
      status: Route::STATUS_PLANNED,
      due_date: @base_date + 1.day,
      target_completion_percent: 80,
      state: 'RJ',
      estimated_distance_meters: 30_000
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

    @attendance = @stop_1.stop_attendances.create!(
      check_in_at: Time.now - 2.hours,
      check_out_at: Time.now - 1.hour,
      status: StopAttendance::STATUS_VISITED
    )
  end

  def test_report_returns_summary_kpi_json
    get '/api/v1/routes/report'
    assert_response :ok
    json = JSON.parse(response.body)

    # Verifica estrutura do relatório
    assert_not_nil json['summary']
    assert_not_nil json['sellers']
    assert_not_nil json['routes_count']

    # Verifica KPIs no summary
    summary = json['summary']
    assert_not_nil summary['total_routes']
    assert_not_nil summary['completed_routes']
    assert_not_nil summary['completion_rate_percent']
    assert_not_nil summary['total_stops']
    assert_not_nil summary['visited_stops']

    # Verifica que sellers está presente
    assert_instance_of Array, json['sellers']
    assert_equal 2, json['sellers'].length

    # Verifica contagem de rotas
    assert_equal 2, json['routes_count']
  end

  def test_report_filters_by_status
    get '/api/v1/routes/report?status=completed'
    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 1, json['routes_count']
    assert_equal 1, json['summary']['total_routes']
  end

  def test_report_filters_by_seller
    get '/api/v1/routes/report?seller_uid=seller_001'
    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 1, json['routes_count']
    sellers = json['sellers']
    assert_equal 1, sellers.length
    assert_equal 'seller_001', sellers[0]['seller_uid']
  end

  def test_report_filters_by_state
    get '/api/v1/routes/report?state=SP'
    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 1, json['routes_count']
  end

  def test_export_streams_excel_spreadsheet_attachment
    get '/api/v1/routes/export'
    assert_response :ok

    # Verifica headers de content-type e disposition
    assert_equal 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', response.content_type
    assert_includes response.headers['Content-Disposition'], 'attachment'
    assert_includes response.headers['Content-Disposition'], 'relatorio_rotas_'
    assert_includes response.headers['Content-Disposition'], '.xlsx'

    # Verifica que o body é um binary stream (XLSX é ZIP)
    assert_equal 'PK', response.body[0..1]
  end

  def test_export_with_filters
    get "/api/v1/routes/export?status=completed&state=SP"
    assert_response :ok

    # Verifica que é um arquivo XLSX válido
    assert_equal 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', response.content_type
    assert_equal 'PK', response.body[0..1]

    # Verifica filename
    filename = response.headers['Content-Disposition']
    assert_includes filename, 'relatorio_rotas_'
  end

  def test_report_includes_seller_metrics
    get '/api/v1/routes/report'
    assert_response :ok
    json = JSON.parse(response.body)

    sellers = json['sellers']
    assert_equal 2, sellers.length

    seller_1 = sellers.find { |s| s['seller_uid'] == 'seller_001' }
    assert_not_nil seller_1
    assert_not_nil seller_1['route_count']
    assert_not_nil seller_1['completed_route_count']
    assert_not_nil seller_1['completion_percent']
  end

  def test_report_empty_dataset
    Route.destroy_all

    get '/api/v1/routes/report'
    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 0, json['routes_count']
    assert_equal 0, json['summary']['total_routes']
    assert_empty json['sellers']
  end

  def test_export_filename_includes_date
    today = Date.today.strftime('%Y%m%d')

    get '/api/v1/routes/export'
    assert_response :ok

    filename = response.headers['Content-Disposition']
    assert_includes filename, today
  end

  def test_report_with_multiple_filters
    get "/api/v1/routes/report?status=completed&seller_uid=seller_001&state=SP"
    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 1, json['routes_count']
    assert_equal 1, json['summary']['total_routes']
  end

  def test_report_calculates_completion_rate
    get '/api/v1/routes/report'
    assert_response :ok
    json = JSON.parse(response.body)

    summary = json['summary']
    # 1 rota concluída de 2 = 50%
    assert_in_delta 50.0, summary['completion_rate_percent'], 0.01
  end

  def test_report_filters_by_date_range
    get "/api/v1/routes/report?date_from=#{@base_date}&date_to=#{@base_date}"
    assert_response :ok
    json = JSON.parse(response.body)

    # Deve retornar apenas a rota de hoje
    assert_equal 1, json['routes_count']
  end

  def test_export_is_valid_xlsx_file
    get '/api/v1/routes/export'
    assert_response :ok

    # Testa que o arquivo é um ZIP válido (XLSX = ZIP)
    body = response.body
    assert_equal 'PK', body[0..1], 'File should be a ZIP/XLSX file'
  end

  def test_report_summary_includes_all_required_fields
    get '/api/v1/routes/report'
    assert_response :ok
    json = JSON.parse(response.body)

    summary = json['summary']
    required_fields = [
      'total_routes', 'completed_routes', 'completion_rate_percent',
      'total_stops', 'visited_stops', 'stop_completion_percent',
      'feedback_coverage_percent', 'total_planned_distance_meters',
      'average_visit_duration_seconds'
    ]

    required_fields.each do |field|
      assert_not_nil summary[field], "Missing field: #{field}"
    end
  end
end
