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
require 'beanstalk-client'    # gem install beanstalk-client
require 'timeout'
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
if options.config_file == nil
  puts "Please provide a configuration file... (-h for details)."
  exit(-2);
end
if not File.exists?(options.config_file) 
  puts " Configuration file #{options.config_file} not found!"
  exit(-3);
else
  $CONFIG=YAML.load_file(options.config_file);
  puts "Using this configuration:" if $verbose
  puts $CONFIG.to_yaml if $verbose
  beanstalk_server=$CONFIG['BEANSTALK_SERVER']
  beanstalk_port=$CONFIG['BEANSTALK_PORT']
  $GRACE_TIME=$CONFIG['GRACE_TIME']
  result_basedir=$CONFIG['RESULT_BASEDIR']
  puts "---" if $verbose
end

if not File.directory?(result_basedir)
  puts "FATAL: Result directory does not exist, exiting."
  exit(-4)
end

puts "Starting producer, connecting to #{beanstalk_server}:#{beanstalk_port}" if $verbose
beanstalk=nil;
# Attempt to connect to beanstalkd. Do not loop and try to reconnect
# here! If the server is not reachable this can be a permanent error.
# The monit infrastructure will report this and automatically restart
# the worker. Just make sure to print a useful log message and exit
# with an error code.
begin 
  beanstalk = Beanstalk::Pool.new(["#{beanstalk_server}:#{beanstalk_port}"]) 
rescue 
  puts "FATAL: Cannot connect to beanstalk server. Exiting."
  exit 1
end

loop do
  job = beanstalk.reserve
  begin
    payload_json=job.body 
    payload=JSON.parse(payload_json)
    header=payload[0]
    job_uuid=header['uuid']
    # calculate the result directory of the job. An HTTP server exports
    # this directory to external clients.
    job_result_path="#{result_basedir}/#{job_uuid[0..1]}/#{job_uuid}"
    job_type=header['type']
    body=payload[1]
    puts
    puts "### Dequeued job #{job_uuid}, algorithm #{job_type}"
    puts " + result directory: #{job_result_path}"
    puts " + input data: #{body}"
    # after a timeout, beanstalk puts the job back into the queue.
    puts " + time left for processing: #{job.time_left()}"
    puts " + job queue priority: #{job.pri()}"
    
    # Be careful! Only delete the job if the algorithm was really
    # successful. This means that if you start external processes, you
    # MUST evaluate the return code. If the external process failed,
    # release the job so that it is still in the queue (and other
    # consumers can process it)
    pid=0;
    first_dir="#{result_basedir}/#{job_uuid[0..1]}"
    Dir.mkdir(first_dir) unless File.directory?(first_dir)
    second_dir="#{result_basedir}/#{job_uuid[0..1]}/#{job_uuid}"
    Dir.mkdir(second_dir) unless File.directory?(second_dir)
    #TODO: Pass the result path to the job 
    begin
      timeout(job.time_left() + $GRACE_TIME) {
        pid = Process.fork
        if pid.nil? then
          # In child: Execute the algorithm. Decide which program to
          # execute here.
          case job_type
          when "drunken_sailor"
            sailor_bin = File.join(File.dirname(__FILE__), "drunken_sailor.rb")
            exec "ruby", sailor_bin, "-s", "#{job.time_left()}", "-v"
          when "sleep"
            exec "sleep", "#{job.time_left()}"
	  when "mail"
            to, msg = Msg_mail::extract_mail_payload(body['payload'])
	    Msg_mail::send_mail(to, msg)
	    exec "true"
          else
            puts "Unknown job type: #{job_type} - ignoring job."
          end
        else
          # In parent
          Process.wait(pid)
        end
      }
      puts "Algorithm terminated within expected time constraints."
      exitstatus=$?.exitstatus;
      puts "Algorithm terminated with exitstatus #{exitstatus}"
      if (exitstatus == 0)
        puts "Job completed, removing from queue."
        job.delete
      else
        puts "Job failed, leaving job in queue."
        begin
          job.release
        rescue Beanstalk::NotFoundError => e
          puts "Job not found, cannot release it. Ignoring."
        end
      end
    rescue Timeout::Error 
      puts "Algorithm did not terminate within expected timeframe."
      puts "Attempting to kill algorithm PID #{pid}"
      Process.kill("KILL", pid)
      Process.wait(pid)
      begin
        job.release
      rescue Beanstalk::NotFoundError => e
        puts "Job not found, cannot release it. Ignoring."
      end
    end
  rescue Exception => e
    puts "Unexpected problem during job execution: #{e} - Releasing job."
    begin
      job.release
    rescue Beanstalk::NotFoundError => e
      puts "Job not found, cannot release it. Ignoring."
    end
  end
end

# The consumer should never leave the loop. If this happens, an error
# occured, so just leave gracefully.
puts "Worker node left main loop - exiting."
exit 2
