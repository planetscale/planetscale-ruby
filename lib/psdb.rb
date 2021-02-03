require "psdb/version"

module PSDB
  class Proxy
    def initialize(kwargs = {})
      @token_name = kwargs[:token_id] || ENV['PSDB_TOKEN_NAME']
      @token = kwargs[:token] || ENV['PSDB_TOKEN']
      @org = kwargs[:org] || ENV['PSDB_ORG']
      @db = kwargs[:db] || ENV['PSDB_DB']
      @branch = kwargs[:branch] || ENV['PSDB_DB_BRANCH']
      if [@token_name, @token, @org, @db, @branch].any? { |e| e.nil? }
        raise ArgumentError.new("missing required configuration variables")
      end
      @binary = File.expand_path("../../vendor/pscale-#{Gem::Platform.local.os}", __FILE__)
    end

    def database_password
      args = "#{@binary} #{token_args} branch --org #{@org} --json status #{@db} #{@branch}"
      stdout, status = Open3.capture2(args)
      raise ArgumentError.new("could not get database password") unless status.success?
      return JSON.parse(stdout)['password']
    end

    def start
      args = "#{token_args} connect --org #{@org} #{@db} #{@branch}"
      pid = fork do
        tries = 0
        while true
          puts "starting proxy try: #{tries}"
          system "#{@binary} #{args}"
          tries += 1
          sleep 1
        end
      end
      Process.detach(pid)
    end

    private

    def token_args
      "--service-token-name #{@token_name} --service-token #{@token}"
    end
  end
end
