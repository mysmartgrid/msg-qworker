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

require 'rubygems'
require 'base64'

###
## Msg Raspberry PI image plug-in
#

class Msg_rasp_image

  # string: Make EMOS base station image
  def self.make_image(string)
    string = Base64::decode64(string)
    id = ""
    ip = ""
    gateway = ""
    netmask = ""
    string.split(/\|/).each do |item|
      tag = item.split(/::/)
      case tag[0]
        when "id"
          id = tag[1]
        when "ip"
          ip = tag[1]
        when "gateway"
	  gateway = tag[1]
        when "netmask"
	  netmask = tag[1]
        else
          puts "Unexptected input: " + tag[0] + " -> Ignoring"
        end
    end
    exec( "/usr/local/bin/rasp_mkimage.sh template=/var/tmpdata/raspi-image.img target=" + id + " netmask=" + netmask + " gateway=" + gateway + " ip=" + ip + " &" )
  end
end
