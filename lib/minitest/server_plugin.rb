require "minitest"

module Minitest
  @server = false

  def self.plugin_server_options opts, options # :nodoc:
    opts.on "--server=pid", Integer, "Connect to minitest server w/ pid." do |s|
      @server = s
    end
  end

  def self.plugin_server_init options
    if @server then
      require "minitest/server"
      self.reporter << Minitest::ServerReporter.new(@server)
    end
  end
end

class Minitest::ServerReporter < Minitest::AbstractReporter
  def initialize pid
    uri = Minitest::Server.path(pid)
    @mt_server = DRbObject.new_with_uri uri
    super()
  end

  def start
    @mt_server.start
  end

  def record result
    r = result
    c = r.class
    file, = c.instance_method(r.name).source_location
    sanitize r.failures

    @mt_server.result file, c.name, r.name, r.failures, r.assertions, r.time
  end

  def sanitize failures
    failures.map! { |e|
      case e
      when Minitest::UnexpectedError then
        # embedded exception might not be able to be marshaled.
        bt = e.exception.backtrace

        ex = RuntimeError.new(e.message)
        e.exception = ex
        ex.set_backtrace bt

        if ex.instance_variables.include? :@bindings then # web-console is Evil
          ex.instance_variable_set :@bindings, nil
          e.instance_variable_set  :@bindings, nil
        end
      end

      e
    }
  end

  def report
    @mt_server.report
  end
end
