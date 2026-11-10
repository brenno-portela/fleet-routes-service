# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'

# Adiciona o diretório app ao LOAD_PATH para carregar services facilmente
$LOAD_PATH.unshift File.expand_path('../app', __dir__)
$LOAD_PATH.unshift File.expand_path('../app/services', __dir__)

require 'routes/haversine_distance'
require 'routes/telemetry_calculator'

