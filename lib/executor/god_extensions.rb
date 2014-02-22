require 'httpclient'
require 'httpclient/include_client'
require 'oj'

class God::Behaviors::HttpLogging < God::Behavior
  extend HTTPClient::IncludeClient
  include_http_client

  HTTP_EXCEPTIONS = [
    Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, EOFError,
    HTTPClient::BadResponseError, HTTPClient::ConnectTimeoutError, HTTPClient::KeepAliveDisconnected,
    HTTPClient::ReceiveTimeoutError, HTTPClient::RetryableResponse, HTTPClient::SendTimeoutError,
    HTTPClient::TimeoutError
  ]

  attr_accessor :uri
  attr_accessor :default_params

  def after_start
    send_update(:state => :started,
                :user => ENV['USER'],
                :command => self.watch.start,
                :host => `hostname`.chomp
               )
    nil
  end

  def after_stop
    send_update(:state => :finished, :exit_code => self.watch.exit_code)
    nil
  end

  def name
    friendly_name
  end

  private

  def send_update(params)
    all_params = {:time => Time.now.utc}.merge!(Hash(default_params)).merge!(params)
    applog(self, :info, "Sending status update to #{uri} with: #{all_params}")

    self.http_client.post(uri, body: Oj.dump(all_params))
  rescue *HTTP_EXCEPTIONS => exception
    applog(self, :error, "Status update to #{uri} failed with: #{exception}")
  end
end
