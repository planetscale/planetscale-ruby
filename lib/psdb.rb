# frozen_string_literal: true

require 'psdb/version'
require 'ffi'

module PSDB
  class <<self
    attr_reader :config, :inject
  
    def configure(auth_method: AUTH_PSCALE, **kwargs)
      @proxy = PSDB::Proxy.new(auth_method: auth_method, **kwargs)
      @config = true
    end

    def start
      @proxy.start
    end

    def database_password
      @password ||= @proxy.database_password
    end
  end

  class Proxy
    AUTH_SERVICE_TOKEN = 1 # Use Service Tokens for Auth
    AUTH_PSCALE = 2 # Use externally configured `pscale` auth & org config

    extend FFI::Library
    ffi_lib File.expand_path("../../vendor/psdb-#{Gem::Platform.local.os}.so", __FILE__)
    attach_function :proxyfromenv, %i[string string string], :int
    attach_function :passwordfromenv, %i[string string string], :string
    attach_function :proxyfromtoken, %i[string string string string string], :int
    attach_function :passwordfromtoken, %i[string string string string string], :string

    def initialize(auth_method: AUTH_SERVICE_TOKEN, **kwargs)
      @auth_method = auth_method

      @db = kwargs[:db] || ENV['PSDB_DB']
      @branch = kwargs[:branch] || ENV['PSDB_DB_BRANCH']
      @org = kwargs[:org] || ENV['PSDB_ORG']

      raise ArgumentError, 'missing required configuration variables' if [@db, @branch, @org].any?(&:nil?)

      @token_name = kwargs[:token_id] || ENV['PSDB_TOKEN_NAME']
      @token = kwargs[:token] || ENV['PSDB_TOKEN']

      raise ArgumentError, 'missing configured service token auth' if token_auth? && [@token_name, @token].any?(&:nil?)
    end

    def database_password
      if env_auth?
        passwordfromenv(@org, @db, @branch)
      else
        passwordfromtoken(@token_name, @token, @org, @db, @branch)
      end
    end

    def start
      if env_auth?
        proxyfromenv(@org, @db, @branch)
      else
        proxyfromtoken(@token_name, @token, @org, @db, @branch)
      end
    end

    private

    def env_auth?
      @auth_method == AUTH_PSCALE
    end

    def token_auth?
      @auth_method == AUTH_SERVICE_TOKEN
    end
  end
end

require 'psdb/railtie' if defined?(Rails::Railtie)
