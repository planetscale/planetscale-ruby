require 'minitest/autorun'
require 'psdb'
require 'pry'

class PSDBTest < Minitest::Test
  def test_empty_config
    assert_raises ArgumentError do
      PSDB::Proxy.new
    end
  end

  def test_environment_config
    p = PSDB::Proxy.new(branch: 'test', org: 'testorg', db: 'testdb')
    
    assert_equal p.instance_variable_get(:@db), 'testdb'
    assert_equal p.instance_variable_get(:@branch), 'test'
    assert_equal p.instance_variable_get(:@org), 'testorg'
    assert_equal p.instance_variable_get(:@auth_method), PSDB::Proxy::AUTH_AUTO
  end

  def test_auto_with_service_token
    p = PSDB::Proxy.new(branch: 'test', org: 'testorg', db: 'testdb', token_id: 123, token: 456)

    assert_equal p.instance_variable_get(:@auth_method), PSDB::Proxy::AUTH_SERVICE_TOKEN
  end
end
