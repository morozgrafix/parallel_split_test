require 'parallel_split_test'
require 'parallel_split_test/output_recorder'
require 'parallel'
require 'rspec'
require 'parallel_split_test/core_ext/rspec_example'

module ParallelSplitTest
  class CommandLine < RSpec::Core::Runner
    def initialize(args)
      @args = args
      super
    end

    def run(err, out)
      no_summary = @args.delete('--no-summary')
      no_merge = @args.delete('--no-merge')

      @options = RSpec::Core::ConfigurationOptions.new(@args)

      processes = ParallelSplitTest.choose_number_of_processes
      out.puts "Running examples in #{processes} processes"
      out.puts "Ramp up time: #{ParallelSplitTest.ramp_up_time}"

      results = Parallel.in_processes(processes) do |process_number|
        # binding.pry
        ParallelSplitTest.example_counter = 0
        ParallelSplitTest.process_number = process_number
        set_test_env_number(process_number)
        modify_out_file_in_args(process_number) if out_file
        out = OutputRecorder.new(out)
        setup_copied_from_rspec(err, out)

        delay = delay_before_each_thread(ParallelSplitTest.ramp_up_time.to_f) * ParallelSplitTest.process_number
        puts "Process No.#{ParallelSplitTest.process_number} will be delayed for #{delay.to_s} seconds"
        # puts "#{Time.now}: Process No. #{ParallelSplitTest.process_number} before sleep"
        sleep delay
        # puts "#{Time.now}: Process No. #{ParallelSplitTest.process_number} after sleep"

        [run_group_of_tests, out.recorded]
      end


      combine_out_files if out_file unless no_merge

      reprint_result_lines(out, results.map(&:last)) unless no_summary
      results.map(&:first).max # combine exit status
    end

    private

    # modify + reparse args to unify output
    def modify_out_file_in_args(process_number)
      @args[out_file_position] = "#{out_file_basename}.#{process_number}#{File.extname(out_file)}"
      @options = RSpec::Core::ConfigurationOptions.new(@args)
    end

    def set_test_env_number(process_number)
      ENV['TEST_ENV_NUMBER'] = (process_number == 0 ? '' : (process_number + 1).to_s)
    end

    def out_file
      @out_file ||= @args[out_file_position] if out_file_position
    end

    def out_file_basename
      @out_file_basename ||= File.basename(out_file, File.extname(out_file))
    end

    def out_file_position
      @out_file_position ||= begin
        if out_position = @args.index { |i| ["-o", "--out"].include?(i) }
          out_position + 1
        end
      end
    end

    def combine_out_files
      File.open(out_file, "w") do |f|
        Dir["#{out_file_basename}.*#{File.extname(out_file)}"].each do |file|
          f.write File.read(file)
          File.delete(file)
        end
      end
    end

    def reprint_result_lines(out, printed_outputs)
      out.puts
      out.puts "Summary:"
      out.puts printed_outputs.map{|o| o[/.*\d+ failure.*/] }.join("\n")
    end

    def run_group_of_tests
      example_count = @world.example_count / ParallelSplitTest.processes
      # delay = delay_before_each_thread(ENV['RAMP_UP_TIME'].to_i) * ParallelSplitTest.process_number
      # puts "#{ParallelSplitTest.process_number} process would sleep #{delay.to_s}"
      # # puts "#{Time.now}: Process No. #{ParallelSplitTest.process_number} before sleep"
      # sleep delay
      # # puts "#{Time.now}: Process No. #{ParallelSplitTest.process_number} after sleep"

      @configuration.reporter.report(example_count) do |reporter|
        groups = @world.example_groups
        results = groups.map {|g| g.run(reporter)}
        results.all? ? 0 : @configuration.failure_exit_code
      end
    end

    # calculate ramp-up delay before number of threads
    def delay_before_each_thread(ramp_up_time)
      # binding.pry if ParallelSplitTest.process_number == 1
      # ramp_up_time/(ParallelSplitTest.choose_number_of_processes - 1)
      processes = ParallelSplitTest.choose_number_of_processes

      processes == 1 ? 0 : (ramp_up_time / (processes - 1)).round(2)
    end

    # https://github.com/rspec/rspec-core/blob/6ee92a0d47bcb1f3abcd063dca2cee005356d709/lib/rspec/core/runner.rb#L93
    def setup_copied_from_rspec(err, out)
      @configuration.error_stream = err
      @configuration.output_stream = out if @configuration.output_stream == $stdout
      @options.configure(@configuration)
      @configuration.load_spec_files
      @world.announce_filters
    end
  end
end
