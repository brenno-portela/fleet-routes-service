# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'
require 'active_record'

# Adiciona o diretório app ao LOAD_PATH para carregar services e models facilmente
$LOAD_PATH.unshift File.expand_path('../app', __dir__)
$LOAD_PATH.unshift File.expand_path('../app/services', __dir__)
$LOAD_PATH.unshift File.expand_path('../app/models', __dir__)

require 'routes/haversine_distance'
require 'routes/telemetry_calculator'

require 'application_record'
require 'route'
require 'route_stop'
require 'stop_attendance'
require 'visit_event'

# Configuração de banco de dados SQLite3 em memória para testes
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Silencia logs de SQL durante os testes
ActiveRecord::Base.logger = nil

# Executa as migrations para estruturar o banco de testes
require_relative '../db/migrate/20261110000001_create_routes'
require_relative '../db/migrate/20261110000002_create_route_stops'
require_relative '../db/migrate/20261110000003_create_stop_attendances'
require_relative '../db/migrate/20261110000004_create_visit_events'

CreateRoutes.new.change
CreateRouteStops.new.change
CreateStopAttendances.new.change
CreateVisitEvents.new.change

# Limpa o banco entre testes
module DatabaseCleaner
  def before_setup
    super
    Route.destroy_all
    VisitEvent.destroy_all
  end
end

class Minitest::Test
  include DatabaseCleaner
end

