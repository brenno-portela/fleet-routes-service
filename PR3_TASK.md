# TASK: PR 3 — Transactional Route Services & Audit Lock

## ROLE & CONTEXT
You are a senior Ruby on Rails engineer. You are working in `fleet-routes-service`, a Ruby module for fleet and field route management.
PR 1 (geospatial math) and PR 2 (ActiveRecord models & migrations for `Route`, `RouteStop`, `StopAttendance`, `VisitEvent`) are already implemented.

## OBJECTIVE
Implement PR 3: business service objects for updating route assignments and deleting routes with strict transactional integrity, pessimistic locking, audit protection, and 100% test coverage using Minitest.

---

## FILES TO CREATE

1. `app/services/routes/errors.rb`
2. `app/services/routes/update_assignment.rb`
3. `app/services/routes/delete_route.rb`
4. `test/services/routes/update_assignment_test.rb`
5. `test/services/routes/delete_route_test.rb`

---

## SPECIFICATIONS

### 1. Domain Errors (`app/services/routes/errors.rb`)
```ruby
# frozen_string_literal: true

module Routes
  class Error < StandardError; end
  class RouteNotFoundError < Error; end
  class InvalidAssignmentError < Error; end
  class AuditedRouteModificationError < Error; end
end
```

### 2. `Routes::UpdateAssignment` (`app/services/routes/update_assignment.rb`)
- **Entry point**: `Routes::UpdateAssignment.call(...)` and `new.call(...)`
- **Keyword arguments**:
  - `route:` (or `route_id:`) [Required] -> `Route` instance or ID. Raise `RouteNotFoundError` if not found.
  - `seller_uid:` [Required] -> string. Raise `InvalidAssignmentError` if blank.
  - `seller_name:` [Optional] -> string.
  - `seller_email:` [Optional] -> string.
  - `due_date:` [Required] -> Date/String. Raise `InvalidAssignmentError` if blank.
  - `name:` [Optional] -> fallback to `"Rota #{due_date}"` if blank.
  - `target_completion_percent:` [Optional] -> integer (1..100), default 90.
  - `notes:` [Optional] -> string.
  - `customers:` [Required] -> Array of hashes representing stops.
  - `estimate:` [Optional] -> Hash `{ distance_meters:, duration_seconds: }`.
  - `current_user_uid:`, `current_user_name:` [Optional] -> for `last_edited_by_*`.

- **Pre-transaction Validations**:
  1. `customers` must not be empty -> raise `InvalidAssignmentError, "Selecione pelo menos um cliente para a rota."`
  2. `customers.size <= 24` -> raise `InvalidAssignmentError, "Uma rota aceita no máximo 24 clientes."`
  3. No duplicate `customer_id` in `customers` -> raise `InvalidAssignmentError, "Um mesmo cliente não pode aparecer duas vezes na mesma rota."`
  4. Each customer must have valid coordinates (`Routes::HaversineDistance.valid_coordinates?(lat, lng)`) -> raise `InvalidAssignmentError, "O cliente #{name} precisa ter coordenadas válidas antes de entrar na rota."`

- **Transaction & Locking**:
  - Wrap logic in `route.with_lock do ... end`.

- **Audit Lock Rule (CRITICAL)**:
  - Check `route.recorded_execution?`.
  - If `true`:
    - `current_customer_ids = route.route_stops.ordered.pluck(:customer_id)`
    - `requested_customer_ids = customers.map { |c| (c[:customer_id] || c['customer_id']).to_s }`
    - `seller_changed = route.seller_uid != seller_uid.to_s`
    - `stops_changed = current_customer_ids != requested_customer_ids`
    - If `stops_changed || seller_changed`:
      - Raise `Routes::AuditedRouteModificationError, "Esta rota já possui check-in, feedback ou navegação registrada. Para preservar a auditoria, somente os detalhes administrativos podem ser editados."`
    - If no stops/seller change: only update administrative fields (`name`, `due_date`, `target_completion_percent`, `assignment_notes`, `last_edited_by_*`).

- **Stop Synchronization (when route NOT audited)**:
  - If stops changed:
    - Index existing stops by `customer_id`.
    - Iterate `customers` with 1-based index `idx`:
      - If existing stop found: update `order: idx`, address, coordinates, and contact fields.
      - If new customer: build/create new `route_stops` record with `order: idx`.
    - Delete stops whose `customer_id` is no longer in `customers`.
    - Recalculate `target_completed_stops = ((customers.size * target_completion_percent) / 100.0).ceil`.
    - If `estimate` provided, update `estimated_distance_meters` and `estimated_duration_seconds`.

- **Return**: `route.reload`

### 3. `Routes::DeleteRoute` (`app/services/routes/delete_route.rb`)
- **Entry point**: `Routes::DeleteRoute.call(route_or_id)` and `new.call(route_or_id)`
- **Behavior**:
  - Find route or raise `Routes::RouteNotFoundError, 'Não foi possível identificar a rota a excluir.'`
  - Wrap in `route.with_lock { route.destroy! }`.
  - Cascading delete handles `route_stops`, `stop_attendances`, and `visit_events`.
  - Return `true`.

---

## TEST SUITE SPECIFICATION (Minitest)

### `test/services/routes/update_assignment_test.rb`
1. `test_updates_administrative_details_successfully`
2. `test_reorders_and_updates_stops_on_unexecuted_route`
3. `test_raises_audited_error_when_changing_stops_on_in_progress_route`
4. `test_raises_audited_error_when_changing_seller_on_visited_route`
5. `test_allows_admin_edit_on_executed_route_when_stops_and_seller_unchanged`
6. `test_raises_invalid_assignment_for_invalid_coordinates`
7. `test_raises_invalid_assignment_when_exceeding_24_customers`
8. `test_rolls_back_transaction_on_unexpected_error`

### `test/services/routes/delete_route_test.rb`
1. `test_deletes_route_and_cascades_to_stops_and_events`
2. `test_raises_route_not_found_for_missing_route`

---

## VERIFICATION COMMANDS
```bash
ruby -Ilib:app:test test/services/routes/update_assignment_test.rb
ruby -Ilib:app:test test/services/routes/delete_route_test.rb
bundle exec rake test
bundle exec rubocop app/services/routes/ test/services/routes/
```

## COMMIT & PUSH
```bash
git add .
git commit -m "feat(routes): implement PR3 - transactional services and audit lock"
git push origin main
```

