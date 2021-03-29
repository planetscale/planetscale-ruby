require 'rails/generators'

class Planetscale
  class InstallGenerator < Rails::Generators::Base    

    def create_psdb_configuration
      create_file "config/psdb.rb", "PSDB.start"
      inject_into_file "config/environment.rb", after: "require_relative \"application\"\n" do <<-'RUBY'
require_relative "psdb"
      RUBY
      end
    end
  end 
end
