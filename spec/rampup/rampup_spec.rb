# spec/xxx_spec.rb
require "spec_helper"

naptime = 2

describe "Ramp Up" do
  13.times do |x|
    it "test No. #{x}" do
      puts "test #{x} sleeps for #{naptime} seconds run by process No.#{ParallelSplitTest.process_number}"
      sleep naptime
    end
  end
end