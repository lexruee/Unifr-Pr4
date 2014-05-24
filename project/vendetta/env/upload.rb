#! /usr/bin/ruby -w

# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014

require './vendetta'
require 'pp'

if ARGV.size == 2
    host,file = ARGV
    user, hostname = host.split("@")
    host = {:host => hostname, :user=> user}
    Vendetta::upload_file(:file => file, :host => host)
end
