#!/usr/bin/env ruby

###
## 
# qworker: A beanstalk ruby library for solid job processing
# Copyright (C) 2011 Mathias Dalheimer (md@gonium.net)
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#  
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
##

# Simulates all kinds of errors. This is a test progrqm for the qworker
# external process interface.
require 'optparse'
require 'ostruct'

###
## Commandline parser
#
class Optparser
  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }
  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.inplace = false
    options.encoding = "utf8"
    options.verbose = false
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Specific options:"
      opts.on("-s", "--sleep TIME", "Number of seconds to sleep in order to simulate processing.") do |sleeptime|
        options.sleeptime = sleeptime.to_i
      end
      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do |v|
        options.verbose = v
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    opts.parse!(args)
    options
  end
end

###
## Script startup
#
options = Optparser.parse(ARGV)
$verbose = options.verbose
if options.sleeptime == nil
  puts "Please provide a sleep time value... (-h for details)."
  exit(-1);
end
NORMAL_EXECUTION_SLEEP=options.sleeptime
SLOW_EXECUTION_SLEEP=options.sleeptime * 2

#Signal.trap("KILL") { puts "Ouch!"; exit 99}

puts "Drunken sailor PID: #{$$}"

dice=rand(4);

case dice
when 0: # normal execution
  puts "Drunken Sailor: Normal execution." if $verbose
  sleep NORMAL_EXECUTION_SLEEP
  exit 0
when 1: # the process takes longer as expected for this task
  puts "Drunken Sailor: Slow execution." if $verbose
  sleep SLOW_EXECUTION_SLEEP
  exit 0
when 2: # the process exits with an error code
  puts "Drunken Sailor: Faulty execution." if $verbose
  exit 10
when 3: # infinite loop - does not terminate
  puts "Drunken Sailor: Infinite loop. " if $verbose
  while true
    sleep SLOW_EXECUTION_SLEEP
  end
else
  puts "Unknown dice value! All man abort ship!"
  exit 255
end

