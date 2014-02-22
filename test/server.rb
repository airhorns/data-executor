require 'uri'
require 'net/http'
require 'rack'
require 'rack/handler/thin'
require 'oj'

class Server
  class Middleware
    attr_accessor :error

    def initialize(app)
      @app = app
    end

    def call(env)
      if env["PATH_INFO"] == "/__identify__"
        [200, {}, [@app.object_id.to_s]]
      else
        begin
          @app.call(env)
        rescue StandardError => e
          @error = e unless @error
          raise e
        end
      end
    end
  end

  class << self
    def ports
      @ports ||= {}
    end
  end

  attr_reader :app, :port, :host, :server_thread

  def initialize(app, port = 7789)
    @app = app
    @middleware = Middleware.new(@app)
    @server_thread = nil # supress warnings
    @host = "0.0.0.0"
    @port = port || find_available_port
  end

  def reset_error!
    @middleware.error = nil
  end

  def error
    @middleware.error
  end

  def responsive?
    return false if @server_thread && @server_thread.join(0)

    res = Net::HTTP.start(@host, @port) { |http| http.get('/__identify__') }
    if res.is_a?(Net::HTTPSuccess) or res.is_a?(Net::HTTPRedirection)
      return res.body == @app.object_id.to_s
    end
  rescue SystemCallError
    return false
  end

  def boot
    unless responsive?
      @server_thread = Thread.new do
        Rack::Handler::Thin.run(@middleware, :Host => @host, :Port => @port)
      end

      Timeout.timeout(60) do
        until responsive?
          @server_thread.join(0.1)
        end
      end
    end
  rescue Timeout::Error
    raise "Rack application timed out during boot"
  else
    self
  end

private

  def find_available_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1]
  ensure
    server.close if server
  end
end

if __FILE__ == $0
  app = proc do |env|
    puts
    puts env['rack.input'].read
    #puts Oj.load(env['rack.input'].read)
    [200, {}, ['Hello Server!']]
  end
  $server = Server.new(app).boot
  $server.server_thread.join
end
