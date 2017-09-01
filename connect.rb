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

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: connect.rb [options]"

  opts.on('-c', '--config FILE', 'Config file') { |v| options[:config_file] = v }
end.parse!

unless options[:config_file] && File.exists?(options[:config_file]) then
  STDERR.puts "Missing config file\n"
  abort
end

config = YAML.load_file(options[:config_file]) 
#pp config 

unless config['interface'] then
  STDERR.puts "Interface not configured\n"
  abort
end

# find interface address based on configuration
iface = Socket.getifaddrs.select { |ifaddr| 
  ifaddr.name == config['interface'] && ifaddr.addr.ipv4? 
}.map { |ifaddr| 
  { :name => ifaddr.name, :addr => ifaddr.addr.ip_address } 
}.first

# verify that pf.conf has relayd anchor 

if File.readlines('/etc/pf.conf').grep(/anchor \"relayd\/\*\"/).empty? then 
  puts "Adding relayd anchor to pf.conf, do you wish to proceed"

  if get_user_confirmation then
    open('/etc/pf.conf', 'a') do |f|
      f << "anchor \"relayd/*\"\n"
    end 
    %x( pfctl -d )
    %x( pfctl -e -f /etc/pf.conf )
  else 
    STDERR.puts "VPN Proxy will not work until you set relayd anchor to pf.conf.\nSee 'man 8 relayd' for more information"
  end
end 

# verify system configuration

if %x( sysctl net.inet.esp.enable ) != '0' then
  %x( sysctl net.inet.esp.enable=0 )
end

if %x( sysctl net.inet.esp.udpencap ) != '0' then
  %x( sysctl net.inet.esp.udpencap=0 )
end

if !config['ipsec']['gateway'] || !config['ipsec']['group'] || !config['ipsec']['user'] || !config['ipsec']['group_pw'] then
  STDERR.puts "One of mandatory VPNC configuration properties [ gateway | group | user | group_pw ] is missing\n"
  abort
end

open('/etc/vpnc/vpnhack.conf', 'w') do |vpnhack| 
  vpnhack << "IPSec gateway #{config['ipsec']['gateway']}\n"
  vpnhack << "IPSec ID #{config['ipsec']['group']}\n"
  vpnhack << "IPSec secret #{config['ipsec']['group_pw']}\n"
  vpnhack << "Xauth username #{config['ipsec']['user']}\n"
end

pp "Starting VPNC"

system 'vpnc vpnhack.conf'

if $? != 0 then 
  STDERR.puts "Failed to connect"
  abort 
end 

pp "Started VPNC"

open('/etc/relayd.conf', 'w') do |relaydconf| 
  relaydconf << "interval 5\n\n"

  config['relayd'].each do |relay| 
    if !relay['name'] || !relay['src_port'] || !relay['dst_port'] || !relay['dst_host'] then
      STDERR.puts "Ignoring #{relay}"
      next
    end

    relaydconf << "relay \"#{relay['name']}\" {\n"
    relaydconf << "  listen on #{iface[:addr]} port #{relay['src_port']}\n"
    relaydconf << "  forward to #{relay['dst_host']} port #{relay['dst_port']}\n"
    relaydconf << "}\n\n"
  end
end

pp "Starting relayd"

system 'relayd -v -f /etc/relayd.conf'

if $? != 0 then
  STDERR.puts "Failed to start relayd"
  abort
end 

pp "Started relayd"
