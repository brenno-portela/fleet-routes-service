# frozen_string_literal: true

require 'caxlsx'

module Routes
  # Serviço para exportar relatórios de rotas em formato Excel (XLSX) usando caxlsx.
  # Cria workbook com 4 sheets estilizados: Resumo Executivo, Rotas, Paradas e Clientes, Desempenho Vendedores.
  class ExcelExporter
    # Paleta de cores da marca
    COLOR_PRIMARY = 'FF00463A'        # Brand Primary (dark teal)
    COLOR_ACCENT = 'FF00D2AE'         # Energy Teal
    COLOR_LIGHT = 'FFA4E0CE'          # Light
    COLOR_WHITE = 'FFFFFFFF'          # White
    COLOR_GRAY = 'FFF5F5F5'           # Light gray background

    def self.call(report:, filter_labels: [])
      new.call(report: report, filter_labels: filter_labels)
    end

    def call(report:, filter_labels: [])
      @report = report
      @filter_labels = filter_labels

      package = Axlsx::Package.new
      workbook = package.workbook

      build_summary_sheet(workbook)
      build_routes_sheet(workbook)
      build_stops_sheet(workbook)
      build_sellers_sheet(workbook)

      package.to_stream.read
    end

    private

    def build_summary_sheet(workbook)
      workbook.add_worksheet(name: 'Resumo Executivo') do |sheet|
        # Header com filtros e data de geração
        sheet.add_row ['RELATÓRIO DE ROTAS', nil, nil, nil, nil, nil]
        sheet.merge_cells 'A1:F1'
        sheet['A1'].style = header_style

        sheet.add_row ["Data de Geração: #{Time.now.strftime('%d/%m/%Y %H:%M')}"]
        sheet.add_row ["Filtros Aplicados: #{@filter_labels.join(', ')}"] if @filter_labels.any?
        sheet.add_row [] # linha em branco

        # KPI cards
        kpi_data = [
          ['Total de Rotas', @report[:summary][:total_routes]],
          ['Rotas Concluídas', @report[:summary][:completed_routes]],
          ['Taxa de Conclusão (%)', format_percent(@report[:summary][:completion_rate_percent])],
          ['Total de Paradas', @report[:summary][:total_stops]],
          ['Cobertura de Feedbacks (%)', format_percent(@report[:summary][:feedback_coverage_percent])],
          ['Distância Total Percorrida (km)', format_distance(@report[:summary][:total_actual_distance_meters])]
        ]

        sheet.add_row ['INDICADORES-CHAVE (KPIs)']
        sheet.merge_cells "A#{sheet.rows.count}:B#{sheet.rows.count}"
        sheet["A#{sheet.rows.count}"].style = subheader_style

        kpi_data.each do |label, value|
          sheet.add_row [label, value]
          current_row = sheet.rows.count
          sheet["A#{current_row}"].style = kpi_label_style
          sheet["B#{current_row}"].style = kpi_value_style
        end

        # Auto-adjust column widths
        sheet.column_widths 40, 20
      end
    end

    def build_routes_sheet(workbook)
      workbook.add_worksheet(name: 'Rotas') do |sheet|
        headers = [
          'ID', 'Nome da Rota', 'Vendedor', 'Estado', 'Prazo', 'Status',
          'Meta (%)', 'Conclusão (%)', 'Total Paradas', 'Paradas Visitadas',
          'Distância Planejada (km)', 'Distância Percorrida (km)', 'Variância GPS (%)',
          'Duração em Rota', 'Observações'
        ]

        sheet.add_row headers
        header_row = sheet.rows.count
        style_header_row(sheet, header_row, headers.count)

        @report[:routes].each do |route|
          stops = route.route_stops
          visited_stops = stops.count { |s| s.status == RouteStop::STATUS_VISITED }
          total_stops = stops.count

          planned_distance_km = format_distance(route.estimated_distance_meters)
          completion_percent = total_stops.zero? ? 0 : ((visited_stops.to_f / total_stops) * 100).round(2)

          duration = route.route_stops.flat_map(&:stop_attendances).sum(&:visit_duration_seconds)
          duration_formatted = format_duration(duration)

          sheet.add_row [
            route.id,
            route.name,
            route.seller_name,
            route.state,
            route.due_date&.strftime('%d/%m/%Y'),
            route.status,
            route.target_completion_percent,
            completion_percent,
            total_stops,
            visited_stops,
            planned_distance_km,
            0.0,
            0.0,
            duration_formatted,
            route.assignment_notes
          ]
        end

        # Auto-adjust column widths
        sheet.column_widths 8, 20, 15, 8, 12, 15, 10, 12, 12, 15, 18, 18, 15, 15, 30
      end
    end

    def build_stops_sheet(workbook)
      workbook.add_worksheet(name: 'Paradas e Clientes') do |sheet|
        headers = [
          'ID Rota', 'Nome Rota', 'Vendedor', 'Ordem', 'ID Cliente', 'Nome Cliente',
          'CNPJ/CPF', 'Cidade', 'UF', 'Check-in', 'Checkout', 'Duração Atendimento',
          'Status', 'Motivo Não Visita', 'Feedback', 'Distância do Cliente (Auditoria GPS)'
        ]

        sheet.add_row headers
        header_row = sheet.rows.count
        style_header_row(sheet, header_row, headers.count)

        @report[:routes].each do |route|
          route.route_stops.ordered.each do |stop|
            latest_attendance = stop.latest_attendance

            check_in = latest_attendance&.check_in_at&.strftime('%d/%m/%Y %H:%M')
            check_out = latest_attendance&.check_out_at&.strftime('%d/%m/%Y %H:%M')
            duration = latest_attendance&.visit_duration_seconds ?
              format_duration(latest_attendance.visit_duration_seconds) : '-'

            sheet.add_row [
              route.id,
              route.name,
              route.seller_name,
              stop.order,
              stop.customer_id,
              stop.customer_name,
              stop.cnpj_cpf,
              stop.city,
              stop.state,
              check_in,
              check_out,
              duration,
              stop.status,
              stop.not_visited_reason,
              stop.feedback,
              stop.check_in_distance_meters ? "#{stop.check_in_distance_meters.round(2)}" : '-'
            ]
          end
        end

        # Auto-adjust column widths
        sheet.column_widths 10, 20, 15, 8, 12, 20, 15, 15, 6, 18, 18, 18, 15, 15, 20, 20
      end
    end

    def build_sellers_sheet(workbook)
      workbook.add_worksheet(name: 'Desempenho Vendedores') do |sheet|
        headers = [
          'Vendedor', 'Total de Rotas', 'Rotas Concluídas', 'Taxa Conclusão Rotas (%)',
          'Total Paradas', 'Paradas Visitadas', 'Eficácia Visitas (%)', 'Tempo Médio por Visita'
        ]

        sheet.add_row headers
        header_row = sheet.rows.count
        style_header_row(sheet, header_row, headers.count)

        @report[:sellers].each do |seller|
          completion_rate = seller[:route_count].zero? ? 0 :
            ((seller[:completed_route_count].to_f / seller[:route_count]) * 100).round(2)

          visit_effectiveness = seller[:total_stops].zero? ? 0 :
            ((seller[:visited_stops].to_f / seller[:total_stops]) * 100).round(2)

          avg_duration = format_duration(seller[:average_visit_duration_seconds])

          sheet.add_row [
            seller[:seller_name],
            seller[:route_count],
            seller[:completed_route_count],
            completion_rate,
            seller[:total_stops],
            seller[:visited_stops],
            visit_effectiveness,
            avg_duration
          ]
        end

        # Auto-adjust column widths
        sheet.column_widths 20, 15, 15, 22, 15, 18, 18, 20
      end
    end

    def header_style
      Axlsx::Style.new(
        bg_color: COLOR_PRIMARY,
        fg_color: COLOR_WHITE,
        b: true,
        alignment: { horizontal: :center, vertical: :center },
        border: Axlsx::Border.new(style: :thin)
      )
    end

    def subheader_style
      Axlsx::Style.new(
        bg_color: COLOR_ACCENT,
        fg_color: COLOR_WHITE,
        b: true,
        alignment: { horizontal: :left, vertical: :center },
        border: Axlsx::Border.new(style: :thin)
      )
    end

    def kpi_label_style
      Axlsx::Style.new(
        bg_color: COLOR_LIGHT,
        fg_color: COLOR_PRIMARY,
        b: true,
        alignment: { horizontal: :left, vertical: :center },
        border: Axlsx::Border.new(style: :thin)
      )
    end

    def kpi_value_style
      Axlsx::Style.new(
        bg_color: COLOR_GRAY,
        alignment: { horizontal: :center, vertical: :center },
        border: Axlsx::Border.new(style: :thin),
        num_fmt: 0
      )
    end

    def style_header_row(sheet, row_num, col_count)
      (1..col_count).each do |col_idx|
        cell = sheet.rows[row_num - 1].cells[col_idx - 1]
        cell.style = header_style
      end
    end

    def format_percent(value)
      return '0.00%' if value.zero?

      "#{value.round(2)}%"
    end

    def format_distance(meters)
      return '0.00' if meters.nil? || meters.zero?

      (meters.to_f / 1000).round(2)
    end

    def format_duration(seconds)
      return '-' if seconds.nil? || seconds.zero?

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      secs = seconds % 60

      "#{hours}h#{minutes}m#{secs}s"
    end

    def calculate_gps_variance(planned, actual)
      return '0.00%' if planned.nil? || planned.zero? || actual.nil?

      variance = ((actual.to_f - planned.to_f) / planned.to_f * 100).round(2)
      "#{variance}%"
    end
  end
end
