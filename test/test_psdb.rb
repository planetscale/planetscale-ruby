require 'minitest/autorun'
require 'planetscale'
require 'pry'

class PlanetScaleTest < Minitest::Test
  def test_empty_config
    assert_raises ArgumentError do
      PlanetScale::Proxy.new
    end
  end

  def test_environment_config
    p = PlanetScale::Proxy.new(branch: 'test', org: 'testorg', db: 'testdb')
    
    assert_equal p.instance_variable_get(:@db), 'testdb'
    assert_equal p.instance_variable_get(:@branch), 'test'
    assert_equal p.instance_variable_get(:@org), 'testorg'
    assert_equal p.instance_variable_get(:@auth_method), PlanetScale::Proxy::AUTH_AUTO
  end

  def test_auto_with_service_token
    p = PlanetScale::Proxy.new(branch: 'test', org: 'testorg', db: 'testdb', token_id: 123, token: 456)

    assert_equal p.instance_variable_get(:@auth_method), PlanetScale::Proxy::AUTH_SERVICE_TOKEN
  end
end
