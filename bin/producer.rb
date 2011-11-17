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

# Read the qworker location 
libpath=File.join(File.dirname(__FILE__), '..', 'lib')
$:.unshift << libpath 
#puts "Using libraty path #{$:.join(":")}"

require 'rubygems'
require 'json'
require 'pp'
require 'beanstalk-client'    # gem install beanstalk-client
require 'uuid'                # gem install uuid
require 'optparse'
require 'ostruct'
require 'mail.rb'


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
      opts.on("-c", "--config FILE", "The file where the configuration lives.") do |file|
        options.config_file = file
      end
      opts.on("-a", "--algorithm TYPE ", "The algorithm to execute, 'drunken_sailor', 'sleep' or 'mail'.") do |type|
        options.alg_type = type
      end
      opts.on("-p", "--payload STRING ", "Payload depending on algorithm") do |pl|
        options.payload = pl
      end
      # Boolean switch.
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
if (options.alg_type != "drunken_sailor" and options.alg_type != "sleep" and options.alg_type != "mail")
  puts "Please provide a valid algorithm type... (-h for details)."
  exit(-1);
end
if options.config_file == nil
  puts "Please provide a configuration file... (-h for details)."
  exit(-2);
end
if not File.exists?(options.config_file) 
  puts " Configuration file #{options.config_file} not found - no database configuration available!"
  exit(-3);
else
  $CONFIG=YAML.load_file(options.config_file);
  puts "Using this configuration:" if $verbose
  puts $CONFIG.to_yaml if $verbose
  beanstalk_server=$CONFIG['BEANSTALK_SERVER']
  beanstalk_port=$CONFIG['BEANSTALK_PORT']
  puts "---" if $verbose
end
if (options.alg_type == "mail" and !options.payload)
  puts "Please specify a payload for algorithm 'mail'"
  exit(-4)
end

puts "Starting producer, connecting to #{beanstalk_server}:#{beanstalk_port}" if $verbose

beanstalk=nil;
uuidgen=UUID.new();

# Attempt to connect to beanstalkd. Do not loop and try to reconnect
# here! If the server is not reachable this can be a permanent error.
# The monit infrastructure will report this and automatically restart
# the worker. Just make sure to print a useful log message and exit
# with an error code.
# The Drupal website would do this differently: A pool is maintained by
# the website. A PHP module for this is pheanstalk:
#   https://github.com/pda/pheanstalk/

begin 
  beanstalk = Beanstalk::Pool.new(["#{beanstalk_server}:#{beanstalk_port}"]) 
rescue 
  puts "Cannot connect to beanstalk server. Exiting."
  exit 1
end

# Create a work package. This MUST be formatted as a JSON array, with
# two parts: A hash that contains the metadata (UUID and jobtype)
# and another hash containing the payload. The UUID will be used to 
# publish the results. The algorithm identifies the worker binary to
# run.
# The UUID MUST be a 32 digit hexadecimal number such as 
#   137753108f59012eaa2c549a20077664
uuid=uuidgen.generate(format=:compact);
payload=[
  {'uuid' => uuid, 'type' => options.alg_type}, 
  {'foo' => 'bar', '23' => '42', 'payload' => options.payload}
]
json_payload=JSON.generate(payload);
puts "generated work package: #{json_payload}"

# Now, put the work package in the default tube.
begin
  beanstalk.put(
      json_payload,   # Content of the job.
      pri=1337,       # Priority of this job. <1024 is considered urgent.
      delay=0,        # Should the job be delayed for X seconds?  
      ttr=3          # Seconds until the job will be re-queued.
   )
rescue
  puts "Cannot put work package in the tube."
end

