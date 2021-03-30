require 'minitest/autorun'
require 'psdb'

class PSDBTest < Minitest::Test
  def test_english_hello
    assert_equal "hello world",
      "hello world"
  end
end
