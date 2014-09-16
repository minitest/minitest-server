require "minitest/autorun"
require "minitest/server"

module TestMinitest; end

class TestMinitest::TestServer < Minitest::Test
  def test_sanity
    flunk "write tests or I will kneecap you"
  end
end
