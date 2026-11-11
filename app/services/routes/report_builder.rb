# frozen_string_literal: true

module Routes
  # Serviço para construir relatórios analíticos de rotas com cálculo de KPIs.
  # Aplica filtros, agrega dados de rotas/paradas/frequências e calcula métricas por vendedor.
  class ReportBuilder
    def self.call(filters: {})
      new.call(filters: filters)
    end

    def call(filters: {})
      routes = fetch_and_filter_routes(filters)

      {
        routes: routes,
        summary: build_summary(routes),
        sellers: build_seller_metrics(routes)
      }
    end

    private

    def fetch_and_filter_routes(filters)
      query = Route.includes(:route_stops, :stop_attendances, :visit_events)

      # Filtro por intervalo de datas
      if filters[:date_from].present?
        query = query.where('routes.due_date >= ?', parse_date(filters[:date_from]))
      end
      if filters[:date_to].present?
        query = query.where('routes.due_date <= ?', parse_date(filters[:date_to]))
      end

      # Filtro por status (single ou list)
      if filters[:status].present?
        statuses = Array(filters[:status])
        query = query.where(status: statuses)
      end

      # Filtro por vendedor
      if filters[:seller_uid].present?
        query = query.where(seller_uid: filters[:seller_uid])
      end

      # Filtro por estado (UF)
      if filters[:state].present?
        query = query.where(state: filters[:state].to_s.upcase)
      end

      # Filtro por tipo de rota (não implementado neste escopo, mas reservado)
      # if filters[:route_type].present? && filters[:route_type] != 'all'
      #   # Lógica específica de tipo
      # end

      # Filtro por busca (case-insensitive)
      if filters[:search].present?
        search_term = "%#{filters[:search]}%"
        query = query.where(
          'routes.name ILIKE ? OR EXISTS (SELECT 1 FROM route_stops WHERE route_stops.route_id = routes.id AND route_stops.customer_name ILIKE ?)',
          search_term,
          search_term
        )
      end

      query.order(created_at: :desc)
    end

    def parse_date(date_value)
      return date_value if date_value.is_a?(Date)
      return date_value.to_date if date_value.is_a?(Time)

      Date.parse(date_value.to_s)
    end

    def build_summary(routes)
      total_routes = routes.count
      completed_routes = routes.count { |r| Route::EXECUTED_STATUSES.include?(r.status) }

      all_stops = routes.flat_map(&:route_stops)
      total_stops = all_stops.count
      visited_stops = all_stops.count { |s| s.status == RouteStop::STATUS_VISITED }
      reported_stops = all_stops.count { |s| RouteStop::EXECUTED_STATUSES.include?(s.status) }

      all_attendances = routes.flat_map(&:stop_attendances)
      total_planned_distance = routes.sum { |r| r.estimated_distance_meters.to_f }

      average_duration = all_attendances.any? ?
        (all_attendances.sum(&:visit_duration_seconds).to_f / all_attendances.count).round : 0

      {
        total_routes: total_routes,
        completed_routes: completed_routes,
        completion_rate_percent: safe_division(completed_routes * 100.0, total_routes),
        total_stops: total_stops,
        visited_stops: visited_stops,
        stop_completion_percent: safe_division(visited_stops * 100.0, total_stops),
        feedback_coverage_percent: safe_division(reported_stops * 100.0, total_stops),
        total_planned_distance_meters: total_planned_distance,
        average_visit_duration_seconds: average_duration.to_i
      }
    end

    def build_seller_metrics(routes)
      sellers_hash = {}

      routes.each do |route|
        seller_uid = route.seller_uid
        seller_name = route.seller_name

        if sellers_hash[seller_uid].nil?
          sellers_hash[seller_uid] = {
            seller_uid: seller_uid,
            seller_name: seller_name,
            route_count: 0,
            completed_route_count: 0,
            total_stops: 0,
            visited_stops: 0,
            visit_durations: []
          }
        end

        seller_data = sellers_hash[seller_uid]
        seller_data[:route_count] += 1
        seller_data[:completed_route_count] += 1 if Route::EXECUTED_STATUSES.include?(route.status)

        route.route_stops.each do |stop|
          seller_data[:total_stops] += 1
          seller_data[:visited_stops] += 1 if stop.status == RouteStop::STATUS_VISITED

          stop.stop_attendances.each do |attendance|
            seller_data[:visit_durations] << attendance.visit_duration_seconds if attendance.visit_duration_seconds.present?
          end
        end
      end

      sellers_hash.values.map do |seller_data|
        avg_duration = seller_data[:visit_durations].any? ?
          (seller_data[:visit_durations].sum.to_f / seller_data[:visit_durations].count).round : 0

        {
          seller_uid: seller_data[:seller_uid],
          seller_name: seller_data[:seller_name],
          route_count: seller_data[:route_count],
          completed_route_count: seller_data[:completed_route_count],
          total_stops: seller_data[:total_stops],
          visited_stops: seller_data[:visited_stops],
          completion_percent: safe_division(seller_data[:visited_stops] * 100.0, seller_data[:total_stops]),
          average_visit_duration_seconds: avg_duration.to_i
        }
      end
    end

    def safe_division(numerator, denominator)
      return 0.0 if denominator.zero? || numerator.zero?

      (numerator / denominator).round(2)
    end
  end
end
