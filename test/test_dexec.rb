require "test_helper"
require "tmpdir"

DEXEC_BINARY_LOCATION = File.expand_path(File.dirname(__FILE__) + "/../bin/dexec")
$queue = Queue.new
app = Proc.new do |env|
  $queue << Oj.load(env['rack.input'].read)
  [200, {}, ['Hello Server!']]
end

$server = Server.new(app, nil).boot

def dexec(command)
  result = %x[ #{DEXEC_BINARY_LOCATION} --collector=http://127.0.0.1:#{$server.port} -- #{command}]
  assert_equal 0, $?.exitstatus
  result
end

def collect_dexec(command)
  $queue.clear()
  dexec(command)
  results = []
  results << $queue.pop() until $queue.empty?
  results
end

class TestSuccessfulDexec < Minitest::Unit::TestCase
  class << self
    attr_accessor :data
  end

  def data
    self.class.data ||= collect_dexec("exit")
  end

  def test_success_is_written_to_collector
    assert_equal 0, data[1][:exit_code]
  end

  def test_env_is_captured
    assert_equal data[0][:user], ENV["USER"]
  end

  def test_start_and_end_time_are_captured
    assert data[0][:time] <= Time.now.utc
    assert data[1][:time] <= Time.now.utc
  end
end

class TestFailureDexec < Minitest::Unit::TestCase
  class << self
    attr_accessor :data
  end

  def data
    self.class.data ||= collect_dexec("exit 2")
  end

  def test_error_is_written_to_collector
    assert_equal 2, data[1][:exit_code]
  end

  def test_command_completes_if_no_collector_is_running
    file = "#{Dir.mktmpdir}/ran"
    %x[ #{DEXEC_BINARY_LOCATION} --collector=http://0.0.0.0:1 -- touch #{file} ]
    assert File.exist?(file)
  end
end
