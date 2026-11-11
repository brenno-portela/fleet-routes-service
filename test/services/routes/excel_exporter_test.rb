# frozen_string_literal: true

require 'test_helper'

class Routes::ExcelExporterTest < Minitest::Test
  def setup
    @base_date = Date.today

    # Cria rota com paradas
    @route = Route.create!(
      name: 'Rota para Excel',
      seller_uid: 'seller_001',
      seller_name: 'João Silva',
      seller_email: 'joao@teste.com',
      status: Route::STATUS_COMPLETED,
      due_date: @base_date,
      target_completion_percent: 90,
      state: 'SP',
      estimated_distance_meters: 50_000,
      assignment_notes: 'Notas importantes'
    )

    @stop = @route.route_stops.create!(
      customer_id: 'cust_001',
      customer_name: 'Cliente A',
      latitude: -23.55052,
      longitude: -46.633308,
      order: 1,
      status: RouteStop::STATUS_VISITED
    )

    @attendance = @stop.stop_attendances.create!(
      check_in_at: Time.now - 2.hours,
      check_out_at: Time.now - 1.hour,
      status: StopAttendance::STATUS_VISITED
    )

    # Gera o relatório para usar nos testes
    @report = Routes::ReportBuilder.call
  end

  def test_generates_valid_xlsx_binary_stream
    excel_binary = Routes::ExcelExporter.call(report: @report)

    # Verifica que é um binary string (bytes)
    assert_instance_of String, excel_binary
    assert excel_binary.bytesize > 0

    # Verifica assinatura de arquivo XLSX (PK para ZIP)
    assert_equal 'PK', excel_binary[0..1]
  end

  def test_contains_four_required_sheets
    excel_binary = Routes::ExcelExporter.call(report: @report)

    # Salva temporariamente para leitura
    require 'tempfile'
    temp_file = Tempfile.new(['report', '.xlsx'], encoding: 'ASCII-8BIT')
    temp_file.write(excel_binary)
    temp_file.close

    begin
      # Carrega o workbook com caxlsx_reader
      require 'caxlsx_reader'
      doc = CaxlsxReader::Document.new(temp_file.path)

      sheet_names = doc.sheets.map(&:name)

      assert_equal 4, sheet_names.count
      assert_includes sheet_names, 'Resumo Executivo'
      assert_includes sheet_names, 'Rotas'
      assert_includes sheet_names, 'Paradas e Clientes'
      assert_includes sheet_names, 'Desempenho Vendedores'
    ensure
      temp_file.unlink
    end
  end

  def test_populates_data_and_styles_without_exceptions
    # Testa que a exportação não lança exceções
    assert_nothing_raised do
      Routes::ExcelExporter.call(
        report: @report,
        filter_labels: ['SP', 'Data: 01/01/2024', 'Vendedor: João']
      )
    end
  end

  def test_exports_with_filter_labels
    filter_labels = ['Estado: SP', 'Status: Concluído']

    excel_binary = Routes::ExcelExporter.call(
      report: @report,
      filter_labels: filter_labels
    )

    assert excel_binary.bytesize > 0

    # Verifica que é um XLSX válido
    assert_equal 'PK', excel_binary[0..1]
  end

  def test_exports_empty_report
    empty_report = Routes::ReportBuilder.call(filters: { seller_uid: 'non_existent' })

    excel_binary = Routes::ExcelExporter.call(report: empty_report)

    assert excel_binary.bytesize > 0
    assert_equal 'PK', excel_binary[0..1]
  end

  def test_summary_sheet_includes_kpis
    excel_binary = Routes::ExcelExporter.call(report: @report)

    require 'tempfile'
    temp_file = Tempfile.new(['report', '.xlsx'], encoding: 'ASCII-8BIT')
    temp_file.write(excel_binary)
    temp_file.close

    begin
      require 'caxlsx_reader'
      doc = CaxlsxReader::Document.new(temp_file.path)
      sheet = doc.sheets.find { |s| s.name == 'Resumo Executivo' }

      # Verifica que o sheet existe
      assert_not_nil sheet

      # Verifica que contém dados de KPI
      rows = sheet.rows
      kpi_text = rows.flatten.join(' ')

      assert_includes kpi_text, 'Total de Rotas'
      assert_includes kpi_text, 'Rotas Concluídas'
    ensure
      temp_file.unlink
    end
  end

  def test_routes_sheet_includes_headers
    excel_binary = Routes::ExcelExporter.call(report: @report)

    require 'tempfile'
    temp_file = Tempfile.new(['report', '.xlsx'], encoding: 'ASCII-8BIT')
    temp_file.write(excel_binary)
    temp_file.close

    begin
      require 'caxlsx_reader'
      doc = CaxlsxReader::Document.new(temp_file.path)
      sheet = doc.sheets.find { |s| s.name == 'Rotas' }

      # Verifica que o sheet existe
      assert_not_nil sheet

      # Verifica que contém headers esperados
      rows = sheet.rows
      header_row = rows.first
      header_text = header_row.join(' ')

      assert_includes header_text, 'Rota'
      assert_includes header_text, 'Vendedor'
    ensure
      temp_file.unlink
    end
  end

  def test_stops_sheet_includes_data
    excel_binary = Routes::ExcelExporter.call(report: @report)

    require 'tempfile'
    temp_file = Tempfile.new(['report', '.xlsx'], encoding: 'ASCII-8BIT')
    temp_file.write(excel_binary)
    temp_file.close

    begin
      require 'caxlsx_reader'
      doc = CaxlsxReader::Document.new(temp_file.path)
      sheet = doc.sheets.find { |s| s.name == 'Paradas e Clientes' }

      # Verifica que o sheet existe
      assert_not_nil sheet

      rows = sheet.rows
      data_text = rows.flatten.join(' ')

      # Verifica que contém dados dos clientes
      assert_includes data_text, 'Cliente A'
    ensure
      temp_file.unlink
    end
  end

  def test_sellers_sheet_includes_metrics
    excel_binary = Routes::ExcelExporter.call(report: @report)

    require 'tempfile'
    temp_file = Tempfile.new(['report', '.xlsx'], encoding: 'ASCII-8BIT')
    temp_file.write(excel_binary)
    temp_file.close

    begin
      require 'caxlsx_reader'
      doc = CaxlsxReader::Document.new(temp_file.path)
      sheet = doc.sheets.find { |s| s.name == 'Desempenho Vendedores' }

      # Verifica que o sheet existe
      assert_not_nil sheet

      rows = sheet.rows
      data_text = rows.flatten.join(' ')

      # Verifica que contém nome do vendedor
      assert_includes data_text, 'João Silva'
    ensure
      temp_file.unlink
    end
  end

  def test_call_class_method_delegates_to_instance
    excel_binary = Routes::ExcelExporter.call(report: @report)

    assert_instance_of String, excel_binary
    assert excel_binary.bytesize > 0
    assert_equal 'PK', excel_binary[0..1]
  end
end
