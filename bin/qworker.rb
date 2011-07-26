#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'beanstalk-client'    # gem install beanstalk-client
require 'timeout'

$GRACE_TIME=2

beanstalk_server='localhost:11300'
puts "Starting consumer, connecting to #{beanstalk_server}"

beanstalk=nil;

# Attempt to connect to beanstalkd. Do not loop and try to reconnect
# here! If the server is not reachable this can be a permanent error.
# The monit infrastructure will report this and automatically restart
# the worker. Just make sure to print a useful log message and exit
# with an error code.
begin 
  beanstalk = Beanstalk::Pool.new([beanstalk_server]) 
rescue 
  puts "Cannot connect to beanstalk server. Exiting."
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
    job_result_path="#{job_uuid[0..1]}/#{job_uuid}"
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
    begin
      timeout(job.time_left() + $GRACE_TIME) {
        pid = Process.fork
        if pid.nil? then
          # In child: Execute the algorithm. Decide which program to
          # execute here.
          case job_type
          when "drunken_sailor":
            exec "ruby", "drunken_sailor.rb", "-s", "#{job.time_left()}", "-v"
          when "sleep":
            exec "sleep", "#{job.time_left()}"
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
