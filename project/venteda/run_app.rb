# Simple Venteda program
#
# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014
#
# A simple program written in ruby that uses venteda.
# It deploys the app on the cluster and runs it.

require './env/venteda'


puts "Run app venteda/CM2 using venteda!"

# simple config
conf = {
    :package => "venteda",
    :app => "CM",
    :function => "cm2:start(\"./graphs/graph.txt\")",
    :max_hosts => 5,
    :host_file => "./conf/hosts.txt"
}

# run the config
Venteda::run(conf)
