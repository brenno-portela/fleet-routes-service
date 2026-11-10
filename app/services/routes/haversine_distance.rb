# frozen_string_literal: true

module Routes
  # Serviço para cálculo de distância geodésica em linha reta sobre a superfície terrestre
  # utilizando a fórmula de Haversine e auditoria de presença do vendedor em relação ao cliente.
  class HaversineDistance
    # Raio médio da Terra em metros, correspondente à calibração do módulo original
    EARTH_RADIUS_METERS = 6_371_008.8

    # Faixas de tolerância de distância em metros para auditoria de checkout/check-in
    THRESHOLD_ON_SITE_METERS  = 150.0
    THRESHOLD_NEARBY_METERS   = 500.0
    THRESHOLD_DISTANT_METERS  = 1_500.0

    class << self
      # Calcula a distância em metros entre duas coordenadas
      # @param origin_lat [Numeric, String, nil] Latitude de origem
      # @param origin_lng [Numeric, String, nil] Longitude de origem
      # @param target_lat [Numeric, String, nil] Latitude de destino
      # @param target_lng [Numeric, String, nil] Longitude de destino
      # @return [Float, nil] Distância em metros ou nil se coordenadas forem inválidas
      def call(origin_lat:, origin_lng:, target_lat:, target_lng:)
        new.calculate(
          origin_lat: origin_lat,
          origin_lng: origin_lng,
          target_lat: target_lat,
          target_lng: target_lng
        )
      end

      # Atalho recebendo pares de hash ou objetos com latitude/longitude
      def distance_between(first_coord, second_coord)
        new.distance_between(first_coord, second_coord)
      end

      # Classifica a distância para fins de auditoria de presença
      # @param meters [Numeric, nil] Distância em metros
      # @return [Hash] Classificação semântica com rótulo, cor e código de status
      def assess_proximity(meters)
        new.assess_proximity(meters)
      end

      # Formata metros em representação legível (pt-BR)
      # @param meters [Numeric, nil]
      # @return [String] Ex: "150 m" ou "12,4 km"
      def format_meters(meters)
        new.format_meters(meters)
      end

      # Valida se os valores representam uma coordenada geográfica real e utilizável
      def valid_coordinates?(latitude, longitude)
        new.valid_coordinates?(latitude, longitude)
      end
    end

    def calculate(origin_lat:, origin_lng:, target_lat:, target_lng:)
      return nil unless valid_coordinates?(origin_lat, origin_lng) && valid_coordinates?(target_lat, target_lng)

      lat1 = to_rad(origin_lat.to_f)
      lon1 = to_rad(origin_lng.to_f)
      lat2 = to_rad(target_lat.to_f)
      lon2 = to_rad(target_lng.to_f)

      dlat = lat2 - lat1
      dlon = lon2 - lon1

      half_chord = (Math.sin(dlat / 2.0)**2) +
                   (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(dlon / 2.0)**2))

      # Clamping para evitar NaN por arredondamento de ponto flutuante
      half_chord = [[half_chord, 0.0].max, 1.0].min

      2.0 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(half_chord), Math.sqrt(1.0 - half_chord))
    end

    def distance_between(first_coord, second_coord)
      lat1 = extract_val(first_coord, :latitude, :lat)
      lng1 = extract_val(first_coord, :longitude, :lng, :lon)
      lat2 = extract_val(second_coord, :latitude, :lat)
      lng2 = extract_val(second_coord, :longitude, :lng, :lon)

      calculate(origin_lat: lat1, origin_lng: lng1, target_lat: lat2, target_lng: lng2)
    end

    def assess_proximity(meters)
      return { label: 'Indisponível', color: :default, status: :unavailable } if meters.nil? || !meters.finite?

      if meters <= THRESHOLD_ON_SITE_METERS
        { label: 'Próximo', color: :success, status: :on_site }
      elsif meters <= THRESHOLD_NEARBY_METERS
        { label: 'Nas proximidades', color: :info, status: :nearby }
      elsif meters <= THRESHOLD_DISTANT_METERS
        { label: 'Distante', color: :warning, status: :distant }
      else
        { label: 'Muito distante', color: :error, status: :far_away }
      end
    end

    def format_meters(meters)
      return '-' if meters.nil? || !meters.finite?

      if meters < 1_000.0
        "#{meters.round} m"
      else
        km = meters / 1_000.0
        formatted_km = format('%.1f', km).tr('.', ',')
        "#{formatted_km} km"
      end
    end

    def valid_coordinates?(latitude, longitude)
      return false if latitude.nil? || longitude.nil?

      lat = Float(latitude, exception: false)
      lng = Float(longitude, exception: false)

      return false if lat.nil? || lng.nil?
      return false unless lat.between?(-90.0, 90.0) && lng.between?(-180.0, 180.0)
      return false if lat.zero? && lng.zero?

      true
    end

    # Audita a distância entre o feedback/check-in/checkout e o cadastro do cliente
    def audit_feedback(feedback_coord:, customer_coord:)
      unless valid_coord_obj?(feedback_coord)
        return {
          meters: nil,
          assessment: assess_proximity(nil),
          reason: 'Sem localização do vendedor',
          valid: false
        }
      end

      unless valid_coord_obj?(customer_coord)
        return {
          meters: nil,
          assessment: assess_proximity(nil),
          reason: 'Cliente sem coordenadas válidas',
          valid: false
        }
      end

      dist = distance_between(feedback_coord, customer_coord)
      {
        meters: dist,
        formatted: format_meters(dist),
        assessment: assess_proximity(dist),
        reason: nil,
        valid: true
      }
    end

    private

    def to_rad(degrees)
      degrees * (Math::PI / 180.0)
    end

    def valid_coord_obj?(obj)
      return false if obj.nil?

      lat = extract_val(obj, :latitude, :lat)
      lng = extract_val(obj, :longitude, :lng, :lon)
      valid_coordinates?(lat, lng)
    end

    def extract_val(obj, *keys)
      return nil if obj.nil?

      keys.each do |key|
        if obj.respond_to?(key)
          val = obj.public_send(key)
          return val unless val.nil?
        elsif obj.is_a?(Hash)
          val = obj[key] || obj[key.to_s]
          return val unless val.nil?
        end
      end
      nil
    end
  end
end

