# Venteda library
#
# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014
#
# This library can used as a simple distribution platform
# to distribute and to deploy erlang applications in small cluster. 
#
# 
require 'pathname'

module Venteda
    
    #
    # Some paths
    #
    @@vendetta_env_dir = File.expand_path(File.dirname(__FILE__))
    @@vendetta_dir = File.expand_path "."
    @@tmp_dir = @@vendetta_dir + "/tmp"
    @@lib_dir = @@vendetta_dir + "/lib"
    @@app_dir = @@vendetta_dir + "/apps"
    @@default_hosts = @@vendetta_dir + "/conf/hosts.txt"
    @@cookie = "abc"

    #
    # Reads a host file and returns a list of hosts.
    #
    def read_hosts(file)
        hosts = Array.new
        File.open(file,'r') do |f|
            f.each_line do |line|
                if line[0] != "#" and line!=""
                    parts = line.split()
                    if parts.size==4
                        hosts << {:host => parts[0], :ps => parts[1].to_i, :user => parts[3]}
                    end
                end
            end
        end
        hosts
    end
    
    #
    # Uploads a file to a host.
    # a_hash = {:host => host, :file => 'path_to_file' }
    # host = {:user => 'user', :host => 'ip or hostname' }
    #
    def upload_file(a_hash)
        file = a_hash[:file]
        host = a_hash[:host]
        `scp  #{file} #{host[:user]}@#{host[:host]}:/home/#{host[:user]}`
    end
    
    #
    # Distributes a file in a cluster.
    # a_hash = {:hosts => hosts, :file => 'path_to_file' }
    #
    def distribute(a_hash)
        hosts = a_hash[:hosts]
        file = a_hash[:file]
        hosts.each do |host|
            upload_file(:file => file, :host => host)
        end
    end
    
    #
    # Packages an app :app with package name :package.
    # a_hash = {:app => app name, :package => package name}
    #
    def package(a_hash)
        # get app and package name
        app, package = a_hash[:app], a_hash[:package]
       
        # create help variables
        tmp_path = "#{@@tmp_dir}/#{package}"
        lib_path = @@lib_dir + "/*"
        app_path = "#{@@app_dir}/#{app}"
        
        `rm -rf #{tmp_path}` # clean tmp/{package} if present
        `mkdir -p #{tmp_path}/apps` # make dir tmp/{package}
        `cp -LR #{app_path} #{tmp_path}/apps/#{app}` # copy all files from the app {app}
        `cp -R #{lib_path} #{tmp_path}/apps/#{app}` # copy all libaries form lib to {app}
        
        archive_file = compress(package) # create tar.gz file
        `rm -rf #{tmp_path}` # remove tmp/{package}
        archive_file # return absolute archive file path
    end
    
    #
    # Unpacks an deployed package on a host.
    # host = host = {:user => 'user', :host => 'ip or hostname' }
    # package_filename = a package file name
    #
    def unpack(a_host,package_filename)
        tar_cmd = "tar -zxf #{package_filename}"
        `ssh #{a_host[:user]}@#{a_host[:host]} '#{tar_cmd}'`
    end
    
    #
    # Deploys an app on the cluster.
    # a_hash = {:cluster => hosts, :app => app name, :package => package name}
    #
    def deploy(a_hash)
        # get app name and package name
        app, package = a_hash[:app], a_hash[:package]
        puts "deploy #{package}/#{app} on the cluster..."
    
        # package the app
        a_hash[:file] = package(a_hash)
        package_filename = Pathname.new(a_hash[:file]).basename.to_s
        distribute(a_hash)
        
        # if we have less than :max_hosts raise SystemExit excpetion
        if a_hash[:max_hosts] > a_hash[:hosts].size
            exit
        end
        
        hosts = a_hash[:hosts][0...a_hash[:max_hosts]]
        # unpack the package on each node
        puts "unpack package #{package}..."
        hosts.each do |host|
            unpack(host,package_filename)
        end
        
        hosts.each do |host|
            compile(host,package,app)
            puts "package/app: #{package}/#{app} - deployed on host: #{host[:host]}"
        end
        return hosts #return nodes where the app is deployed
    end
    
    #
    # Compile deployed app {app} in package {package} on node {a_host}.
    #
    def compile(a_host,package,app)
        compile_cmd = "cd ~/#{package}/apps/#{app} && erl -noshell -eval \'make:all(),init:stop().\'"
        `ssh #{a_host[:user]}@#{a_host[:host]} "#{compile_cmd}"`
    end
    
    #
    # Runs an app from the folder /apps/{app}
    # a_hash = { :package => package,:app => app, :function =>function, :max_hosts => n, :host_file => path to host file}
    #
    def run(a_hash)
        app = a_hash[:app]
        package = a_hash[:package]
        function = a_hash[:function]
        max_hosts = a_hash[:max_hosts]
        
        # if hosts file is not provided then use default hosts file
        if a_hash[:host_file].nil?
            hosts = read_hosts(@@default_hosts)
        else
            hosts = read_hosts(a_hash[:host_file])
        end
        
        
        begin
            deployed_hosts = deploy(:app => app, :package => package, :hosts => hosts, :max_hosts => max_hosts)
            start_master(:package => package,:app => app, :function => function,:hosts => deployed_hosts, :max_hosts => max_hosts)
        rescue SystemExit
            puts "add some nodes to your cluster! Need %s nodes!" % max_hosts
        end
    end
    
    #
    # Starts the master node which is responsible for the deployment.
    # a_hash = {:app => app, :package => package, :function => function, :hosts }
    #
    def start_master(a_hash)
        host = `uname -n`.chomp # get host name
        puts "start master node: master@#{host}"
        hosts = a_hash[:hosts]
        app = a_hash[:app]
        function = a_hash[:function]
        nodes = start_nodes(a_hash)
        
        # create enodes.txt file and save it in local app folder
        File.open("#{@@app_dir}/#{app}/enodes.txt","w+") do |f|
            f.puts("'master@#{host}'.") # add master node
            nodes.each do |node|
                f.puts("#{node}.")
            end
        end
        
        # compile local app
        `cd  #{@@app_dir}/#{app} && erl -noshell -eval 'make:all(),init:stop().'`
        # cd to local app folder and run the env/run.sh script
        system "cd #{@@app_dir}/#{app} && sh #{@@vendetta_env_dir}/run.sh #{@@cookie} '#{function}'"
        
        # shut down all nodes
        puts "Terminate nodes..."
        cmd = ""
        nodes.each do |node|
            cmd << "rpc:call(#{node},init,stop,[]),"
        end
        cmd << "init:stop()."
        puts "Kill nodes"
        puts `erl -name terminator@#{host} -setcookie #{@@cookie} -noshell -eval "#{cmd}"`
        cmd = "epmd -kill"
        
        hosts.each do |host|
            puts "host: #{host[:host]} - " + `ssh #{host[:user]}@#{host[:host]} '#{cmd}'`
        end
        puts "Kill local port mapper"
        `epmd -kill`
        return ""
    end
    
    #
    # Start all nodes on all hosts.
    # a_hash = {:hosts => hosts, :max_hosts => max_hosts, :app => app, :package => package }
    #
    def start_nodes(a_hash)
        hosts = a_hash[:hosts]
        # if we have less than :max_hosts raise SystemExit excpetion
        if a_hash[:max_hosts] > hosts.size
            exit
        end
        nodes = Array.new
        hosts.each do |host|
            host[:app] = a_hash[:app]
            host[:package] = a_hash[:package]
            nodes << start_node(host)
        end
        return nodes
    end
    
    #
    # Start node on host.
    # a_host = {:user => user, :host => host }
    #
    def start_node(a_host)
        run_cmd = 'erl -noshell -eval "io:format(\"~p~n\",[erlang:system_info(process_limit)]),init:stop()."'
        default = `ssh #{a_host[:user]}@#{a_host[:host]} '#{run_cmd}'`
        default  = default.chomp
        r = Random.new
        random_id = r.rand(8000...9000)
        node_id = "'#{random_id}@#{a_host[:host]}'"
        
        `sh #{@@vendetta_env_dir}/run_remote.sh #{a_host[:user]}@#{a_host[:host]} #{a_host[:package]}/apps/#{a_host[:app]} #{default} #{node_id} #{@@cookie}`
        return node_id
    end
    
    #
    # Compress a directory
    #
    def compress(package)
        archive_file = "#{@@tmp_dir}/#{package}.tar.gz"
        `tar -zcf #{archive_file} --directory=#{@@tmp_dir} #{package}`
        archive_file
    end
    
    #
    # Pings an host.
    # Returns true if available otherwise false.
    #
    def ping(host)
     res = `ping #{host} -c 1`
     res.include?("0% packet loss")
    end
    
    
end
include Venteda
