# frozen_string_literal: true

require_relative 'errors'

module Routes
  # Serviço para atualizar atribuições de rotas com integridade transacional e proteção de auditoria.
  # Utiliza lock pessimista para evitar race conditions e valida modificações em rotas executadas.
  class UpdateAssignment
    def self.call(**kwargs)
      new.call(**kwargs)
    end

    def call(route: nil, route_id: nil, seller_uid:, seller_name: nil, seller_email: nil,
             due_date:, name: nil, target_completion_percent: 90, notes: nil, customers:,
             estimate: nil, current_user_uid: nil, current_user_name: nil)
      # Resolva route a partir de route_id se necessário
      route ||= find_route(route_id)

      # Validações pré-transação
      validate_customers(customers)
      validate_seller_uid(seller_uid)
      validate_due_date(due_date)

      # Executar dentro da transação com lock pessimista
      route.with_lock do
        perform_update(
          route, seller_uid, seller_name, seller_email, due_date, name,
          target_completion_percent, notes, customers, estimate,
          current_user_uid, current_user_name
        )
      end

      route.reload
    end

    private

    def find_route(route_id)
      if route_id.nil?
        raise Routes::RouteNotFoundError, 'Route not found'
      end

      Route.find_by(id: route_id) || (raise Routes::RouteNotFoundError, 'Route not found')
    end

    def validate_customers(customers)
      raise Routes::InvalidAssignmentError, 'Selecione pelo menos um cliente para a rota.' if customers.empty?

      if customers.size > 24
        raise Routes::InvalidAssignmentError, 'Uma rota aceita no máximo 24 clientes.'
      end

      customer_ids = customers.map { |c| (c[:customer_id] || c['customer_id']).to_s }
      if customer_ids.uniq.size != customer_ids.size
        raise Routes::InvalidAssignmentError, 'Um mesmo cliente não pode aparecer duas vezes na mesma rota.'
      end

      customers.each do |customer|
        customer_name = customer[:customer_name] || customer['customer_name'] || 'Desconhecido'
        lat = customer[:latitude] || customer['latitude']
        lng = customer[:longitude] || customer['longitude']

        unless Routes::HaversineDistance.valid_coordinates?(lat, lng)
          raise Routes::InvalidAssignmentError,
                "O cliente #{customer_name} precisa ter coordenadas válidas antes de entrar na rota."
        end
      end
    end

    def validate_seller_uid(seller_uid)
      raise Routes::InvalidAssignmentError, 'Seller UID cannot be blank' if seller_uid.blank?
    end

    def validate_due_date(due_date)
      raise Routes::InvalidAssignmentError, 'Due date cannot be blank' if due_date.blank?
    end

    def perform_update(route, seller_uid, seller_name, seller_email, due_date, name,
                       target_completion_percent, notes, customers, estimate,
                       current_user_uid, current_user_name)
      current_customer_ids = route.route_stops.ordered.pluck(:customer_id)
      requested_customer_ids = customers.map { |c| (c[:customer_id] || c['customer_id']).to_s }

      seller_changed = route.seller_uid.to_s != seller_uid.to_s
      stops_changed = current_customer_ids != requested_customer_ids

      # Audit lock rule: se a rota foi executada, valide o que pode ser alterado
      if route.recorded_execution?
        if stops_changed || seller_changed
          raise Routes::AuditedRouteModificationError,
                'Esta rota já possui check-in, feedback ou navegação registrada. ' \
                'Para preservar a auditoria, somente os detalhes administrativos podem ser editados.'
        end

        # Apenas atualize campos administrativos
        update_administrative_fields(route, seller_uid, seller_name, seller_email,
                                    due_date, name, target_completion_percent,
                                    notes, current_user_uid, current_user_name)
      else
        # Rota não foi executada: permite sincronização completa de paradas
        synchronize_stops(route, customers) if stops_changed

        # Atualize todos os campos
        update_all_fields(route, seller_uid, seller_name, seller_email,
                         due_date, name, target_completion_percent,
                         notes, customers, estimate, current_user_uid, current_user_name)
      end
    end

    def update_administrative_fields(route, seller_uid, seller_name, seller_email,
                                     due_date, name, target_completion_percent,
                                     notes, current_user_uid, current_user_name)
      route.seller_uid = seller_uid.to_s
      route.seller_name = seller_name if seller_name.present?
      route.seller_email = seller_email if seller_email.present?
      route.due_date = due_date
      route.name = name.present? ? name : "Rota #{due_date}"
      route.target_completion_percent = target_completion_percent
      route.assignment_notes = notes if notes.present?
      route.last_edited_by_uid = current_user_uid if current_user_uid.present?
      route.last_edited_by_name = current_user_name if current_user_name.present?

      route.save!
    end

    def update_all_fields(route, seller_uid, seller_name, seller_email,
                         due_date, name, target_completion_percent,
                         notes, customers, estimate, current_user_uid, current_user_name)
      route.seller_uid = seller_uid.to_s
      route.seller_name = seller_name if seller_name.present?
      route.seller_email = seller_email if seller_email.present?
      route.due_date = due_date
      route.name = name.present? ? name : "Rota #{due_date}"
      route.target_completion_percent = target_completion_percent
      route.assignment_notes = notes if notes.present?
      route.last_edited_by_uid = current_user_uid if current_user_uid.present?
      route.last_edited_by_name = current_user_name if current_user_name.present?

      # Atualizar estimate se fornecido
      if estimate.present?
        route.estimated_distance_meters = estimate[:distance_meters] if estimate[:distance_meters].present?
        route.estimated_duration_seconds = estimate[:duration_seconds] if estimate[:duration_seconds].present?
      end

      # Recalcular target_completed_stops
      route.target_completed_stops = ((customers.size * target_completion_percent) / 100.0).ceil

      route.save!
    end

    def synchronize_stops(route, customers)
      # Índice de paradas existentes por customer_id
      existing_stops = route.route_stops.index_by(&:customer_id)

      customers.each_with_index do |customer, idx|
        order = idx + 1
        customer_id = (customer[:customer_id] || customer['customer_id']).to_s
        customer_name = customer[:customer_name] || customer['customer_name']
        latitude = customer[:latitude] || customer['latitude']
        longitude = customer[:longitude] || customer['longitude']
        address = customer[:address] || customer['address']
        phone_number = customer[:phone_number] || customer['phone_number']
        email = customer[:email] || customer['email']

        if existing_stops[customer_id]
          # Atualizar stop existente
          stop = existing_stops[customer_id]
          stop.update!(
            order: order,
            customer_name: customer_name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            phone_number: phone_number,
            email: email
          )
        else
          # Criar novo stop
          route.route_stops.create!(
            customer_id: customer_id,
            customer_name: customer_name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            phone_number: phone_number,
            email: email,
            order: order,
            status: RouteStop::STATUS_PENDING
          )
        end
      end

      # Deletar stops que não estão mais na lista de customers
      requested_customer_ids = customers.map { |c| (c[:customer_id] || c['customer_id']).to_s }
      route.route_stops.where.not(customer_id: requested_customer_ids).destroy_all
    end
  end
end
