#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'beanstalk-client'    # gem install beanstalk-client
require 'uuid'                # gem install uuid

beanstalk_server='localhost:11300'
puts "Starting producer, connecting to #{beanstalk_server}"

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
  beanstalk = Beanstalk::Pool.new([beanstalk_server]) 
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
  {'uuid' => uuid, 'type' => 'sleep'}, 
  {'foo' => 'bar', '23' => '42'}
]
json_payload=JSON.generate(payload);
#puts "generated work package: #{json_payload}"

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

