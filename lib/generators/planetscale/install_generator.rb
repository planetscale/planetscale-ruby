require 'rails/generators'

class Planetscale
  class InstallGenerator < Rails::Generators::Base    
    class_option :organization, type: :string, default: ''

    def check_org
      if options[:organization].empty?
        puts "Usage: bundle exec rails g planetscale:install --organization ORG_NAME"
        abort
      end
    end 

    def create_psdb_configuration
      create_file "config/psdb.rb", "PSDB.start(org: '#{options[:organization]}')"
      inject_into_file "config/environment.rb", after: "require_relative \"application\"\n" do <<-'RUBY'
require_relative "psdb"
      RUBY
      end
    end

    def print_database_yaml
      d =
      <<~EOS
      development:
        <<: *default
        username: root
        host: 127.0.0.1
        port: 3305
        password: <%= PSDB.database_password rescue nil %>
        database: <db_name>
      EOS

      puts "Installed!\n\nConfigure your database.yaml like so:\n".bold
      puts d
      puts "\nswitch to your PlanetScale branch:\n".bold
      puts "pscale branch switch main --database <db_name>\n"
    end
  end 
end

class String
  def bold;           "\e[1m#{self}\e[22m" end
end
