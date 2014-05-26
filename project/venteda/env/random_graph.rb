require 'pp'
module RandomGraph

    def generate(n)
        r = Random.new
        v_labels = (0..n).to_a.map {|x| 'v' + x.to_s }
        edges = Hash.new
        v_labels.each_with_index do |o_label,i|
            v_labels.each_with_index do |i_label,j|
                if i!=j
                    w = r.rand(1...n)
                    if i < j
                        edges[[i,j]] = [i_label,w]
                        edges[[j,i]] = [o_label,w]
                    end
                    if i > j
                         edges[[j,i]] = [i_label,w]
                         edges[[i,j]] = [o_label,w]
                    end
                end
            end
        end
        
        e = Array.new
        v_labels.each do |v|
            e << Array.new
        end
        
        round = 1
        edges.each do |key,value|
            i,j = key
            r = Random.new
            p = (r.rand)
            
            if p > 0.5
                v,w = value
                n = v[1..-1].to_i
                if n!=i
                    e[i] << value
                else
                    e[j] << value
                end
            end
            round += 1
        end
        e.each_with_index.map do |edge_list,i|
            ["v" +i.to_s, edge_list]
        end
    end

end
include RandomGraph
s = RandomGraph::generate(25)

File.open("g.txt","w+") do |f|
    s.each do |u|
        f.write(u.to_s.gsub("\"","'") + ".\n")
    end
end


