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
  end

  def unmarshalable_ivar_test
    raise "error"
  rescue => e
    e.instance_variable_set :@binding, binding
    raise
  end

  def unmarshalable_class_test
    exc = Class.new RuntimeError
    raise exc, "error"
  rescue => e
    e.instance_variable_set :@binding, binding
    raise
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

  FILE = __FILE__.delete_prefix "#{Dir.pwd}/"

  def test_error
    msg = <<~EOM.chomp
      RuntimeError: error
          #{FILE}:21:in `error_test'
    EOM

    assert_run "error", [msg], 0
  end

  def test_error_unmarshalable__ivar
    msg = <<~EOM.chomp
      RuntimeError: error
          #{FILE}:25:in `unmarshalable_ivar_test'
    EOM

    assert_run "unmarshalable_ivar", [msg], 0
  end

  def test_error_unmarshalable__class
    msg = <<~EOM.chomp
      RuntimeError: Neutered Exception #<Class:0xXXXXXX>: error
          #{FILE}:33:in `unmarshalable_class_test'
    EOM

    assert_run "unmarshalable_class", [msg], 0
  end

  def test_wtf
    assert_run "wtf", ["wtf"], 1
  end

  def assert_run type, e, n
    act = Server.run type
    act[-1] = 0 # time
    act[-3].map!(&:message)

    act[-3][0].gsub!(/0x\h+/, "0xXXXXXX") if act[-3][0]

    exp = ["test/minitest/test_server.rb", "BogoTests", "#{type}_test", e, n, 0]

    assert_equal exp, act
  end
end
