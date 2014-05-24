# encoding: utf-8

# Venteda runner
#
# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014
#
# This program runs an erlang application.
#
# It needs 3 parameters: 
# package name, app name and the name of erlang function to execute.
#
# Optional parameters are: arguments to the erlang function and the number of hosts.
#
# start.rb package app function [function arg, [max hosts]]
#
# Examples: 
# ruby env/start.rb vendetta CM cm2:start
# ruby env/start.rb vendetta CM cm2:start ./graphs/graph.txt
# ruby env/start.rb vendetta CM cm2:start ./graphs/graph.txt 4
#
# 

require './env/venteda'
require 'optparse'

ascii = <<END
              .+`       
  .oo:/ooooo++m.        
  `oNM//.  `+Mmh/       Venteda - A distribution platform for small clusters.
 -d+`hy    `do +mh`     Alexander Rüedlinger, Michael Jungo
`m/  `m:   ys  ..Nd`
-M-   :d  /d`    hM:
 dd.   h/.m:    `mm`
 `smo. /myh    :md- 
   +sds+MMs-:odNo`  
   - `ssNMmhhoo-`   
      ` yo` - .     
        `.    `     
END


puts ascii
$ARGV = ARGV
if $ARGV.size==1
    exit
end

if $ARGV[3].nil?
    $ARGV[3] = ""
end

if $ARGV[4].nil?
    $ARGV[4] = 1
end

conf = {
    :package => $ARGV[1],
    :app => $ARGV[1],
    :function => $ARGV[2] + "(\"#{$ARGV[3]}\")",
    :max_hosts => $ARGV[4].to_i
}
puts "run config:"
puts conf

Venteda::run(conf)


