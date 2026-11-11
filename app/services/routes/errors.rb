# frozen_string_literal: true

module Routes
  class Error < StandardError; end
  class RouteNotFoundError < Error; end
  class InvalidAssignmentError < Error; end
  class AuditedRouteModificationError < Error; end
end
