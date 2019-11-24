require "minitest/autorun"
require "minitest/server"
require "minitest/server_plugin"

require "minitest"
require "minitest/test"
require "minitest/server"
require "minitest/server_plugin"
require "minitest/autorun"

class BogoTests < Minitest::Test
  def pass_test
    assert true
  end

  def fail_test
    assert false, "fail"
  end

  def error_test
    raise "error"
  rescue => e
    e.instance_variable_set :@binding, binding # TODO: what is this for?
    raise e
  end

  def wtf_test
    assert false, "wtf"
  rescue Minitest::Assertion => e
    e.instance_variable_set :@proc, proc { 42 }
    raise e
  end
end

class TestServerReporter < Minitest::ServerReporter
  def record o
    super

    Marshal.dump o
  end
end

class Client
  def run pid, type
    reporter = TestServerReporter.new pid
    reporter.start

    reporter.record Minitest.run_one_method(BogoTests, "#{type}_test")
  end
end

class Server
  attr_accessor :results

  def self.run type = nil
    s = self.new
    s.run type
    s.results
  end

  def run type = nil
    Minitest::Server.run self

    Client.new.run $$, type
  ensure
    Minitest::Server.stop
  end

  def minitest_start
    # do nothing
  end

  def minitest_result(*vals)
    self.results = vals
  end
end

class ServerTest < Minitest::Test
  def test_pass
    assert_run "pass", [], 1
  end

  def test_fail
    assert_run "fail", ["fail"], 1
  end

  def test_error
    msg = ["RuntimeError: error\n    #{__FILE__}:21:in `error_test'"]
    assert_run "error", msg, 0
  end

  def test_wtf
    assert_run "wtf", ["wtf"], 1
  end

  def assert_run type, e, n
    act = Server.run type
    act[-1] = 0 # time
    act[-3].map!(&:message)

    exp = ["test/minitest/test_server.rb", "BogoTests", "#{type}_test", e, n, 0]

    assert_equal exp, act
  end
end
