#! /usr/bin/ruby -w

# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014

require './vendetta'
require 'pp'


if ARGV.size == 1
    file = ARGV[0]
    hosts = Vendetta::read_hosts('./../conf/hosts.txt')
    Vendetta::distribute(:hosts => hosts, :file =>file)
end
