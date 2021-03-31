require 'rails/generators'

class Planetscale
  class InstallGenerator < Rails::Generators::Base    
    class_option :organization, type: :string, default: ''

    def read_config
      @database = "<db_name>"
      file_path = File.join(Rails.root, PSDB::Proxy::PSCALE_FILE)
      return unless File.exist?(file_path)

      data = YAML.safe_load(File.read(file_path))
      @database = data['database']
      @org = data['org']
    end

    def check_org
      if options[:organization].empty? && @org.nil?
        puts "Usage: bundle exec rails g planetscale:install --organization ORG_NAME"
        abort
      end

      @org ||= options[:organization]
    end 

    def create_psdb_configuration
      create_file "config/psdb.rb", "PSDB.start(org: '#{@org}')\n"
      inject_into_file "config/environment.rb", after: "require_relative \"application\"\n" do <<~'RUBY'
        require_relative "psdb"
      RUBY
      end
    end

    # todo(nickvanw): When we get rid of DB passwords, this can mostly go away, and we can just
    # return the `DATABSE_URL` that the user should use. 
    def print_database_yaml
      d =
      <<~EOS
      development:
        <<: *default
        username: root
        host: 127.0.0.1
        port: 3305
        password: <%= PSDB.database_password rescue nil %>
        database: #{@database}
      EOS

      puts "Installed!\n\nConfigure your database.yaml like so:\n".bold
      puts d

      return unless @database == "<db_name>"

      puts "\nswitch to your PlanetScale branch:\n".bold
      puts "pscale branch switch main --database #{@database}\n"
    end
  end 
end

class String
  def bold; "\e[1m#{self}\e[22m" end
end
