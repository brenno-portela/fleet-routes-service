# frozen_string_literal: true

class StopAttendance < ApplicationRecord
  STATUS_PENDING           = 'pending'
  STATUS_IN_PROGRESS       = 'in_progress'
  STATUS_VISITED           = 'visited'
  STATUS_NOT_VISITED       = 'not_visited'
  STATUS_AWAITING_FEEDBACK = 'awaiting_feedback'

  STATUSES = [
    STATUS_PENDING,
    STATUS_IN_PROGRESS,
    STATUS_VISITED,
    STATUS_NOT_VISITED,
    STATUS_AWAITING_FEEDBACK
  ].freeze

  belongs_to :route_stop, inverse_of: :stop_attendances
  has_one :route, through: :route_stop

  validates :check_in_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  validate :check_out_must_be_after_check_in, if: -> { check_in_at.present? && check_out_at.present? }

  before_save :calculate_duration_seconds

  scope :completed, -> { where(status: [STATUS_VISITED, STATUS_NOT_VISITED]) }
  scope :recent_first, -> { order(check_in_at: :desc) }

  private

  def calculate_duration_seconds
    return unless check_in_at.present? && check_out_at.present?

    self.visit_duration_seconds = Routes::TelemetryCalculator.visit_duration_seconds(
      check_in_at: check_in_at,
      check_out_at: check_out_at
    )
  end

  def check_out_must_be_after_check_in
    if check_out_at < check_in_at
      errors.add(:check_out_at, 'não pode ser anterior ao check-in')
    end
  end
end

