require 'parallel'

module ParallelSplitTest
  class << self
    attr_accessor :example_counter, :processes, :process_number, :ramp_up_time

    def ramp_up_time
      return 0 if ENV['RAMP_UP_TIME'].nil?
      ENV['RAMP_UP_TIME']
    end

    def run_example?
      self.example_counter += 1
      (example_counter - 1) % processes == process_number
    end

    def choose_number_of_processes
      self.processes = best_number_of_processes
    end

    def best_number_of_processes
      [
        ENV['PARALLEL_SPLIT_TEST_PROCESSES'],
        Parallel.physical_processor_count,
        Parallel.processor_count
      ].map(&:to_i).find{|number| number > 0 }
    end
  end
end
