#! /usr/bin/ruby -w

# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014

require './vendetta'
require 'pp'

hosts = Vendetta::read_hosts('./../conf/hosts.txt')
available = Array.new
not_available = Array.new
hosts.each do |host|
    res = `ping #{host[:host]} -c 1`
    if Vendetta::ping(host[:host])
        available << host
    else
        not_available << host
    end
end

puts "Vendetta pinger"
puts "number of available hosts %s" % available.size
puts "available hosts:"
available.each do |host|
    puts host[:host]
end
