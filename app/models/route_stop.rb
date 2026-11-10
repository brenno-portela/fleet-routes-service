# frozen_string_literal: true

class RouteStop < ApplicationRecord
  STATUS_PENDING           = 'pending'
  STATUS_ASSIGNED          = 'assigned'
  STATUS_IN_PROGRESS       = 'in_progress'
  STATUS_VISITED           = 'visited'
  STATUS_NOT_VISITED       = 'not_visited'
  STATUS_AWAITING_FEEDBACK = 'awaiting_feedback'

  STATUSES = [
    STATUS_PENDING,
    STATUS_ASSIGNED,
    STATUS_IN_PROGRESS,
    STATUS_VISITED,
    STATUS_NOT_VISITED,
    STATUS_AWAITING_FEEDBACK
  ].freeze

  EXECUTED_STATUSES = [
    STATUS_IN_PROGRESS,
    STATUS_VISITED,
    STATUS_NOT_VISITED,
    STATUS_AWAITING_FEEDBACK
  ].freeze

  MAX_STOPS_PER_ROUTE = 24

  belongs_to :route, inverse_of: :route_stops
  has_many :stop_attendances, -> { order(check_in_at: :desc) }, dependent: :destroy, inverse_of: :route_stop
  has_many :visit_events, dependent: :nullify, inverse_of: :route_stop

  validates :customer_id, presence: true
  validates :customer_name, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :route_id }

  validate :coordinates_must_be_valid
  validate :cannot_exceed_max_stops_limit, on: :create

  scope :visited, -> { where(status: STATUS_VISITED) }
  scope :not_visited, -> { where(status: STATUS_NOT_VISITED) }
  scope :reported, -> { where(status: [STATUS_VISITED, STATUS_NOT_VISITED]) }
  scope :ordered, -> { order(:order) }

  # Trava de auditoria: identifica se a parada já possui registro de campo
  def recorded_execution?
    return true if EXECUTED_STATUSES.include?(status.to_s.downcase)
    return true if check_in_at.present? || check_out_at.present? || feedback.present?
    return true if stop_attendances.any?

    false
  end

  def latest_attendance
    stop_attendances.first
  end

  def effective_duration_seconds
    latest_attendance&.visit_duration_seconds || visit_duration_seconds
  end

  private

  def coordinates_must_be_valid
    unless Routes::HaversineDistance.valid_coordinates?(latitude, longitude)
      errors.add(:coordinates, 'devem ser uma latitude e longitude terrestres válidas e não nulas')
    end
  end

  def cannot_exceed_max_stops_limit
    return unless route

    if route.route_stops.size >= MAX_STOPS_PER_ROUTE
      errors.add(:base, "Uma rota aceita no máximo #{MAX_STOPS_PER_ROUTE} clientes.")
    end
  end
end

