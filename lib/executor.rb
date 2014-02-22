require 'securerandom'
require 'bundler/setup'
$load_god = true
require 'god'
require 'executor/god_extensions'

class Executor
  def initialize(options, god_options)
    @options = options
    @god_options = god_options
    start_watching
    $run = true
  end


  def start_watching
    ::God.log_level = :debug
    ::God::EventHandler.load
    ::God::EventHandler.start

    ::God.watch do |w|
      w.name = name
      w.pid_file = File.join(God.pid_file_directory, "#{name}.pid")
      w.start = @options[:command]
      w.stop = lambda do
        w.driver.shutdown
      end

      w.log_cmd = "echo -n"
      w.err_log_cmd = "echo -n"
      w.interval = 2
      w.behavior :http_logging do |b|
        b.uri = @options[:collector]
        b.default_params = {
          :name => name,
          :jid => jid
        }
      end

      # start the process immediately
      w.transition(:init, :start)

      # determine when process has finished start
      w.transition(:start, :up) do |on|
        on.condition(:process_running) do |c|
          c.running = true
        end

        # failsafe
        on.condition(:tries) do |c|
          c.times = 1
          c.transition = :stop
        end
      end

      # mark as done if the process goes from up to stop
      w.transition(:up, :stop) do |on|
        on.condition(:process_exits)
      end
    end
  end

  private

  def name
    @name ||= "#{@options[:namespace]}-#{jid}"
  end

  def jid
    @jid ||= SecureRandom.hex
  end
end
