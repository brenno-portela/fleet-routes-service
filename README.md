<<<<<<< HEAD
<<<<<<< HEAD
# Fleet Routes Service (Ruby / Rails)

=======
<<<<<<< HEAD
# fleet-routes-service
Serviço de rotas extraído e reimplementado em Ruby.
=======
=======
>>>>>>> 3a5af18 (feat(routes): implement PR2 - relational migrations, active record models and model tests)
# Fleet Routes Service (Ruby / Rails)

<<<<<<< HEAD
Repositório oficial: https://github.com/brenno-portela/fleet-routes-service.git

🚀 Status da Migração: PR 1 — Fundação & Cálculos Matemáticos de Geolocalização
Este primeiro PR estabelece a base do repositório em Ruby puro, sem acoplamentos de banco de dados ou frameworks externos.

Serviços implementados
Routes::HaversineDistance (app/services/routes/haversine_distance.rb):
Implementação da fórmula de Haversine esférica com raio terrestre calibrado em 6.371.008,8 metros.
Cálculo de distância geodésica em metros entre coordenadas.
Validação de coordenadas geográficas.
Auditoria de presença do vendedor (assess_proximity), categorizando a distância em:
No local / Próximo: até 150 m (:success).
Nas proximidades: até 500 m (:info).
Distante: até 1.500 m (:warning).
Muito distante: acima de 1.500 m (:error).
Formatação amigável em metros e quilômetros no padrão brasileiro (pt-BR).
Routes::TelemetryCalculator (app/services/routes/telemetry_calculator.rb):
Cálculo de discrepância e variância percentual entre realizado e planejado.
Cores e rótulos semânticos de auditoria para variância.
Formatação de durações (horas, minutos e segundos).
Cálculo de tempo de permanência de visitas a partir de timestamps em milissegundos ou objetos Time.
🧪 Como Rodar os Testes (Minitest)
Todos os testes foram escritos utilizando o Minitest nativo:


bash
# Executar todos os testes via Rake:
bundle exec rake test

# Ou executar individualmente:
ruby -Ilib:app:test test/services/routes/haversine_distance_test.rb
ruby -Ilib:app:test test/services/routes/telemetry_calculator_test.rb
📁 Estrutura de Arquivos

text
fleet-routes-service/
├── .gitignore
├── .rubocop.yml
├── Gemfile
├── Rakefile
├── README.md
├── app/
│   └── services/
│       └── routes/
│           ├── haversine_distance.rb
│           └── telemetry_calculator.rb
└── test/
    ├── test_helper.rb
    └── services/
        └── routes/
            ├── haversine_distance_test.rb
            └── telemetry_calculator_test.rb
>>>>>>> c0b7e7c (feat: adiciona serviços de cálculo de rotas e testes automatizados)
Módulo backend em **Ruby** para gestão, auditoria, telemetria e acompanhamento de rotas de frotas e equipes de campo, migrado a partir do módulo original de histórico de rotas.
=======
Módulo backend em **Ruby on Rails** para gestão, auditoria, telemetria e acompanhamento de rotas de frotas e equipes de campo, migrado a partir do módulo original de histórico de rotas.
>>>>>>> 3a5af18 (feat(routes): implement PR2 - relational migrations, active record models and model tests)

Repositório oficial: [https://github.com/brenno-portela/fleet-routes-service.git](https://github.com/brenno-portela/fleet-routes-service.git)

---

## 🚀 Status da Migração

### ✅ PR 1 — Fundação & Cálculos Matemáticos de Geolocalização (Concluído)
* **`Routes::HaversineDistance` (`app/services/routes/haversine_distance.rb`)**:
  * Fórmula de Haversine esférica com raio calibrado em $6.371.008,8\text{ m}$.
  * Cálculo de distância geodésica em metros e validação de coordenadas.
  * Auditoria de presença do vendedor (`assess_proximity`):
    * **No local / Próximo:** $\le 150\text{ m}$ (`:success`)
    * **Nas proximidades:** $\le 500\text{ m}$ (`:info`)
    * **Distante:** $\le 1.500\text{ m}$ (`:warning`)
    * **Muito distante:** $> 1.500\text{ m}$ (`:error`)
* **`Routes::TelemetryCalculator` (`app/services/routes/telemetry_calculator.rb`)**:
  * Cálculo de discrepância e variância percentual entre realizado e planejado.
  * Formatação de durações e cálculo de permanência em visitas.

### ✅ PR 2 — Modelagem Relacional & Migrations ActiveRecord (Concluído)
* **Migrations (`db/migrate/`)**:
  * `20261110000001_create_routes.rb`: Tabela `routes` com índices compostos para listagem rápida e auditoria.
  * `20261110000002_create_route_stops.rb`: Tabela `route_stops` com integridade referencial (`on_delete: :cascade`) e unicidade de ordem por rota.
  * `20261110000003_create_stop_attendances.rb`: Tabela `stop_attendances` para relação 1:N de visitas e revisitas por parada.
  * `20261110000004_create_visit_events.rb`: Tabela `visit_events` para registro granular de amostras de GPS e telemetria.
* **Modelos ActiveRecord (`app/models/`)**:
  * **`Route`**: Associações completas, cálculo de meta e taxa de conclusão (`completion_percent`), e trava de auditoria (`recorded_execution?`).
  * **`RouteStop`**: Validação de coordenadas, limite máximo de 24 paradas por rota (`MAX_STOPS_PER_ROUTE`), e detecção de execução.
  * **`StopAttendance`**: Validação cronológica de check-out após check-in e cálculo automático de duração de atendimento antes de salvar.
  * **`VisitEvent`**: Validação de tipo de evento, coordenadas e scopes cronológicos.

---

## 🧪 Como Rodar os Testes (Minitest)

Todos os testes de serviços e modelos utilizam o **Minitest** nativo com banco em memória:

```bash
# Executar toda a suíte de testes:
bundle exec rake test

# Ou executar por arquivo:
ruby -Ilib:app:test test/models/route_test.rb
ruby -Ilib:app:test test/models/route_stop_test.rb
ruby -Ilib:app:test test/models/stop_attendance_test.rb
ruby -Ilib:app:test test/models/visit_event_test.rb
ruby -Ilib:app:test test/services/routes/haversine_distance_test.rb
ruby -Ilib:app:test test/services/routes/telemetry_calculator_test.rb
```

---

## 📁 Estrutura do Repositório

```text
fleet-routes-service/
├── .gitignore
├── .rubocop.yml
├── Gemfile
├── Rakefile
├── README.md
├── app/
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── route.rb               # Modelo de rotas e trava de auditoria
│   │   ├── route_stop.rb          # Paradas com validação de 24 paradas e geo
│   │   ├── stop_attendance.rb     # Múltiplos atendimentos 1:N por parada
│   │   └── visit_event.rb         # Telemetria e amostras de GPS
│   └── services/
│       └── routes/
│           ├── haversine_distance.rb
│           └── telemetry_calculator.rb
├── db/
│   └── migrate/
│       ├── 20261110000001_create_routes.rb
│       ├── 20261110000002_create_route_stops.rb
│       ├── 20261110000003_create_stop_attendances.rb
│       └── 20261110000004_create_visit_events.rb
└── test/
    ├── test_helper.rb             # Bootstrap do Minitest com SQLite3 em memória
    ├── models/
    │   ├── route_test.rb
    │   ├── route_stop_test.rb
    │   ├── stop_attendance_test.rb
    │   └── visit_event_test.rb
    └── services/
        └── routes/
            ├── haversine_distance_test.rb
            └── telemetry_calculator_test.rb
```

---

## 🔗 Próximos Passos (Próximos PRs)

* **PR 3:** Serviços transacionais de negócio (`Routes::UpdateAssignment` com trava de auditoria e `Routes::DeleteRoute`).
* **PR 4:** Relatórios agregados (`Routes::ReportBuilder`) e streaming Excel com `caxlsx` (`Routes::ExcelExporter`).
* **PR 5:** Controllers RESTful e endpoints de integração.
<<<<<<< HEAD

<<<<<<< HEAD
=======
>>>>>>> caa6817 (feat(routes): implement PR1 - haversine distance, telemetry calculator and minitest suite)
>>>>>>> c0b7e7c (feat: adiciona serviços de cálculo de rotas e testes automatizados)
=======
>>>>>>> 3a5af18 (feat(routes): implement PR2 - relational migrations, active record models and model tests)
