# frozen_string_literal: true

require 'psdb/version'

module PSDB
  class Proxy
    AUTH_SERVICE_TOKEN = 1 # Use Service Tokens for Auth
    AUTH_PSCALE = 2 # Use externally configured `pscale` auth & org config

    def initialize(auth_method: AUTH_SERVICE_TOKEN, **kwargs)
      @auth_method = auth_method

      @db = kwargs[:db] || ENV['PSDB_DB']
      @branch = kwargs[:branch] || ENV['PSDB_DB_BRANCH']

      raise ArgumentError, 'missing required configuration variables' if [@db, @branch].any?(&:nil?)

      @org = kwargs[:org] || ENV['PSDB_ORG']
      @token_name = kwargs[:token_id] || ENV['PSDB_TOKEN_NAME']
      @token = kwargs[:token] || ENV['PSDB_TOKEN']

      if token_auth? && [@org, @token_name, @token].any?(&:nil?)
        raise ArgumentError, 'missing configured service token auth'
      end

      @binary = File.expand_path("../../vendor/pscale-#{Gem::Platform.local.os}", __FILE__)
    end

    def database_password
      args = [@binary, auth_args, 'branch', org_args, '--json status', @db, @branch].compact.join(' ')
      stdout, status = Open3.capture2(args)
      raise ArgumentError, 'could not get database password' unless status.success?

      JSON.parse(stdout)['password']
    end

    def start
      args = [auth_args, 'connect', org_args, @db, @branch].compact.join(' ')
      pid = fork do
        tries = 0
        loop do
          puts "starting proxy try: #{tries}"
          system "#{@binary} #{args}"
          tries += 1
          sleep 1
        end
      end
      Process.detach(pid)
    end

    private

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
