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
  end 
end
