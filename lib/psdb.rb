# frozen_string_literal: true

require 'psdb/version'
require 'ffi'

module PSDB
  class <<self
    attr_reader :config

    def configure(auth_method:, **kwargs)
      @proxy = PSDB::Proxy.new(auth_method: auth_method, **kwargs)
      @config = true
    end

    def start
      @proxy.start
    end

    def database_password
      @proxy.database_password
    end
  end

  class Proxy
    AUTH_SERVICE_TOKEN = 1 # Use Service Tokens for Auth
    AUTH_PSCALE = 2 # Use externally configured `pscale` auth & org config

    extend FFI::Library
    ffi_lib '/Users/nickvanw/planetscale/cli/cmd/lib/test.so'
    attach_function :startproxyfromenv, %i[string string string], :bool
    attach_function :passwordfromenv, %i[string string string], :string

    def initialize(auth_method: AUTH_SERVICE_TOKEN, **kwargs)
      @auth_method = auth_method

      @db = kwargs[:db] || ENV['PSDB_DB']
      @branch = kwargs[:branch] || ENV['PSDB_DB_BRANCH']
      @org = kwargs[:org] || ENV['PSDB_ORG']

      raise ArgumentError, 'missing required configuration variables' if [@db, @branch, @org].any?(&:nil?)

      @token_name = kwargs[:token_id] || ENV['PSDB_TOKEN_NAME']
      @token = kwargs[:token] || ENV['PSDB_TOKEN']

      raise ArgumentError, 'missing configured service token auth' if token_auth? && [@token_name, @token].any?(&:nil?)

      @binary = File.expand_path("../../vendor/pscale-#{Gem::Platform.local.os}", __FILE__)
    end

    def database_password
      if env_auth?
        passwordfromenv(@org, @db, @branch)
      else
        raise ArgumentError, 'not implemented'
      end
    end

    def start
      if env_auth?
        startproxyfromenv(@org, @db, @branch)
      else
        raise ArgumentError, 'not implemented'
      end
    end

    def start_binary
      args = [auth_args, 'connect', org_args, @db, @branch].compact.join(' ')
      @pid = fork do
        tries = 0
        loop do
          puts "starting proxy try: #{tries}"
          exec "#{@binary} #{args}"
          tries += 1
          sleep 1
        end
      end

      Process.detach(@pid)
    end

    private

    def env_auth?
      @auth_method == AUTH_PSCALE
    end

    def token_auth?
      @auth_method == AUTH_SERVICE_TOKEN
    end

    def org_args
      "--org #{@org}" if @org
    end

    def auth_args
      "--service-token-name #{@token_name} --service-token #{@token}" if token_auth?
    end
  end
end

require 'psdb/railtie' if defined?(Rails::Railtie)
