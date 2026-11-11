# TASK: PR 4 — Route Reporting & Synchronous Excel Streaming (caxlsx)

## ROLE & CONTEXT
You are a senior Ruby on Rails engineer working in `fleet-routes-service`.
PR 1 (math/geospatial), PR 2 (ActiveRecord models: `Route`, `RouteStop`, `StopAttendance`, `VisitEvent`), and PR 3 (transactional services) are complete.

## OBJECTIVE
Implement PR 4: the analytical reporting intelligence and high-performance Excel exporter using `caxlsx`.
It transforms raw route and stop records into business KPIs and generates a polished multi-tab `.xlsx` workbook (in-memory buffer for streaming).

---

## FILES TO CREATE

1. `app/services/routes/report_builder.rb`
2. `app/services/routes/excel_exporter.rb`
3. `test/services/routes/report_builder_test.rb`
4. `test/services/routes/excel_exporter_test.rb`

---

## SPECIFICATIONS

### 1. `Routes::ReportBuilder` (`app/services/routes/report_builder.rb`)
- **Entry point**: `Routes::ReportBuilder.call(filters: {})`
- **Supported filters (`filters` hash)**:
  - `date_from:` / `date_to:` (Filter on `routes.due_date` or `routes.created_at`)
  - `status:` (Match single or list of statuses: `planned`, `assigned`, `in_progress`, `completed`, `not_completed`)
  - `seller_uid:` (Match specific salesperson)
  - `state:` (Match state UF uppercase, e.g., `'SP'`)
  - `route_type:` (`'all'`, `'shared'`, `'seller_planned'`)
  - `search:` (Case-insensitive text search on route name or customer name)

- **Calculations & Output Structure (`Hash`)**:
  ```ruby
  {
    routes: [...],    # Filtered Route records with preloaded stops and attendances
    summary: {
      total_routes: Integer,
      completed_routes: Integer,
      completion_rate_percent: Float,     # (completed_routes / total_routes) * 100
      total_stops: Integer,
      visited_stops: Integer,
      stop_completion_percent: Float,     # (visited_stops / total_stops) * 100
      feedback_coverage_percent: Float,   # (reported_stops / total_stops) * 100
      total_actual_distance_meters: Float,
      total_planned_distance_meters: Float,
      average_visit_duration_seconds: Integer
    },
    sellers: [         # Grouped metrics per seller_uid
      {
        seller_uid: String,
        seller_name: String,
        route_count: Integer,
        completed_route_count: Integer,
        total_stops: Integer,
        visited_stops: Integer,
        completion_percent: Float,
        average_visit_duration_seconds: Integer
      }
    ]
  }
  ```
- **Performance Rule**: Always use eager loading (`includes(:route_stops, :stop_attendances, :visit_events)`) to prevent N+1 queries.

---

### 2. `Routes::ExcelExporter` (`app/services/routes/excel_exporter.rb`)
- **Entry point**: `Routes::ExcelExporter.call(report:, filter_labels: [])`
- **Dependency**: Gem `caxlsx` (already in `Gemfile`).
- **Return value**: Binary string (`package.to_stream.read`), ready for Rails controller `send_data`.
- **Workbook Tabs (4 Sheets)**:
  1. **"Resumo Executivo"**:
     - Header block with applied filter labels and generation date.
     - KPI cards: Total de Rotas, Rotas Concluídas, Taxa de Conclusão, Total de Paradas, Cobertura de Feedbacks, Distância Total Percorrida.
  2. **"Rotas"**:
     - Columns: ID, Nome da Rota, Vendedor, Estado, Prazo, Status, Meta (%), Conclusão (%), Total Paradas, Paradas Visitadas, Distância Planejada (km), Distância Percorrida (km), Variância GPS (%), Duração em Rota, Observações.
  3. **"Paradas e Clientes"**:
     - Columns: ID Rota, Nome Rota, Vendedor, Ordem, ID Cliente, Nome Cliente, CNPJ/CPF, Cidade, UF, Check-in, Checkout, Duração Atendimento, Status, Motivo Não Visita, Feedback, Distância do Cliente (Auditoria GPS).
  4. **"Desempenho Vendedores"**:
     - Columns: Vendedor, Total de Rotas, Rotas Concluídas, Taxa Conclusão Rotas (%), Total Paradas, Paradas Visitadas, Eficácia Visitas (%), Tempo Médio por Visita.
- **Styling Rules**:
  - Palette: Brand Primary (`#00463A`), Energy Teal (`#00D2AE`), Light (`#A4E0CE`), White (`#FFFFFF`).
  - Bold headers with dark background and white text.
  - Auto-adjusted column widths.
  - Proper formatting for dates (`DD/MM/YYYY HH:MM`) and numbers.

---

## TEST SUITE SPECIFICATION (Minitest)

### `test/services/routes/report_builder_test.rb`
1. `test_aggregates_summary_kpis_correctly`
2. `test_filters_by_date_range`
3. `test_filters_by_status_and_seller`
4. `test_groups_seller_performance_metrics`
5. `test_handles_empty_dataset_without_zero_division_errors`

### `test/services/routes/excel_exporter_test.rb`
1. `test_generates_valid_xlsx_binary_stream`
2. `test_contains_four_required_sheets`
3. `test_populates_data_and_styles_without_exceptions`

---

## VERIFICATION COMMANDS
```bash
ruby -Ilib:app:test test/services/routes/report_builder_test.rb
ruby -Ilib:app:test test/services/routes/excel_exporter_test.rb
bundle exec rake test
bundle exec rubocop app/services/routes/report_builder.rb app/services/routes/excel_exporter.rb
```

## COMMIT & PUSH
```bash
git add .
git commit -m "feat(routes): implement PR4 - report builder and caxlsx excel streaming exporter"
git push origin main
```

