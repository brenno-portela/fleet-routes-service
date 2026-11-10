<<<<<<< HEAD
# Fleet Routes Service (Ruby / Rails)

=======
<<<<<<< HEAD
# fleet-routes-service
Serviço de rotas extraído e reimplementado em Ruby.
=======
# Fleet Routes Service (Ruby / Rails)
Fleet Routes Service (Ruby / Rails)
Serviço backend em Ruby para gestão, auditoria, telemetria e acompanhamento de rotas de frotas e equipes de campo, migrado a partir do módulo original de histórico de rotas.

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

Repositório oficial: [https://github.com/brenno-portela/fleet-routes-service.git](https://github.com/brenno-portela/fleet-routes-service.git)

---

## 🚀 Status da Migração: PR 1 — Fundação & Cálculos Matemáticos de Geolocalização

Este primeiro PR estabelece a base do repositório em Ruby puro, sem acoplamentos de banco de dados ou frameworks externos:

* **`Routes::HaversineDistance` (`app/services/routes/haversine_distance.rb`)**:
  * Implementação da fórmula de Haversine esférica com raio terrestre calibrado em $6.371.008,8\text{ m}$.
  * Cálculo de distância geodésica em metros entre coordenadas.
  * Validador estrito de coordenadas geográficas válidas (rejeitando coordenadas inexistentes, nulas e o ponto oceânico `(0, 0)`).
  * Auditoria de presença do vendedor (`assess_proximity`), categorizando a distância em:
    * **No local / Próximo:** $\le 150\text{ m}$ (`:success`)
    * **Nas proximidades:** $\le 500\text{ m}$ (`:info`)
    * **Distante:** $\le 1.500\text{ m}$ (`:warning`)
    * **Muito distante:** $> 1.500\text{ m}$ (`:error`)
  * Formatação amigável em metros e quilômetros no padrão brasileiro (`pt-BR`).

* **`Routes::TelemetryCalculator` (`app/services/routes/telemetry_calculator.rb`)**:
  * Cálculo de discrepância e variância percentual entre realizado e planejado.
  * Cores e rótulos semânticos de auditoria para variância.
  * Formatação de durações (horas, minutos e segundos).
  * Cálculo de tempo de permanência de visitas a partir de timestamps em milissegundos ou objetos `Time`.

---

## 🧪 Como Rodar os Testes (Minitest)

Todos os testes foram escritos utilizando o **Minitest** nativo:

```bash
# Executar todos os testes via Rake:
bundle exec rake test

# Ou executar individualmente:
ruby -Ilib:app:test test/services/routes/haversine_distance_test.rb
ruby -Ilib:app:test test/services/routes/telemetry_calculator_test.rb
```

---

## 📁 Estrutura de Arquivos

```text
fleet-routes-service/
├── .gitignore
├── .rubocop.yml
├── Gemfile
├── Rakefile
├── README.md
├── app/
│   └── services/
│       └── routes/
│           ├── haversine_distance.rb      # Cálculo de Haversine e auditoria de presença
│           └── telemetry_calculator.rb    # Métricas de telemetria e variância
└── test/
    ├── test_helper.rb                     # Configuração do Minitest
    └── services/
        └── routes/
            ├── haversine_distance_test.rb # Suíte de testes geodésicos
            └── telemetry_calculator_test.rb # Suíte de testes de telemetria
```

---

## 🔗 Próximos Passos (Próximos PRs)

* **PR 2:** Migrations e modelos ActiveRecord (`Route`, `RouteStop`, `StopAttendance`, `VisitEvent`).
* **PR 3:** Serviços transacionais de negócio (`Routes::UpdateAssignment` com trava de auditoria e `Routes::DeleteRoute`).
* **PR 4:** Relatórios agregados (`Routes::ReportBuilder`) e streaming Excel com `caxlsx` (`Routes::ExcelExporter`).
* **PR 5:** Controllers RESTful e endpoints de integração.

<<<<<<< HEAD
=======
>>>>>>> caa6817 (feat(routes): implement PR1 - haversine distance, telemetry calculator and minitest suite)
>>>>>>> c0b7e7c (feat: adiciona serviços de cálculo de rotas e testes automatizados)
