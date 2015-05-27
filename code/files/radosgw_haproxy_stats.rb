#!/usr/bin/ruby
 
require 'socket'
STATSD_HOST = 'filer-carbon.cern.ch'
STATSD_PORT = 8125

HOSTNAME = `facter hostname`.chomp
SOCKET = UNIXSocket.new("/var/lib/haproxy/stats")
UDPSOCK = UDPSocket.new

SOCKET.puts("show stat")

# Parse the headers
header_line = SOCKET.gets
header_line.gsub!(/# /,'')
HEADERS = header_line.split(/,/)[0..-2]

# Read the data
while (line = SOCKET.gets) do
  next if line.length <= 1
  stats = Hash[HEADERS.zip($_.split(/,/))]
  #HEADERS.each do |statname|
  %w(scur smax qcur qmax bin bout ereq econ eresp rate check_duration).each do |statname|
    UDPSOCK.send("haproxy.#{HOSTNAME}.#{stats['pxname']}.#{stats['svname']}.#{statname}:#{stats[statname]}|g", 0, STATSD_HOST, STATSD_PORT)
    #puts("haproxy.#{HOSTNAME}.#{stats['pxname']}.#{stats['svname']}.#{statname}:#{stats[statname]}|g")
  end
end

