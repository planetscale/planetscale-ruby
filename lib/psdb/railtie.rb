# frozen_string_literal: true

require 'psdb'
require 'rails'

module PSDB
  class Railtie < Rails::Railtie
    initializer 'psdb.initializer' do
      PSDB.start if PSDB.config
      binding.pry
    end
  end
end
