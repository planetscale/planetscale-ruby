# frozen_string_literal: true

require 'psdb/version'
require 'ffi'

module PSDB
  class <<self
    attr_reader :config, :inject

    def start(auth_method: Proxy::AUTH_PSCALE, **kwargs)
      @proxy = PSDB::Proxy.new(auth_method: auth_method, **kwargs)
      @proxy.start
      @config = true
    end

    def database_password
      @proxy.database_password
    end
  end

  class Proxy
    AUTH_SERVICE_TOKEN = 1 # Use Service Tokens for Auth
    AUTH_PSCALE = 2 # Use externally configured `pscale` auth & org config
    AUTH_STATIC = 3 # Use a locally provided certificate & password
    CONTROL_URL = 'http://127.0.0.1:6060'

    extend FFI::Library
    ffi_lib File.expand_path("../../proxy/psdb-#{Gem::Platform.local.os}.so", __FILE__)
    attach_function :startfromenv, %i[string string string], :int
    attach_function :startfromtoken, %i[string string string string string], :int
    attach_function :startfromstatic, %i[string string string string string string string], :int

    def initialize(auth_method: AUTH_SERVICE_TOKEN, **kwargs)
      @auth_method = auth_method

      default_file = File.join(Rails.root, '.pscale') if defined?(Rails.root)

      @cfg_file = kwargs[:cfg_file] || ENV['PSDB_DB_CONFIG'] || default_file

      @branch_name = kwargs[:branch] || ENV['PSDB_DB_BRANCH']
      @branch = lookup_branch

      @db_name = kwargs[:db] || ENV['PSDB_DB']
      @db = lookup_database

      @org = kwargs[:org] || ENV['PSDB_ORG']

      raise ArgumentError, 'missing required configuration variables' if [@db, @branch, @org].any?(&:nil?)

      @token_name = kwargs[:token_id] || ENV['PSDB_TOKEN_NAME']
      @token = kwargs[:token] || ENV['PSDB_TOKEN']

      raise ArgumentError, 'missing configured service token auth' if token_auth? && [@token_name, @token].any?(&:nil?)

      @password = kwargs[:database_password]
      @priv_key = kwargs[:private_key]
      @cert_chain = kwargs[:cert_chain]
      @remote_addr = kwargs[:remote_addr]
      @certificate = kwargs[:certificate]

      if local_auth? && [@password, @priv_key, @certificate, @cert_chain, @remote_addr].any?(&:nil?)
        raise ArgumentError, 'missing configuration options for auth'
      end
    end

    def database_password
      return @password if local_auth?

      Net::HTTP.get(URI("#{CONTROL_URL}/password"))
    end

    def start
      case @auth_method
      when AUTH_PSCALE
        startfromenv(@org, @db, @branch)
      when AUTH_SERVICE_TOKEN
        startfromtoken(@token_name, @token, @org, @db, @branch)
      when AUTH_STATIC
        startfromstatic(@org, @db, @branch, @priv_key, @certificate, @cert_chain, @remote_addr)
      end
    end

    private

    def lookup_branch
      return @branch_name if @branch_name
      return nil unless File.exist?(@cfg_file)

      cfg_file['branch']
    end

    def lookup_database
      return @db_name if @db_name
      return nil unless File.exist?(@cfg_file)

      cfg_file['database']
    end

    def cfg_file
      @cfg ||= YAML.safe_load(File.read(@cfg_file))
    end

    def local_auth?
      @auth_method == AUTH_STATIC
    end

    def env_auth?
      @auth_method == AUTH_PSCALE
    end

    def token_auth?
      @auth_method == AUTH_SERVICE_TOKEN
    end
  end
end

require 'psdb/railtie' if defined?(Rails::Railtie)
