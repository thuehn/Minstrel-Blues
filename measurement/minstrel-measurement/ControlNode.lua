
require ('NetIF')
require ('spawn_pipe')
require ('parsers/ex_process')
require ('parsers/dig')
require ('parsers/ifconfig')
require ('AccessPointRef')
require ('StationRef')
local unistd = require ('posix.unistd')
require ('net')
require ('tcpExperiment')
require ('udpExperiment')
require ('mcastExperiment')
require ('Uci')
require ('misc')

ControlNode = { name = nil
              , ctrl_net = nil
              , port = nil
              , ap_refs = nil     -- list of access point nodes
              , sta_refs = nil    -- list of station nodes
              , node_refs = nil   -- list of all nodes
              , stats = nil   -- maps node name to statistics
              , pids = nil    -- maps node name to process id of lua node
              , logger_proc = nil
              , log_net = nil
              , log_port = nil
              }


function ControlNode:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ControlNode:create ( name, ctrl_net, port, log_net, log_port, log_file )
    local o = ControlNode:new ( { name = name
                                , ctrl_net = ctrl_net
                                , ap_refs = {}
                                , sta_refs = {}
                                , node_refs = {}
                                , stats = {}
                                , pids = {}
                                , port = port
                                , log_net = log_net
                                , log_port = log_port
                                } )

    function start_logger ( log_net, port, file )
        local logger = spawn_pipe ( "lua", "bin/runLogger.lua", file, "--port", port, "--log_if", log_net.iface )
        if ( logger ['err_msg'] ~= nil ) then
            print ( "Logger not started" .. logger ['err_msg'] )
        end
        close_proc_pipes ( logger )
        local str = logger['proc']:__tostring()
        os.sleep ( 3 )
        o:send_info ( "Logging started: " .. str )
        return parse_process ( str ) 
    end

--    function start_logger_remote ( addr, port, file )
--        local remote_cmd = "lua bin/runLogger.lua " .. file
--                    .. " --port " .. port 
-- 
--        if ( addr ~= nil ) then
--            remote_cmd = remote_cmd .. " --log_ip " .. addr 
--        end
--        o:send_info ( remote_cmd )
--        local ssh = spawn_pipe("ssh", "root@" .. addr, remote_cmd)
--        close_proc_pipes ( ssh )
--    end

    if ( log_net ~= nil and log_port ~= nil and log_file ~= nil ) then
        local pid = start_logger ( log_net, log_port, log_file ) ['pid']
        o.pids = {}
        o.pids['logger'] = pid
        if ( o.pids['logger'] == nil ) then
            print ("Logger not started.")
        end
    end

    return o
end


function ControlNode:__tostring()
    local net = "node"
    if ( self.ctrl_net ~= nil ) then
        net = self.ctrl_net:__tostring()
    end
    local log = "node"
    if ( self.log_net ~= nil ) then
        log = self.log_net:__tostring()
    end
    local out = "control if: " .. net .. "\n"
    out = out .. "control port: " .. ( self.port or "none" ) .. "\n"
    out = out .. "log: " .. log .."\n"
    out = out .. "log port: " .. ( self.log_port or "none" ) .. "\n"
    for i, ap_ref in ipairs ( self.ap_refs ) do
        out = out .. '\n'
        out = out .. ap_ref:__tostring()
    end
    out = out .. '\n'
    for i, sta_ref in ipairs ( self.sta_refs ) do
        out = out .. '\n'
        out = out .. sta_ref:__tostring()
    end
    return out
end

function ControlNode:run( port )
    self.port = port
    if rpc.mode == "tcpip" then
        self:send_info ( "Service Control started" )
        self:set_cut ()
        rpc.server ( port )
    else
        self:send_error ( "Err: tcp/ip supported only" )
    end
end


function ControlNode:get_ctrl_addr ()
    return get_addr ( self.ctrl_net.iface )
end

function ControlNode:add_ap ( name, ctrl_if, ctrl_port, rsa_key )
    self:send_info ( " add access point " .. name )
    local ctrl = NetIF:create ( ctrl_if )
    local ref = AccessPointRef:create ( name, ctrl, ctrl_port, rsa_key )
    self.ap_refs [ #self.ap_refs + 1 ] = ref 
    self.node_refs [ #self.node_refs + 1 ] = ref
end

function ControlNode:add_sta ( name, ctrl_if, ctrl_port, rsa_key )
    self:send_info ( " add station " .. name )
    local ctrl = NetIF:create ( ctrl_if )
    local ref = StationRef:create ( name, ctrl, ctrl_port, rsa_key )
    self.sta_refs [ #self.sta_refs + 1 ] = ref 
    self.node_refs [ #self.node_refs + 1 ] = ref
end

function ControlNode:list_aps ()
    local names = {}
    for _,v in ipairs ( self.ap_refs ) do names [ #names + 1 ] = v.name end
    return names
end

function ControlNode:list_stas ()
    local names = {}
    for _,v in ipairs ( self.sta_refs ) do names [ #names + 1 ] = v.name end
    return names
end

function ControlNode:list_nodes ()
    self:send_info ( " query nodes" )
    local names = {}
    for _,v in ipairs ( self.node_refs ) do names [ #names + 1 ] = v.name end
    return names
end

function ControlNode:list_phys ( name )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref == nil ) then return {} end
    return node_ref.rpc.phy_devices ()
end

function ControlNode:set_phy ( name, wifi )
    local node_ref = self:find_node_ref ( name )
    node_ref.wifi_cur = wifi
end

function ControlNode:get_phy ( name )
    local node_ref = self:find_node_ref ( name )
    return node_ref.wifi_cur
end

function ControlNode:link_to_ssid ( name, ssid )
    self:send_info ( "link to ssid " .. (name or "none" ) )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref ~= nil ) then
        self:send_info ( "link to ssid " .. (node_ref.name or "none" ) )
    end
    node_ref:link_to_ssid ( ssid, node_ref.wifi_cur )
end

function ControlNode:set_ssid ( name, ssid )
    local node_ref = self:find_node_ref ( name )
    node_ref:set_ssid ( ssid  )
end

function ControlNode:get_ssid ( name )
    self:send_info ( "get ssid " .. (name or "none" ) )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref ~= nil ) then
        self:send_info ( "get ssid node_ref " .. (node_ref.name or "none" ) )
    end
    return node_ref.rpc.get_ssid ( node_ref.wifi_cur )
end

function ControlNode:add_station ( ap, sta )
    local ap_ref = self:find_node_ref ( ap )
    local sta_ref = self:find_node_ref ( sta )
    if ( ap_ref == nil or sta_ref == nil ) then return nil end
    local mac = sta_ref.rpc.get_mac ( sta_ref.wifi_cur )
    ap_ref:add_station ( mac, sta_ref )
end

function ControlNode:list_stations ( ap )
    local ap_ref = self:find_node_ref ( ap )
    return ap_ref.stations
end

function ControlNode:set_ani ( name, ani )
    local node_ref = self:find_node_ref ( name )
    node_ref.rpc.set_ani ( node_ref.wifi_cur, ani )
end

function ControlNode:find_node_ref( name ) 
    for _, node in ipairs ( self.node_refs ) do 
        if node.name == name then return node end 
    end
    return nil
end

function ControlNode:set_nameservers ( nameserver )
    for _, node_ref in ipairs ( self.node_refs ) do
        node_ref:set_nameserver ( nameserver )
    end
end

function ControlNode:set_nameserver (  nameserver )
    set_resolvconf ( nameserver )
end

function ControlNode:get_stats()
    return self.stats
end

function ControlNode:reachable ()
    function node_reachable ( ip )
        local ping = spawn_pipe("ping", "-c1", ip)
        local exitcode = ping['proc']:wait()
        close_proc_pipes ( ping )
        return exitcode == 0
    end

    local reached = {}
    for _, node in ipairs ( self.node_refs ) do
        local addr = lookup ( node.name )
        if ( addr == nil ) then
            break
        end
        node.ctrl.addr = addr
        if node_reachable ( addr ) then
            reached [ node.name ] = true
        else
            reached [ node.name ] = false
        end
    end
    return reached
end

function ControlNode:start( log_addr, log_port )

    function start_node ( node_ref, log_addr )

        local remote_cmd = "lua runNode.lua"
                    .. " --name " .. node_ref.name 
                    .. " --ctrl_if " .. node_ref.ctrl.iface

        if ( log_addr ~= nil ) then
            remote_cmd = remote_cmd .. " --log_ip " .. log_addr 
        end
        self:send_info ( remote_cmd )
        local ssh = spawn_pipe("ssh", "-i", node_ref.rsa_key, "root@" .. node_ref.ctrl.addr, remote_cmd)
        close_proc_pipes ( ssh )
--[[    local exit_code = ssh['proc']:wait()
        if (exit_code == 0) then
            self:send_info (node.name .. ": node started" )
        else
            self:send_info (node.name .. ": node not started, exit code: " .. exit_code)
            self:send_info ( ssh['err']:read("*all") )
            os.exit(1)
        end --]]
    end

    for _, node_ref in ipairs ( self.node_refs ) do
        start_node( node_ref, log_addr )
    end
    return true
end

function ControlNode:connect_nodes ( ctrl_port )
    
    if rpc.mode ~= "tcpip" then
        self:send_info ( "Err: rpc mode tcp/ip is supported only" )
        return false
    end

    for _, node_ref in ipairs ( self.node_refs ) do
        function connect_rpc ()
            local l, e = rpc.connect ( node_ref.ctrl.addr, ctrl_port )
            return l, e
        end
        local status
        local rpc
        local err
        local status, rpc = pcall ( connect_rpc )
        if ( status == false or rpc == nil ) then
            self:send_error ("Connection to " .. node_ref.name .. " failed: ")
            self:send_error ( "Err: no node at address: " .. node_ref.ctrl.addr .. " on port: " .. ctrl_port )
            return false
        else 
            self:send_info ("Connected to " .. node_ref.name)
            node_ref:init( rpc )
        end
    end

    -- query lua pid before closing rpc connection
    -- maybe to kill nodes later
    for _, node_ref in ipairs ( self.node_refs ) do 
        self.pids[ node_ref.name ] = node_ref.rpc.get_pid()
    end

    return true
end

function ControlNode:disconnect_nodes()
    for _, node_ref in ipairs ( self.node_refs ) do 
        rpc.close ( node_ref.rpc )
    end
end

-- runs experiment 'exp' for all nodes 'ap_refs'
-- in parallel
-- see run_experiment in Experiment.lua for
-- a sequential variant
-- fixme: exp userdata over rpc not possible
function ControlNode:run_experiments ( command, args, ap_names )

    local exp
    if ( command == "tcp") then
        exp = TcpExperiment:create ( args )
    elseif ( command == "mcast") then
        exp = McastExperiment:create ( args )
    elseif ( command == "udp") then
        exp = UdpExperiment:create ( args )
    else
        return false
    end

    local ret = true
    local ap_refs = {}
    for _, name in ipairs ( ap_names ) do
        local ap_ref = self:find_node_ref ( name )
        ap_refs [ #ap_refs + 1 ] = ap_ref
    end

    for _, ap_ref in ipairs ( ap_refs ) do
        exp:prepare_measurement ( ap_ref )
    end

    local keys = {}
    for i, ap_ref in ipairs ( ap_refs ) do
        keys[i] = exp:keys ( ap_ref )
    end

    self:send_info ( "Start experiment." )
    local stop = false
    for _, key in ipairs ( keys[1] ) do -- fixme: smallest set of keys

        for _, ap_ref in ipairs ( ap_refs ) do
            if ( exp:settle_measurement ( ap_ref, key, 5 ) == false ) then
                self:send_error ( "experiment aborted, settledment failed. please check the wifi connnections." )
                return ret
            end
        end

        -- -------------------------------------------------------
        for _, ap_ref in ipairs ( ap_refs ) do
            exp:start_measurement (ap_ref, key )
        end

        -- -------------------------------------------------------
        -- Experiment
        -- -------------------------------------------------------
            
        for _, ap_ref in ipairs ( ap_refs ) do
            exp:start_experiment ( ap_ref, key )
        end
    
        for _, ap_ref in ipairs ( ap_refs ) do
            exp:wait_experiment ( ap_ref, 5 )
        end

        -- -------------------------------------------------------

        for _, ap_ref in ipairs ( ap_refs ) do
            exp:stop_measurement (ap_ref, key )
        end

        for _, ap_ref in ipairs ( ap_refs ) do
            exp:unsettle_measurement ( ap_ref, key )
        end

    end

    self:send_info ( "Copy stats from nodes." )
    for _, ap_ref in ipairs ( ap_refs ) do

        self.stats [ ap_ref.name ] = {} 
        self.stats [ ap_ref.name ] [ 'regmon_stats' ] = copy_map ( ap_ref.stats.regmon_stats )
        self.stats [ ap_ref.name ] [ 'tcpdump_pcaps' ] = copy_map ( ap_ref.stats.tcpdump_pcaps )
        self.stats [ ap_ref.name ] [ 'cpusage_stats' ] = copy_map ( ap_ref.stats.cpusage_stats )
        self.stats [ ap_ref.name ] [ 'rc_stats' ] = copy_map ( ap_ref.stats.rc_stats )

        for _, sta_ref in ipairs ( ap_ref.refs ) do
            self.stats [ sta_ref.name ] = {} 
            self.stats [ sta_ref.name ] [ 'regmon_stats' ] = copy_map ( sta_ref.stats.regmon_stats )
            self.stats [ sta_ref.name ] [ 'tcpdump_pcaps' ] = copy_map ( sta_ref.stats.tcpdump_pcaps )
            self.stats [ sta_ref.name ] [ 'cpusage_stats' ] = copy_map ( sta_ref.stats.cpusage_stats )
            self.stats [ sta_ref.name ] [ 'rc_stats' ] = copy_map ( sta_ref.stats.rc_stats )
        end
    end

    return ret

end

-- runs experiment 'exp' for node 'ap_ref'
-- sequentially
-- see run_experiment in Experiment.lua
function ControlNode:run_experiment ( exp, ap_name )

    local ap_ref = find_node_ref ( ap_name )

    local status
    local err
    status, err = pcall ( function () return exp ( ap_ref ) end )

    if ( status == false ) then 
        self:send_info ( "Error: experiment failed:\n" .. err )
        return false 
    end
    
    self.stats [ ap_ref.name ] = {}
    self.stats [ ap_ref.name ] [ 'regmon_stats' ] = copy_map ( ap_ref.stats.regmon_stats )
    self.stats [ ap_ref.name ] [ 'tcpdump_pcaps' ] = copy_map ( ap_ref.stats.tcpdump_pcaps )
    self.stats [ ap_ref.name ] [ 'cpusage_stats' ] = copy_map ( ap_ref.stats.cpusage_stats )
    self.stats [ ap_ref.name ] [ 'rc_stats' ] = copy_map ( ap_ref.stats.rc_stats )
    for _, sta_ref in ipairs ( ap_ref.refs ) do
        self.stats [ sta_ref.name ] = {} 
        self.stats [ sta_ref.name ] [ 'regmon_stats' ] = copy_map ( sta_ref.stats.regmon_stats )
        self.stats [ sta_ref.name ] [ 'tcpdump_pcaps' ] = copy_map ( sta_ref.stats.tcpdump_pcaps )
        self.stats [ sta_ref.name ] [ 'cpusage_stats' ] = copy_map ( sta_ref.stats.cpusage_stats )
        self.stats [ sta_ref.name ] [ 'rc_stats' ] = copy_map ( sta_ref.stats.rc_stats )
    end
    return true

end

function ControlNode:stop()

    function stop_logger ( pid )
        if ( pid == nil ) then
            self:send_error ( "logger not stopped: pid is not set" )
        else
            self:send_info ( "stop logger with pid " .. pid )
            kill = spawn_pipe( "kill", pid )
            close_proc_pipes ( kill )
        end
    end

    for i, node_ref in ipairs ( self.node_refs ) do
        self:send_info ( "stop node at " .. node_ref.ctrl.addr .. " with pid " .. self.pids [ node_ref.name ] )
        local ssh = spawn_pipe("ssh", "-i", node_ref.rsa_key, "root@" .. node_ref.ctrl.addr, "kill " .. self.pids [ node_ref.name ] )
        local exit_code = ssh['proc']:wait()
        close_proc_pipes ( ssh )
    end
    stop_logger ( self.pids['logger'] )
end

-- -------------------------
-- posix
-- -------------------------

function ControlNode:get_pid()
    local lua_pid = unistd.getpid()
    return lua_pid
end

-- kill child process of lua by pid
-- if process with pid is not a child of lua
-- then return nil
-- otherwise the exit code of kill is returned
function kill ( pid, signal )
    local lua_pid = unistd.getpid()
    if (parent_pid ( pid ) == lua_pid) then
        local kill
        if (signal ~= nil) then
            kill = spawn_pipe("kill","-"..signal,pid)
        else
            kill = spawn_pipe("kill", pid)
        end
        local exit_code = kill['proc']:wait()
        close_proc_pipes ( kill )
        return exit_code
    else 
        self:send_warning("try to kill pid " .. pid)
        return nil
    end
    -- TODO: creates zombies
end


-- -------------------------
-- Logging
-- -------------------------

function ControlNode:connect_logger ()
    function connect ()
        local l, e = rpc.connect ( "127.0.0.1", self.log_port)
        return l, e
    end
    local status, logger, err = pcall ( connect )
    -- TODO: print this message a single time only
    if (status == false) then
        print ( "Err: Connection to Logger failed" )
        print ( "Err: no logger at address: " .. "127.0.0.1" .. " on port: " .. self.log_port)
        return nil
    else
        return logger
    end
end

function ControlNode:get_logger_addr ()
    local logger = self:connect_logger()
    if ( logger == nil ) then return nil end
    local addr = logger.get_addr() 
    self:disconnect_logger ( logger )
    return addr
end

function ControlNode:disconnect_logger ( logger )
    if (logger ~= nil) then
        rpc.close (logger)
    end
end

function ControlNode:set_cut ()
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.set_cut ()    
    end
    self:disconnect_logger ( logger )
end

function ControlNode:send_error( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_error( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function ControlNode:send_info( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_info( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function ControlNode:send_warning( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_warning( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end
