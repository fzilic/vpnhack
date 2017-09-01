#!/usr/bin/env ruby

require 'etc'
require 'yaml'
require 'optparse'
require 'socket'
require 'pp'

require_relative 'functions' 

unless Etc.getpwuid(Process.euid).name == "root" then
  STDERR.puts "Must run as root.\n"
  abort
end

system 'pkill vpnc' 

if $? != 0 then 
  STDERR.puts "Failed stop vpnc"
end 

system 'pkill relayd'

if $? != 0 then
  STDERR.puts "Failed to stop relayd"
end 
