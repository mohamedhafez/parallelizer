# -*- encoding : utf-8 -*-

# used to call java code
require 'java'

# 'java_import' is used to import java classes
java_import 'java.util.concurrent.Callable'
java_import 'java.util.concurrent.FutureTask'
java_import 'java.util.concurrent.LinkedBlockingQueue'
java_import 'java.util.concurrent.ThreadPoolExecutor'
java_import 'java.util.concurrent.TimeUnit'

# get our DefaultDaemonThreadFactory class, so that the process will be able to end even
# if we haven't explicitly shut down the pool (the default thread factory marks its threads as
# non-daemon, which keeps the JVM from exiting until they are explicitly shut down)
require "parallelizer/org.rubygems.parallelizer.jar"
java_import 'org.rubygems.parallelizer.DefaultDaemonThreadFactory'


class Parallelizer
  class RejectedExecutionError < RuntimeError
  end

  attr_accessor :max_acceptable_delay, :delayed_too_long_proc

  def initialize ops={} #:core_pool_threads, :max_pool_threads, :keep_alive_time, :max_acceptable_delay, :delayed_too_long_proc, :prestart_all_core_threads
  core_pool_threads = ops[:core_pool_threads] || 10
    max_pool_threads = ops[:max_pool_threads] || 10
    raise "Parallelizer core_pool_threads greater than max_pool_threads!" if core_pool_threads > max_pool_threads

    @pool = ThreadPoolExecutor.new(core_pool_threads,
                                   max_pool_threads,
                                   ops[:keep_alive_time] || 60,
                                   TimeUnit::SECONDS,
                                   LinkedBlockingQueue.new,
                                   DefaultDaemonThreadFactory.new)

    @max_acceptable_delay = ops[:max_acceptable_delay]
    @delayed_too_long_proc = ops[:delayed_too_long_proc]

    prestart_all_core_threads if ops[:prestart_all_core_threads]
  end

  def prestart_all_core_threads
    @pool.prestartAllCoreThreads
  end

  def shutdown
    @pool.shutdown
  end

  def await_termination(seconds)
    @pool.await_termination(seconds, TimeUnit::SECONDS)
  end

  #works like a normal map, but in parallel, and also if an exception is raised that exception
  #will be stored in that index instead of the result
  def map enumerator, &proc
    run_computation_array enumerator.map {|arg| Computation.new(self, proc, arg) }
  end

  #expects an array of procs
  def run array
    run_computation_array array.map {|proc| Computation.new(self, proc) }
  end

  protected

  # Implement a callable class
  class Computation
    include Callable

    attr_accessor :results_array, :result_index, :execution_requested_time

    def initialize parallelizer, proc, argument=nil
      @parallelizer = parallelizer
      @proc = proc
      @argument = argument
    end

    def call
      begin
        test_delay
        @results_array[@result_index] = @argument ? @proc.call(@argument) : @proc.call
      rescue
        @results_array[@result_index] = $!
      end
    end

    def test_delay
      delay = nil
      if @parallelizer.max_acceptable_delay && @parallelizer.delayed_too_long_proc && @execution_requested_time &&
          (delay = Time.now.to_f - @execution_requested_time.to_f) > @parallelizer.max_acceptable_delay
        @parallelizer.delayed_too_long_proc.call(delay)
      end
    end
  end

  def run_computation_array computation_array
    results_array = Array.new(computation_array.size)
    future_tasks = []
    computation_array.each_with_index {|comp, i|
      comp.results_array = results_array
      comp.result_index = i
      comp.execution_requested_time = Time.now

      if i < computation_array.size - 1
        task = FutureTask.new(comp)

      begin
        @pool.execute task
      rescue Java::JavaUtilConcurrent::RejectedExecutionException
        raise RejectedExecutionException.new($!.message)
      end

        
        future_tasks << task
      else #last element, run it in this thread
        comp.call
      end
    }

    future_tasks.each {|task| task.get } #wait for all tasks to complete
    results_array
  end
end
