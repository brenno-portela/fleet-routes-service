# frozen_string_literal: true

class Route < ApplicationRecord
  STATUS_PLANNED       = 'planned'
  STATUS_ASSIGNED      = 'assigned'
  STATUS_IN_PROGRESS   = 'in_progress'
  STATUS_COMPLETED     = 'completed'
  STATUS_NOT_COMPLETED = 'not_completed'

  STATUSES = [
    STATUS_PLANNED,
    STATUS_ASSIGNED,
    STATUS_IN_PROGRESS,
    STATUS_COMPLETED,
    STATUS_NOT_COMPLETED
  ].freeze

  EXECUTED_STATUSES = [
    STATUS_IN_PROGRESS,
    STATUS_COMPLETED,
    STATUS_NOT_COMPLETED
  ].freeze

  has_many :route_stops, -> { order(:order) }, dependent: :destroy, inverse_of: :route
  has_many :visit_events, dependent: :destroy, inverse_of: :route
  has_many :stop_attendances, through: :route_stops

  validates :name, presence: true
  validates :seller_uid, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :target_completion_percent, numericality: { only_integer: true, in: 1..100 }

  validate :origin_coordinates_must_be_valid, if: :origin_present?

  scope :recent, ->(limit = 50) { order(created_at: :desc).limit(limit) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_seller, ->(seller_uid) { where(seller_uid: seller_uid) if seller_uid.present? }
  scope :by_state, ->(state) { where(state: state.to_s.upcase) if state.present? }
  scope :active, -> { where(status: [STATUS_ASSIGNED, STATUS_PLANNED, STATUS_IN_PROGRESS]) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }

  # Trava de auditoria: verifica se a rota já possui qualquer registro de execução em campo
  def recorded_execution?
    return true if EXECUTED_STATUSES.include?(status.to_s.downcase)

    route_stops.any?(&:recorded_execution?)
  end

  def visited_stops
    route_stops.select { |s| s.status.to_s.downcase == 'visited' }
  end

  def reported_stops
    route_stops.select { |s| %w[visited not_visited].include?(s.status.to_s.downcase) }
  end

  def completion_percent
    total = route_stops.size
    return 0 if total.zero?

    ((visited_stops.size.to_f / total) * 100.0).round
  end

  def calculate_target_completed_stops
    total = route_stops.size
    return 0 if total.zero?

    ((total * target_completion_percent) / 100.0).ceil
  end

  private

  def origin_present?
    origin_latitude.present? || origin_longitude.present?
  end

  def origin_coordinates_must_be_valid
    unless Routes::HaversineDistance.valid_coordinates?(origin_latitude, origin_longitude)
      errors.add(:origin_coordinates, 'devem ser uma latitude e longitude terrestres válidas e não nulas')
    end
  end
end

