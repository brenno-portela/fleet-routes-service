# frozen_string_literal: true

module Api
  module V1
    # Controller para endpoints de relatórios e exportação Excel
    class RouteReportsController < BaseController
      def show
        filters = build_filter_params
        report = Routes::ReportBuilder.call(filters: filters)

        response_json = {
          summary: report[:summary],
          sellers: report[:sellers],
          routes_count: report[:routes].count
        }

        render json: response_json, status: :ok
      end

      def export
        filters = build_filter_params
        filter_labels = build_filter_labels(filters)

        report = Routes::ReportBuilder.call(filters: filters)
        excel_binary = Routes::ExcelExporter.call(report: report, filter_labels: filter_labels)

        send_data excel_binary,
                  filename: "relatorio_rotas_#{Date.today.strftime('%Y%m%d')}.xlsx",
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment'
      end

      private

      def build_filter_params
        params.permit(:date_from, :date_to, :status, :seller_uid, :state, :route_type, :search).to_h.symbolize_keys
      end

      def build_filter_labels(filters)
        labels = []
        labels << "Estado: #{filters[:state]}" if filters[:state].present?
        labels << "Vendedor: #{filters[:seller_uid]}" if filters[:seller_uid].present?
        labels << "Status: #{filters[:status]}" if filters[:status].present?
        labels << "De: #{filters[:date_from]}" if filters[:date_from].present?
        labels << "Até: #{filters[:date_to]}" if filters[:date_to].present?
        labels << "Busca: #{filters[:search]}" if filters[:search].present?
        labels
      end
    end
  end
end
