require 'minitest/autorun'
require 'planetscale'
require 'pry'

class PlanetscaleTest < Minitest::Test
  def test_empty_config
    assert_raises ArgumentError do
      Planetscale::Proxy.new
    end
  end

  def test_environment_config
    p = Planetscale::Proxy.new(branch: 'test', org: 'testorg', db: 'testdb')
    
    assert_equal p.instance_variable_get(:@db), 'testdb'
    assert_equal p.instance_variable_get(:@branch), 'test'
    assert_equal p.instance_variable_get(:@org), 'testorg'
    assert_equal p.instance_variable_get(:@auth_method), Planetscale::Proxy::AUTH_AUTO
  end

  def test_auto_with_service_token
    p = Planetscale::Proxy.new(branch: 'test', org: 'testorg', db: 'testdb', token_id: 123, token: 456)

    assert_equal p.instance_variable_get(:@auth_method), Planetscale::Proxy::AUTH_SERVICE_TOKEN
  end
end
