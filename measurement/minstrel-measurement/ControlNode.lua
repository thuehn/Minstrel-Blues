
--pprint = require ('pprint')

local ps = require ('posix.signal') --kill
local posix = require ('posix') -- sleep
local lpc = require 'lpc'
local misc = require 'misc'
local net = require ('Net')

require ('NodeBase')

require ('NetIF')
require ('misc')
require ('Uci')

require ('parsers/ex_process')

require ('AccessPointRef')
require ('StationRef')

require ('tcpExperiment')
require ('udpExperiment')
require ('mcastExperiment')
require ('EmptyExperiment')

ControlNode = NodeBase:new()

function ControlNode:create ( name, ctrl, port, log_port, log_file, output_dir )
    local o = ControlNode:new ( { name = name
                                , ctrl = ctrl
                                , port = port
                                , log_port = log_port
                                , log_file = log_file
                                , output_dir = output_dir
                                , log_addr = ctrl.addr
                                , ap_refs = {}     -- list of access point nodes
                                , sta_refs = {}    -- list of station nodes
                                , node_refs = {}   -- list of all nodes
                                , pids = {}    -- maps node name to process id of lua node
                                , exp = nil
                                , stats = {}
                                , keys = {}
                                } )

    if ( o.ctrl.addr == nil ) then
        o.ctrl:get_addr ()
        o.log_addr = o.ctrl.addr
    end

    if ( log_port ~= nil and log_file ~= nil ) then
        local pid, _, _ = misc.spawn ( "lua", "/usr/bin/runLogger", "/tmp/" .. log_file 
                                    , "--port", log_port )
        o.pids = {}
        o.pids ['logger'] = pid
    end

    return o
end


function ControlNode:__tostring()
    local net = "none"
    if ( self.ctrl ~= nil ) then
        net = self.ctrl:__tostring()
    end
    local out = "control if: " .. net .. "\n"
    out = out .. "control port: " .. ( self.port or "none" ) .. "\n"
    out = out .. "output: " .. ( self.output_dir or "none" ) .. "\n"
    out = out .. "log file: " .. ( self.log_file or "none" ) .."\n"
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

function ControlNode:restart_wifi_debug()
    if ( table_size ( self.ap_refs ) == 0 ) then
        self:send_warning ( "Cannot start wifi on APs. Not initialized" )
        print ( "Cannot start wifi on APs. Not initialized" )
    end
    for _, ap_ref in ipairs ( self.ap_refs ) do
        ap_ref.rpc.restart_wifi()
    end
end

function ControlNode:add_ap ( name, ctrl_if, rsa_key )
    self:send_info ( " add access point " .. name )
    local ctrl = NetIF:create ( ctrl_if )
    local ref = AccessPointRef:create ( name, ctrl, rsa_key, self.output_dir )
    self.ap_refs [ #self.ap_refs + 1 ] = ref 
    self.node_refs [ #self.node_refs + 1 ] = ref
end

function ControlNode:add_sta ( name, ctrl_if, rsa_key )
    self:send_info ( " add station " .. name )
    local ctrl = NetIF:create ( ctrl_if )
    local ref = StationRef:create ( name, ctrl, rsa_key, self.output_dir )
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
    self:send_info ( "query nodes" )
    local names = {}
    for _,v in ipairs ( self.node_refs ) do names [ #names + 1 ] = v.name end
    return names
end

function ControlNode:get_mac ( node_name )
    local node_ref = self:find_node_ref ( node_name )
    if ( node_ref == nil ) then return nil end
    return node_ref:get_mac ()
end

function ControlNode:get_opposite_macs ( node_name )
    local node_ref = self:find_node_ref ( node_name )
    if ( node_ref == nil ) then return nil end
    return node_ref:get_opposite_macs ()
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

function ControlNode:enable_wifi ( name, enabled )
    local node_ref = self:find_node_ref ( name )
    return node_ref:enable_wifi ( enabled ) 
end

function ControlNode:link_to_ssid ( name, ssid )
    self:send_info ( "link to ssid " .. (name or "none" ) )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref ~= nil ) then
        self:send_info ( "link to ssid " .. (node_ref.name or "none" ) )
    end
    node_ref:link_to_ssid ( ssid, node_ref.wifi_cur )
end

function ControlNode:get_ssid ( name )
    self:send_info ( "get ssid " .. (name or "none" ) )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref ~= nil ) then
        self:send_info ( "get ssid from node_ref " .. ( node_ref.name or "none" ) )
        return node_ref.rpc.get_ssid ( node_ref.wifi_cur )
    else
        self:send_error ( "get ssid from node_ref " .. ( node_ref.name or "none" ) .. "failed. Not found" )
    end
    return nil
end

function ControlNode:add_station ( ap, sta )
    local ap_ref = self:find_node_ref ( ap )
    local sta_ref = self:find_node_ref ( sta )
    if ( ap_ref == nil or sta_ref == nil ) then return nil end
    local mac = sta_ref.rpc.get_mac ( sta_ref.wifi_cur )
    ap_ref:add_station ( mac, sta_ref )
    sta_ref:set_ap_ref ( ap_ref )
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

function ControlNode:check_bridges ()
    local no_bridges = true
    for _, node_ref in ipairs ( self.node_refs ) do
        local has_bridge = node_ref:check_bridge ()
        self:send_info ( node_ref.name .. " has no bridged setup" )
        no_bridges = no_bridges and not has_bridge
    end
    if ( no_bridges == false ) then
        self:send_error ( "One or more nodes have a bridged setup" )
    end
    return no_bridges
end

function ControlNode:reachable ()
    function node_reachable ( ip )
        local ping, exit_code = misc.execute ( "ping", "-c1", ip)
        return exit_code == 0
    end

    local reached = {}
    for _, node in ipairs ( self.node_refs ) do
        local addr = net.lookup ( node.name )
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

function ControlNode:start_nodes ( log_addr, log_port )

    function start_node ( node_ref, log_addr )

        local remote_cmd = "lua /usr/bin/runNode"
                    .. " --name " .. node_ref.name 
                    .. " --ctrl_if " .. node_ref.ctrl.iface

        if ( log_addr ~= nil ) then
            remote_cmd = remote_cmd .. " --log_ip " .. log_addr 
        end
        self:send_info ( "ssh " .. "-i " .. ( node_ref.rsa_key or "none" )
                        .. " root@" .. ( node_ref.ctrl.addr or "none" ) .. " " .. remote_cmd )
        local pid, _, _ = misc.spawn ( "ssh", "-i", node_ref.rsa_key, 
                                      "root@" .. ( node_ref.ctrl.addr or "none" ), remote_cmd )
        return pid
    end

    for _, node_ref in ipairs ( self.node_refs ) do
        self.pids [ node_ref.name ] = start_node ( node_ref, log_addr )
    end
    return true
end

function ControlNode:connect_nodes ( ctrl_port )
    
    for _, node_ref in ipairs ( self.node_refs ) do
        local slave = net.connect ( node_ref.ctrl.addr, ctrl_port, 10, node_ref.name, 
                                    function ( msg ) self:send_error ( msg ) end )
        if ( slave == nil ) then 
            return false
        else
            self:send_info ( "Connected to " .. node_ref.name)
            node_ref:init ( slave )
        end
    end

    -- query lua pid before closing rpc connection
    -- maybe to kill nodes later
    for _, node_ref in ipairs ( self.node_refs ) do 
        self.pids [ node_ref.name ] = node_ref.rpc.get_pid ()
    end

    return true
end

function ControlNode:disconnect_nodes()
    for _, node_ref in ipairs ( self.node_refs ) do 
        net.disconnect ( node_ref.rpc )
    end
end

-- kill all running nodes with two times sigint(2)
-- (default kill signal is sigterm(15) )
function ControlNode:stop()

    --fixme: move to log node
    function stop_logger ( pid )
        if ( pid == nil ) then
            self:send_error ( "logger not stopped: pid is not set" )
        else
            self:send_info ( "stop logger with pid " .. pid )
            ps.kill ( pid )
            lpc.wait ( pid )
        end
    end

    -- fixme: nodes should implement a stop function and kill itself with getpid
    -- and wait
    for i, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.rpc == nil ) then break end
        self:send_info ( "stop node at " .. node_ref.ctrl.addr .. " with pid " .. self.pids [ node_ref.name ] )
        local ssh
        local exit_code
        local remote = "root@" .. node_ref.ctrl.addr
        local remote_cmd = "lua /usr/bin/kill_remote " .. self.pids [ node_ref.name ] .. " --INT -i 2"
        self:send_debug ( remote_cmd )
        ssh, exit_code = misc.execute ( "ssh", "-i", node_ref.rsa_key, remote, remote_cmd )
        if ( exit_code ~= 0 ) then
            self:send_debug ( "send signal -2 to remote pid " .. self.pids [ node_ref.name ] .. " failed" )
        end
    end

    stop_logger ( self.pids ['logger'] )

    -- transfer log
    local fname = "/tmp/" .. self.log_file
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local log = file:read ("*a")
        file:close()
        return log
    else
        return nil
    end
end

function ControlNode:init_experiment ( command, args, ap_names, is_fixed )
    if ( command == "tcp") then
        self.exp = TcpExperiment:create ( self, args, is_fixed )
    elseif ( command == "mcast") then
        self.exp = McastExperiment:create ( self, args, is_fixed )
    elseif ( command == "udp") then
        self.exp = UdpExperiment:create ( self, args, is_fixed )
    elseif ( command == "noop" ) then
        self.exp = EmptyExperiment:create ( self, args, is_fixed )
    else
        return false
    end

    self:send_info ("*** Generate measurement keys ***")
    self.keys = {}
    for i, ap_ref in ipairs ( self.ap_refs ) do
        self.keys[i] = self.exp:keys ( ap_ref )
    end
    return true
end

function ControlNode:get_txpowers ()
    local powers = {}
    for i, ap_ref in ipairs ( self.ap_refs ) do
        powers [ ap_ref.name ] = ap_ref.rpc.tx_power_indices ( ap_ref.wifi_cur, ap_ref.stations[1] ) 
        for _, sta_ref in ipairs ( ap_ref.refs ) do
            powers [ sta_ref.name ] = powers [ ap_ref.name ]
        end
    end
    return powers
end

function ControlNode:get_txrates ()
    local rates = {}
    for i, ap_ref in ipairs ( self.ap_refs ) do
        rates [ ap_ref.name ] = ap_ref.rpc.tx_rate_indices ( ap_ref.wifi_cur, ap_ref.stations[1] ) 
        for _, sta_ref in ipairs ( ap_ref.refs ) do
            rates [ sta_ref.name ] = rates [ ap_ref.name ]
        end
    end
    return rates
end

function ControlNode:get_keys ()
    return self.keys
end

function ControlNode:get_stats ()
    return self.stats
end

function ControlNode:copy_stats ( ap_ref )

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

-- runs experiment 'exp' for all nodes 'ap_refs'
-- in parallel
function ControlNode:run_experiment ( command, args, ap_names, is_fixed, key, number, count )

    function find_rate ( rate_name, rate_names, rate_indices )
        rate_name = string.gsub ( rate_name, " ", "" )
        rate_name = string.gsub ( rate_name, "MBit/s", "M" )
        rate_name = string.gsub ( rate_name, "1M", "1.0M" )
        --print ( "'" .. rate_name .. "'" )
        for i, name in ipairs ( rate_names ) do
            if ( name == rate_name ) then return rate_indices [ i ] end
        end
        print ( "rate name doesn't match: '" .. rate_name .. "'" )
        return nil
    end


    local exp_header = "* Start experiment " .. number .. " of " .. count
                            .. " with key " .. ( key or "none" ) .. " *"
    local hrule = ""
    for i=1, string.len ( exp_header ) do hrule = hrule .. "*" end
    self:send_info ( hrule )
    self:send_info ( exp_header )
    self:send_info ( hrule )

    self:send_info ("*** Prepare measurement ***")
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:prepare_measurement ( ap_ref )
    end

    self:send_info ("*** Settle measurement ***")

    for _, ap_ref in ipairs ( self.ap_refs ) do
        -- self:send_debug ( ap_ref:__tostring() )
        -- for _, station in ipairs ( ap_ref.rpc.visible_stations( ap_ref.wifi_cur ) ) do
        --     self:send_debug ( "station: " .. station )
        -- end
        if ( self.exp:settle_measurement ( ap_ref, key, 10 ) == false ) then
            self:send_error ( "experiment aborted, settledment failed. please check the wifi connnections." )
            return false
        end
        -- for _, station in ipairs ( ap_ref.rpc.visible_stations( ap_ref.wifi_cur ) ) do
        --     self:send_debug ( "station: " .. station )
        -- end

        local rate_names = ap_ref.rpc.tx_rate_names ( ap_ref.wifi_cur, ap_ref.stations[1] )
        local msg = "rate names: "
        self:send_debug( msg .. table_tostring ( rate_names, 80 - string.len ( msg ) ) )

        local rates = ap_ref.rpc.tx_rate_indices ( ap_ref.wifi_cur, ap_ref.stations[1] )
        local msg = "rate indices: "
        self:send_debug( msg .. table_tostring ( rates, 80  - string.len ( msg ) ) )

        local powers = ap_ref.rpc.tx_power_indices ( ap_ref.wifi_cur, ap_ref.stations[1] )
        local msg = "power indices: "
        self:send_debug( msg .. table_tostring ( powers, 80  - string.len ( msg ) ) )

        for i, sta_ref in ipairs ( ap_ref.refs ) do

            local rate_name = sta_ref.rpc.get_linked_rate_idx ( sta_ref.wifi_cur )
            if ( rate_name ~= nil ) then
                local rate_idx = find_rate ( rate_name, rate_names, rates )
                self:send_debug ( " rate_idx: " .. ( rate_idx or "unset" ) )
            end

            local signal = sta_ref.rpc.get_linked_signal ( sta_ref.wifi_cur )
        end

    end

    self:send_info ( "Waiting one extra second for initialised debugfs" )
    posix.sleep (1)

    self:send_info ("*** Start Measurement ***" )

    -- -------------------------------------------------------
    for _, ap_ref in ipairs ( self.ap_refs ) do
         self.exp:start_measurement (ap_ref, key )
    end

    -- -------------------------------------------------------
    -- Experiment
    -- -------------------------------------------------------

    self:send_info ("*** Start Experiment ***" )
    for _, ap_ref in ipairs ( self.ap_refs ) do
         self.exp:start_experiment ( ap_ref, key )
    end
    
    self:send_info ("*** Wait Experiment ***" )
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:wait_experiment ( ap_ref, 5 )
    end

    -- -------------------------------------------------------

    self:send_info ("*** Stop Measurement ***" )
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:stop_measurement (ap_ref, key )
    end

    self:send_info ("*** Fetch Measurement ***" )
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:fetch_measurement (ap_ref, key )
    end

    self:send_info ("*** Unsettle measurement ***" )
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:unsettle_measurement ( ap_ref, key )
    end

    self:send_info ( "*** Copy stats from nodes. ***" )
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self:copy_stats ( ap_ref )
    end

    return true
end

-- -------------------------
-- Hardware
-- -------------------------

function ControlNode:get_boards ()
    local map = {}
    for _, node_ref in ipairs ( self.node_refs ) do
       local board = node_ref:get_board () 
       map [ node_ref.name ] = board
    end
    return map
end

-- -------------------------
-- date
-- -------------------------

function ControlNode:set_dates ()
    local time = os.date( "*t", os.time() )
    for _, node_ref in ipairs ( self.node_refs ) do
        local cur_time
        local err
        cur_time, err = node_ref:set_date ( time.year, time.month, time.day, time.hour, time.min, time.sec )
        if ( err == nil ) then
            self:send_info ( "Set date/time to " .. cur_time )
        else
            self:send_error ( "Set date/time failed: " .. err )
            self:send_error ( "Time is: " .. cur_time )
        end
    end
end
