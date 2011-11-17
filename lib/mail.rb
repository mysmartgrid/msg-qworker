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
require 'net/smtp'
require 'base64'

###
## Mailsend plug-in
#

class Msg_mail

  # to: array of recipients
  # msg: full message, including headers
  def self.send_mail(to, msg)
    Net::SMTP.start('smtp.mysmartgrid.de', 25, 'mysmartgrid.de', 'notifications@mysmartgrid.de', 'aiK6ahCh', :plain) do |smtp|
      to.each do |recpt|
        smtp.send_message(msg, "noreply@mysmartgrid.de", recpt)
      end
    end
  end

  # string: containing information regarding email such as: recipients, subject and body
  def self.extract_mail_payload(string)
    string = Base64::decode64(string)
    to = []
    header = ""
    subject = ""
    body = ""
    from = ""
    string.split(/\|/).each do |item|
      tag = item.split(/::/)
      case tag[0]
        when "Header"
          header = tag[1]
        when "To"
          to.push(tag[1])
        when "From"
	  from = tag[1]
        when "Subject"
	  subject = tag[1]
        when "Body"
          body = tag[1]
        else
          puts "Unexptected input: " + tag[0] + " -> Ignoring"
        end
    end
    msg = header + "\nFrom: " + from + "\nSubject: " + subject + "\n\n" + body
    return to, msg
  end
end
