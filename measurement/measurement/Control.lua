
require ("spawn_pipe")
require ("parsers/ex_process")
require ('parsers/dig')

ControlNode = { ap_refs = nil     -- list of access point nodes
              , sta_refs = nil    -- list of station nodes
              , stats = nil   -- maps node name to statistics
              , pids = nil    -- maps node name to process id of lua node
              , logger_proc = nil
              }


function ControlNode:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function ControlNode:create ()
    local o = ControlNode:new({ ap_refs = {}
                              , sta_refs = {}
                              , stats = {}
                              , pids = {}
                              })
    return o
end


function ControlNode:__tostring()
    local out = "ControlNode"
    for i, ap_ref in ipairs ( self.ap_refs ) do
        out = out .. '\n'
        out = out .. ap_ref:__tostring()
    end
    for i, sta_ref in ipairs ( self.sta_refs ) do
        out = out .. '\n'
        out = out .. sta_ref:__tostring()
    end
    return out
end

function ControlNode:add_ap_ref ( ap_ref )
    self.ap_refs [ #self.ap_refs + 1 ] = ap_ref
end

function ControlNode:add_sta_ref ( sta_ref )
    self.sta_refs [ #self.sta_refs + 1 ] = sta_ref
end

function ControlNode:nodes() 
    if ( self.node_refs == nil ) then
        self.node_refs = {}
        for _,v in ipairs(self.sta_refs) do self.node_refs [ #self.node_refs + 1 ] = v end
        for _,v in ipairs(self.ap_refs) do self.node_refs [ #self.node_refs + 1 ] = v end
    end
    return self.node_refs
end

function ControlNode:find_node( name ) 
    for _, node in ipairs ( self:nodes() ) do 
        if node.name == name then return node end 
    end
    return nil
end

function ControlNode:reachable ()
    function reachable ( ip ) 
        local ping = spawn_pipe("ping", "-c1", ip)
        local exitcode = ping['proc']:wait()
        close_proc_pipes ( ping )
        return exitcode == 0
    end

    function lookup ( name ) 
        local dig = spawn_pipe ( "dig", name )
        local exitcode = dig['proc']:wait()
        local content = dig['out']:read("*a")
        local answer = parse_dig ( content )
        close_proc_pipes ( dig )
        return answer.addr
    end

    local reached = {}
    for _, node in ipairs ( self:nodes() ) do
        local addr = lookup ( node.name )
        node.ctrl.addr = addr
        if reachable ( addr ) then
            reached[node.name] = true
        else
            reached[node.name] = false
        end
    end
    return reached
end

function ControlNode:start( log_addr, log_port, log_file )

    function start_logger ( addr, port, file )
        local logger = spawn_pipe ( "lua", "bin/Logger.lua", file, "--port", port )
        if ( logger ['err_msg'] ~= nil ) then
            print("Logger not started" .. logger ['err_msg'] )
        end
        close_proc_pipes ( logger )
        local str = logger['proc']:__tostring()
        print ( str )
        return parse_process ( str ) 
    end

    function start_node ( node, log_addr )
        local remote_cmd = "lua runNode.lua"
                    .. " --name " .. node.name 
                    .. " --log_ip " .. log_addr 
        print ( remote_cmd )
        local ssh = spawn_pipe("ssh", "root@" .. node.ctrl.addr, remote_cmd)
        close_proc_pipes ( ssh )
--[[    local exit_code = ssh['proc']:wait()
        if (exit_code == 0) then
            print (node.name .. ": node started" )
        else
            print (node.name .. ": node not started, exit code: " .. exit_code)
            print ( ssh['err']:read("*all") )
            os.exit(1)
        end --]]
    end

    self.pids['logger'] = start_logger ( log_addr, log_port, log_file ) ['pid']
    if ( self.pids['logger'] == nil ) then
        print ("Logger not started.")
        return false
    end

    for _, node in ipairs ( self:nodes() ) do
        start_node( node, log_addr )
    end
    return true
end

function ControlNode:connect( ctrl_port )
    if rpc.mode ~= "tcpip" then
        print ( "Err: rpc mode tcp/ip is supported only" )
        return false
    end

    for _, node_ref in ipairs ( self:nodes() ) do
        node_ref:connect ( ctrl_port )
        if ( node_ref.rpc == nil ) then
            print ("Connection to " .. node_ref.name .. " failed")
            return false
        end
    end

    -- query lua pid before closing rpc connection
    -- maybe to kill nodes later
    for _, node_ref in ipairs ( self:nodes() ) do 
        self.pids[ node_ref.name ] = node_ref.rpc.get_pid()
    end

    return true
end

function ControlNode:disconnect()
    for _, node_ref in ipairs ( self:nodes() ) do 
        rpc.close ( node_ref.rpc )
    end
end

function ControlNode:run_experiment ( exp, ap_ref, sta_refs )

    local ap_stats
    local stas_stats

    status, ap_stats, stas_stats = pcall ( function () return exp ( ap_ref, sta_refs ) end )
    if ( status == false ) then return false end

    self.stats [ ap_ref.name ] = ap_stats
    for i, sta_ref in ipairs ( sta_refs ) do
        self.stats [ sta_ref.name ] = stas_stats [i]
    end
    return true

end

function ControlNode:stop()

    function stop_logger ( pid )
        kill = spawn_pipe("kill", pid)
        close_proc_pipes ( kill )
    end

    for i, node_ref in ipairs ( self:nodes() ) do
        local ssh = spawn_pipe("ssh", "root@" .. node_ref.ctrl.addr, "kill " .. self.pids [ node_ref.name ] )
        local exit_code = ssh['proc']:wait()
        close_proc_pipes ( ssh )
    end
    stop_logger ( self.pids['logger'] )
end
