#! /usr/bin/ruby -w

#
# Rules for implementing the disktra function:
# No loops are allowed such as while, for and each
# Only functional functions are allowed such as select, reduce, 
# inject or map.
#
# Reason: we want implement the same solution using erlang.
#

require 'json'
require 'pp'

class Graph

    attr_accessor :nodes, :edges
    
    def initialize(nodes,edges)
        @nodes, @edges = nodes, edges
    end

    def dijkstra(source)
        dist,previous,neighbors = Hash.new,Hash.new,Hash.new
        
        # for each node
        @nodes.map do |v|
            dist[v] = Float::INFINITY
            previous[v] = nil
            neighbors[v] = Array.new
        end
        
        # for each edge
        @edges.map do |e|
            v1,v2,w = e
            neighbors[v1] << [v2,w]
            neighbors[v2] << [v1,w]
        end
        
        dist[source] = 0
        dijkstra_loop(:previous => previous, :dist => dist, :nodes => @nodes,:neighbors => neighbors)
    end
    
    
    def dijkstra_loop(aHash)
        previous,dist,nodes,neighbors = aHash[:previous],aHash[:dist],aHash[:nodes],aHash[:neighbors]
        
        # select a vertex u with min distance value
        u = nodes.reduce {|w,v| w = if dist[v] < dist[w] then v else w end }
        
        # remove u from nodes list
        nodes = nodes.select {|v| v!=u }
        
        return if dist[u] == Float::INFINITY
        
        # for each neighbor of u
        neighbors[u].map do |node|
            v,w = node
            if nodes.include?(v)
                alt = dist[u] + w
                if alt < dist[v]
                    dist[v] = alt
                    previous[v] = u
                end
            end
        end
        if not nodes.empty?
            dijkstra_loop(:previous => previous, :dist => dist, :nodes => nodes,:neighbors => neighbors)
        end
        aHash
    end
    
    def shortest_path(target)
        aHash = dijkstra("v1")
        previous = aHash[:previous]
        path = Array.new
        path << target
        shortest_path_loop(target,previous,path)
    end
    
    def shortest_path_loop(u,previous,path)
        return path if previous[u].nil?
        path << previous[u]
        u = previous[u]
        shortest_path_loop(u,previous,path)
    end
    
    
end

File.open('graph.txt','r') do |file|
    contents = file.read
    ahash = JSON.parse(contents)
    graph = Graph.new(ahash["V"],ahash["E"])
    pp graph.shortest_path("v5")
end
