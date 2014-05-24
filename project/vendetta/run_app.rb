# Simple Vendetta program
#
# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014
#
# A simple program written in ruby that uses vendetta.
# It deploys the app on the cluster and runs it.

require './env/vendetta'


puts "Run app vendetta/CM2 using vendetta!"

# simple config
conf = {
    :package => "vendetta",
    :app => "CM",
    :function => "cm2:start(\"./graphs/graph.txt\")",
    :max_hosts => 5,
    :host_file => "./conf/hosts.txt"
}

# run the config
Vendetta::run(conf)
