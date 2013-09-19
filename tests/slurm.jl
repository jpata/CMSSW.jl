immutable SLURMManager <: ClusterManager
    launch::Function
    manage::Function

    SLURMManager() = new(launch_slurm_workers, manage_slurm_worker)
end

function launch_slurm_workers(SLURMManager, np::Integer, config::Dict)
    exehome = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    home = ENV["HOME"]
    jobname = "julia-$(getpid())"
    
    ofname = string(jobname, ".out")
    qsub_cmd = `salloc -J $jobname -n $np -p prio,main srun -n $np -D $home -J $jobname -o $home/$jobname-%j-%t.out $exehome/$exename -e 'import Base.start_worker;println("hostname:",gethostname());start_worker()'` .> string(jobname, ".out") 
    println("Allocating job: ", qsub_cmd)
    out, qsub_proc = readsfrom(qsub_cmd)
    @assert isfile(ofname)
    
    id = nothing
    while true
        @assert !process_exited(qsub_proc) || qsub_proc.exitcode == 0
        out = open(readall, ofname)
        m = match(r"salloc: Granted job allocation ([0-9]*)\n", out)
        m == nothing && (sleep(1);continue) 
        id = int(m.captures[1])
        break
    end 

    filename(i) = "$home/$jobname-$id-$i.out"
    
    io_objs = cell(np)
    hosts = cell(np)
    ports = cell(np)
    configs = cell(np)
    
    for i=1:np
        # wait for each output stream file to get created
        fname = filename(i-1)
        #println("Waiting for file $fname")

        result = timedwait(() -> (isfile(fname) && contains(open(readall, fname), "julia_worker")), 120.0)
        if result != :ok
            error("failed to open worker output: $i, $fname")
        end
        @assert !process_exited(qsub_proc)

        li = open(readall, fname)
        m = match(r".*hostname:([^\s]*)\n.*", li)
        m == nothing && error("Could not understand input: '$li'")
        host = m.captures[1]
        hosts[i] = host

        m = match(r".*julia_worker:([0-9]*)#.*", li)
        m == nothing && error("Could not understand input: '$li'")
        port = int(m.captures[1])
        ports[i] = port
        
        # Hack to get Base to get the host:port, the Julia process has already started.
        cmd = `tail -f $fname`
        cmd.detach = true
        io_objs[i],io_proc = readsfrom(cmd)
        io_objs[i].line_buffered = true
        #println("Job $i id=$id, host=$host:$port")

        configs[i] = merge(config, {:job => id, :task => i, :iofile => fname, :process => io_proc, :parent_process => qsub_proc})
    end
    return (:host_port, collect(zip(hosts, ports, configs)))
end

function manage_slurm_worker(id::Integer, config::Dict, op::Symbol)
    if op == :finalize
        try
            run(`scancel $(conf[:job])`)
        catch
        end

        kill(config[:parent_process], 9)
        kill(config[:process], 9)
        if isfile(config[:iofile])
            #print(open(readall, config[:iofile]))
            rm(config[:iofile])
        end
    end
end

#for i=1:10
#    addprocs(10, cman=SLURMManager())
#end

#procs = Any[]
#println("Processes created: ", nprocs())
#for i=1:nprocs()
#    println("Getting hostname from $i")
#    try
#        push!(procs, @fetchfrom i (i, gethostname(), getpid()))
#        sleep(1.0)
#    catch e
#        push!(procs, (i, e))
#    end
#end
#@everywhere print(1+2)
#print(procs)
