# frozen_string_literal: true

require_relative 'errors'

module Routes
  # Serviço para deletar rotas com integridade transacional e lock pessimista.
  # Cascateia a deleção de paradas (route_stops), frequências de visitação (stop_attendances)
  # e eventos de visitação (visit_events).
  class DeleteRoute
    def self.call(route_or_id)
      new.call(route_or_id)
    end

    def call(route_or_id)
      route = find_route(route_or_id)

      route.with_lock do
        route.destroy!
      end

      true
    end

    private

    def find_route(route_or_id)
      case route_or_id
      when Route
        route_or_id
      when Integer, String
        Route.find_by(id: route_or_id) ||
          (raise Routes::RouteNotFoundError, 'Não foi possível identificar a rota a excluir.')
      else
        raise Routes::RouteNotFoundError, 'Não foi possível identificar a rota a excluir.'
      end
    end
  end
end
