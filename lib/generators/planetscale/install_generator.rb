require 'rails/generators'

class Planetscale
  class InstallGenerator < Rails::Generators::Base
    class_option :organization, type: :string, default: ''

    def read_config
      @database = "<db_name>"
      file_path = File.join(Rails.root, PlanetScale::Proxy::PLANETSCALE_FILE)
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

    APPLICATION_REQUIRE_REGEX = /(require_relative ("|')application("|')\n)/.freeze

    def create_planetscale_config
      create_file "config/planetscale.rb", "PlanetScale.start(org: '#{@org}')\n"
      inject_into_file "config/environment.rb", after: APPLICATION_REQUIRE_REGEX do <<~'RUBY'
        require_relative "planetscale"
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
        database: #{@database}
      EOS


      db_url = "mysql2://root:@127.0.0.1:3305/#{@database}"
      puts "Installed!\n\nConfigure your database.yaml like so:\n".bold
      puts d
      puts "\nOr set DATABASE_URL=#{db_url}"
    end
  end
end

class String
  def bold; "\e[1m#{self}\e[22m" end
end
