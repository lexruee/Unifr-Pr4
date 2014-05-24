#! /usr/bin/ruby -w

# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014

require './venteda'
require 'pp'

if ARGV.size == 2
    host,file = ARGV
    user, hostname = host.split("@")
    host = {:host => hostname, :user=> user}
    Venteda::upload_file(:file => file, :host => host)
end
