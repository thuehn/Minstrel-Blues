
local posix = require ('posix') -- sleep
require ('rpc')
local lpc = require ('lpc')
local misc = require ('misc')
local pprint = require ('pprint')
local config = require ('Config') -- find_node
local net = require ('Net')
local ps = require ('posix.signal') --kill

require ('NetIfRef')
require ('Measurement')
require ('LogNodeRef')

ControlNodeRef = { name = nil           -- hostname of the control node ( String )
                 , ssh_port = nil       -- ssh port ( Number )
                 , lua_bin = nil        -- lua binary path ( String )
                 , ctrl_net_ref = nil   -- reference to control interface ( NetRef )
                 , rpc = nil            -- rpc client ( userdata )
                 , output_dir = nil     -- path to measurment result ( String )
                 , stats = nil          -- maps node name to statistics ( Measurement )
                 , distance = nil       -- approx.distance between node just for the log file ( String )
                 , net_if = nil         -- local network interface ( NetIF )
                 , log_ref = nil        -- reference to logger ( LogNodeRef )
                 , nameserver = nil     -- IP of the nameserver ( String )
                 , ctrl_port = nil      -- port of control node ( Number )
                 , aps_config = nil     -- list of AP configs
                 , sta_config = nil     -- list of STA configs
                 , connections = nil    -- list of APs and connections to STAs
                 , ctrl_pid = nil       -- PID of control node process
                 }

function ControlNodeRef:new (o)
    local o = o or {}
    setmetatable (o, self)
    self.__index = self
    return o
end

function ControlNodeRef:create ( ctrl_port, output_dir
                               , log_fname, log_port
                               , distance, net_if, nameserver
                               , ctrl_arg, ap_args, sta_args, connections
                               , ap_setups, sta_setups, command )
    local ap_names = {}
    for _, ap in ipairs ( ap_args ) do
        local parts = split ( ap, "," )
        ap_names [ #ap_names + 1 ] = parts [ 1 ]
    end

    local aps_config = Config.select_configs ( ap_setups, ap_names )
    if ( table_size ( aps_config ) == 0 ) then return nil end

    local sta_names = {}
    for _, sta in ipairs ( sta_args ) do
        local parts = split ( sta, "," )
        sta_names [ #sta_names + 1 ] = parts [ 1 ]
    end

    local stas_config = Config.select_configs ( sta_setups, sta_names )
    if ( table_size ( stas_config ) == 0 ) then return nil end

    local ctrl_config = Config.select_config ( nodes, ctrl_arg )
    if ( ctrl_config == nil ) then return nil end

    print ( "Configuration:" )
    print ( "==============" )
    print ( )
    print ( "Command: " .. command )
    print ( )
    print ( "Control: " .. Config.cnode_to_string ( ctrl_config ) )
    print ( )
    print ( "Access Points:" )
    print ( "--------------" )

    for _, ap in ipairs ( aps_config ) do
        print ( Config.cnode_to_string ( ap ) )
    end

    print ( )
    print ( "Stations:" )
    print ( "---------" )

    for _, sta_config in ipairs ( stas_config ) do
        print ( Config.cnode_to_string ( sta_config ) )
    end
    print ( )

    Config.save ( output_dir, ctrl_config, aps_config, stas_config )

    local ctrl_net_ref = NetIfRef:create ( ctrl_config ['ctrl_if'] )
    ctrl_net_ref:set_addr ( ctrl_config ['name'] )

    local o = ControlNodeRef:new { name = ctrl_config ['name']
                                 , ssh_port = tonumber ( ctrl_config ['ssh_port'] ) or 22
                                 , lua_bin = ctrl_config ['lua_bin'] or "/usr/bin/lua"
                                 , ctrl_net_ref = ctrl_net_ref
                                 , ctrl_port = ctrl_port
                                 , output_dir = output_dir
                                 , stats = {}
                                 , distance = distance
                                 , net_if = net_if
                                 , nameserver = nameserver
                                 , aps_config = aps_config
                                 , stas_config = stas_config
                                 , connections = connections
                                 }

    if ( log_port ~= nil and log_fname ~= nil ) then
        o.log_ref = LogNodeRef:create ( net_if.addr, log_port )
        o.log_ref:start ( output_dir .. "/" .. log_fname, o.lua_bin )
        o:send_info ( "wait until logger is running" )
    end

    -- stop when nameserver is not reachable / not working
    if ( nameserver ~= nil ) then
        local addr, _ = parse_ipv4 ( nameserver )
        local ping_ns, exit_code = Misc.execute ( "ping", "-c1", nameserver )
        if ( exit_code ~= 0 ) then
            return nil
        end
    end

    return o
end

function ControlNodeRef:__tostring ()
    return self.rpc.__tostring ()
end

function ControlNodeRef:init ( disable_autostart, disable_synchronize )
    if ( disable_autostart == false ) then
        if ( self.ctrl_net_ref.addr ~= nil and self.ctrl_net_ref.addr ~= self.net_if.addr ) then
            self.ctrl_pid = self:start_remote ()
        else
            self.ctrl_pid = self:start ()
        end
    end

    local succ = self:connect_control ()
    if ( succ ) then
        print ( "Control board: " .. ( self.rpc.get_board () or "unknown" ) )
        print ( "Control os-release: " .. ( self.rpc.get_os_release () or "unknown" ) )
        print ()

        --synchronize time
        if ( disable_synchronize == false
             and  self.ctrl_net_ref.addr ~= nil and self.ctrl_net_ref.addr ~= self.net_if.addr ) then
            local err
            local time = os.date ( "*t", os.time() )
            local cur_time, err = self.rpc.set_date ( time.year, time.month, time.day, time.hour, time.min, time.sec )
            if ( err == nil ) then
                print ( "Set date/time to " .. cur_time )
            else
                print ( "Error: Set date/time failed: " .. err )
                print ( "Time is: " .. ( cur_time or "unset" ) )
            end
        end

        if ( self.nameserver ) then
            self.rpc.set_nameserver ( self.nameserver )
        end

        -- add station and accesspoint references to control
        self:add_aps ()
        self:add_stas ()

    end

    self.ctrl_pid = self:get_pid ()
    return self.ctrl_pid
end

function ControlNodeRef:cleanup ( disable_autostart )
    if ( self.rpc == nil ) then return true end

    print ( " disconnect nodes " )
    self.rpc.disconnect_nodes ()

    -- kill nodes if desired by the user
    if ( disable_autostart == false ) then
        print ( "stop control" )
        self:stop_control ()
        if ( self.ctrl_net_ref.addr ~= nil and self.ctrl_net_ref.addr ~= self.net_if.addr ) then
            self:stop_remote ()
        else
            self:stop_local ()
        end
    end
    self:disconnect_control ()
end


function ControlNodeRef:get_pid ()
    if ( self.rpc ~= nil ) then
        return self.rpc.get_pid ()
    end
    return nil
end

function ControlNodeRef:check_bridges ()
    return self.rpc.check_bridges ()
end

function ControlNodeRef:restart_wifi_debug ()
    self.rpc.restart_wifi_debug()
end

function ControlNodeRef:set_ani ( enabled )
    for _, node_name in ipairs ( self:list_nodes () ) do
        self.rpc.set_ani ( node_name, enabled )
    end
end

function ControlNodeRef:set_ldpc ( enabled )
    for _, node_name in ipairs ( self:list_nodes () ) do
        self.rpc.set_ldpc ( node_name, enabled )
    end
end

function ControlNodeRef:add_aps ()
    for _, ap_config in ipairs ( self.aps_config ) do
        self.rpc.add_ap ( ap_config.name, ap_config.lua_bin or "/usr/bin/lua", ap_config.ctrl_if, ap_config.rsa_key )
    end
end

function ControlNodeRef:add_stas ()
    for _, sta_config in ipairs ( self.stas_config ) do
        self.rpc.add_sta ( sta_config.name, sta_config.lua_bin or "/usr/bin/lua", sta_config.ctrl_if,
                           sta_config.rsa_key, sta_config.mac )
    end
end

function ControlNodeRef:list_nodes ()
    return self.rpc.list_nodes ()
end

function ControlNodeRef:list_aps ()
    return self.rpc.list_aps ()
end

function ControlNodeRef:get_mac ( node_name )
    return self.rpc.get_mac ( node_name )
end

function ControlNodeRef:get_mac_br ( node_name )
    return self.rpc.get_mac_br ( node_name )
end

function ControlNodeRef:get_opposite_macs ( node_name )
    return self.rpc.get_opposite_macs ( node_name )
end

function ControlNodeRef:get_opposite_macs_br ( node_name )
    return self.rpc.get_opposite_macs_br ( node_name )
end

function ControlNodeRef:list_stations ( ap_name )
    return self.rpc.list_stations ( ap_name )
end

function ControlNodeRef:init_nodes ( disable_autostart
                                   , disable_reachable
                                   , disable_synchonize
                                   )
    if ( table_size ( self:list_nodes() ) == 0 ) then
        return false, "no nodes present"
    end

    -- check reachability 
    if ( disable_reachable == false ) then
        if ( self:reachable () == false ) then
            return false, "Some nodes are not reachable"
        end
    end

    -- and auto start nodes
    if ( disable_autostart == false ) then
        -- check known_hosts at control
        if ( self.rpc.hosts_known () == false ) then
            return false, "Not all hosts are known on control node. Check know_hosts file."
        end

        if ( self.rpc.start_nodes ( self.rsa_key , self.distance ) == false ) then
            return false, "Not all nodes started"
        end
    end

    print ( "Wait 3 seconds for nodes initialisation" )
    posix.sleep (3)

    -- and connect to nodes
    print ( "connect to nodes at port " .. self.ctrl_port )
    if ( self.rpc.connect_nodes ( self.ctrl_port ) == false ) then
        return false, "connections to nodes failed!"
    end

    for node_name, board in pairs ( self.rpc.get_boards () ) do
        print ( node_name .. " board: " .. board )
    end

    for node_name, os_release in pairs ( self.rpc.get_os_releases () ) do
        print ( node_name .. " os_release: " .. os_release )
    end

    -- synchonize time
    if ( disable_synchronize == false ) then
        self.rpc.set_dates ()
    end

    -- set nameserver on all nodes
    self.rpc.set_nameservers ( self.nameserver )

    if ( self:prepare_aps () == false ) then
        return false, "preparation of access points failed!"
    end

    if ( self:prepare_stas () == false ) then
        return false, "preparation of stations failed!"
    end

    self:associate_stas ()

    local all_linked = self:link_stas ()
    if ( all_linked == false ) then
        return false, "Cannot get ssid from acceesspoint"
    end

    return true, nil
end

function ControlNodeRef:prepare_aps ()
    local ap_names = self.rpc.list_aps ()
    for _, ap_name in ipairs ( ap_names ) do
        local config = config.find_node ( ap_name, self.aps_config )
        if ( config == nil ) then
            print ( "config for node " .. ap_name .. " not found" )
            return false
        end
        local phys = self.rpc.list_phys ( ap_name )
        local found = false
        for _, phy in ipairs ( phys ) do
            if ( string.sub ( config.radio, 6, 6 ) == string.sub ( phy, 4, 4 ) ) then
                self.rpc.set_phy ( ap_name, phy )
                if ( self.rpc.enable_wifi ( ap_name, true ) == true ) then
                    local ssid = self.rpc.get_ssid ( ap_name )
                    print ( "SSID: " .. ssid )
                end
                found = true
            end
        end
        if ( found == false ) then
            print ( "configured radio " .. config.radio .. " for " .. ap_name .. " not found" )
            return false
        end
    end
    return true
end

function ControlNodeRef:prepare_stas ()
    for _, sta_name in ipairs ( self.rpc.list_stas () ) do
        local config = config.find_node ( sta_name, self.stas_config )
        if ( config == nil ) then
            print ( "config for node " .. sta_name .. " not found" )
            return false
        end
        local phys = self.rpc.list_phys ( sta_name )
        local found = false
        for _, phy in ipairs ( phys ) do
            if ( string.sub ( config.radio, 6, 6 ) == string.sub ( phy, 4, 4 ) ) then
                self.rpc.set_phy ( sta_name, phy )
                self.rpc.enable_wifi ( sta_name, true )
            end
            found = true
        end
        if ( found == false ) then
            print ( "configured radio " .. config.radio .. " for " .. sta_name .. " not found" )
            return false
        end
    end
    return true
end

-- set mode of AP to 'ap'
-- set mode of STA to 'sta'
-- set ssid of AP and STA to ssid
-- fixme: set interface static address
-- fixme: setup dhcp server for wlan0
function ControlNodeRef:associate_stas ()
    for ap, stas in pairs ( self.connections ) do
        for _, sta in ipairs ( stas ) do
            print ( " connect " .. ap .. " with " .. sta )
            self.rpc.add_station ( ap, sta )
        end
    end

end

function ControlNodeRef:save_ssid ( name, ssid )

    local fname = self.output_dir .. "/" .. name .. "/ssid.txt"
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        file:write ( ssid .. "\n" )
        file:close()
    end

end

function ControlNodeRef:link_stas ()
    for ap, stas in pairs ( self.connections ) do
        local ssid = self.rpc.get_ssid ( ap )
        if ( ssid ~= nil ) then
            print ( "SSID: " .. ssid )
            self:save_ssid ( ap, ssid )
            for _, sta in ipairs ( stas ) do
                self.rpc.link_to_ssid ( sta, ssid ) 
                self:save_ssid ( sta, ssid )
            end
        else
            return false
        end
    end
    return true
end

function ControlNodeRef:start ()
    local cmd = {}
    cmd [1] = self.lua_bin or "/usr/bin/lua"
    cmd [2] = "/usr/bin/runControl"
    cmd [3] = "--port"
    cmd [4] = self.ctrl_port 
    cmd [5] = "--ctrl_if"
    cmd [6] = self.ctrl_net_ref.iface
    cmd [7] = "--output"
    cmd [8] = self.output_dir
    if ( self.log_ref ~= nil and self.net_if.addr ~= nil ) then
        cmd [9] = "--log_ip"
        cmd [10] = self.net_if.addr
        cmd [11] = "--log_port"
        cmd [12] = self.log_ref.port 
    end

    print ( cmd )
    local pid, _, _ = misc.spawn ( unpack ( cmd ) )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:start_remote ()
    local remote_cmd = self.lua_bin
                 .. " /usr/bin/runControl"
                 .. " --port " .. self.ctrl_port 
                 .. " --ctrl_if " .. self.ctrl_net_ref.iface
                 .. " --output " .. self.output_dir

    if ( self.log_ref ~= nil and self.net_if.addr ~= nil ) then
        remote_cmd = remote_cmd .. " --log_ip " .. self.net_if.addr
                       .. " --log_port " .. self.log_ref.port
    end
    print ( remote_cmd )
    -- fixme:  "-i", node_ref.rsa_key, 
    local pid, _, _ = misc.spawn ( "ssh", "-p", self.ssh_port, "root@" .. self.ctrl_net_ref.addr, remote_cmd )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:connect_control ()
    print ( "connect " .. self.ctrl_net_ref:__tostring() )
    self.rpc = net.connect ( self.ctrl_net_ref.addr, self.ctrl_port, 10, self.name,
                               function ( msg ) print ( msg ) end )
    return ( self.rpc ~= nil )
end

function ControlNodeRef:disconnect_control ()
    net.disconnect ( self.rpc )
end

function ControlNodeRef:stop_control ()
    self.rpc.stop ()
    if ( self.log_ref ~= nil ) then
        self.log_ref:stop ()
    end
end

function ControlNodeRef:stop_local ()
    ps.kill ( self.ctrl_pid, ps.SIGINT )
    ps.kill ( self.ctrl_pid, ps.SIGINT )
    lpc.wait ( self.ctrl_pid )
end

function ControlNodeRef:stop_remote ()
    local remote_cmd = self.lua_bin .. " /usr/bin/kill_remote " .. self.ctrl_pid .. " --INT -i 2"
    local ssh, exit_code = misc.execute ( "ssh", "-p", self.ssh_port, "root@" .. self.ctrl_net_ref.addr, remote_cmd )
    if ( exit_code == 0 ) then
        return true, nil
    else
        return false, ssh
    end
end

function ControlNodeRef:init_experiments ( command, args, ap_names, is_fixed )
    print ( "Init Experiments" )

    local ret = self.rpc.init_experiment ( command, args, ap_names, is_fixed )

    local all_rates = copy_map ( self.rpc.get_txrates () )
    for name, rates in pairs ( all_rates ) do 
        local rate_indices_fname = self.output_dir .. "/" .. name .. "/txrate_indices.txt"
        misc.write_table ( rates, rate_indices_fname )
    end

    local all_powers = copy_map ( self.rpc.get_txpowers () )
    for ap_name, powers in pairs ( all_powers ) do
        local power_indices_fname = self.output_dir .. "/" .. ap_name .. "/txpower_indices.txt"
        misc.write_table ( powers, power_indices_fname )
    end

    return ret
end

function ControlNodeRef:reachable ()
    local reached = self.rpc.reachable()
    if ( table_size ( reached ) == 0 ) then
        print ( "No hosts reachables" )
        return false
    end
    for addr, reached in pairs ( reached ) do
        if ( reached ) then
            print ( addr .. ": ONLINE" )
        else
            print ( addr .. ": OFFLINE" )
        end
    end
    return true
end

function ControlNodeRef:run_experiments ( command, args, ap_names, is_fixed, keys, channel, htmode )

    function check_mem ( mem, name )
        -- local warn_threshold = 40960
        local warn_threshold = 10240
        local error_threshold = 8192
        -- local error_threshold = 20280
        if ( mem < error_threshold ) then
            print ( name .. " is running out of memory. stop here" )
            return false
        elseif ( mem < warn_threshold ) then
            print ( name .. " has low memory." )
        end
        return true
    end

    -- save wifi channel and htmode
    local fname = self.output_dir .. "/wifi_config.txt"
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        file:write ( "channel = " .. channel .. '\n' )
        file:write ( "htmode = " .. htmode .. '\n' )
        file:write ( "distance = " .. self.distance .. '\n' )
        file:close ()
    end

    self.rpc.randomize_nodes ()

    self.stats = {}

    --[[
    for _, ap_ref in ipairs ( self.ap_refs ) do
        local free_m = ap_ref:get_free_mem ()
        check_mem ( free_m, ap_ref.name )
        for _, sta_ref in ipairs ( ap_ref.refs ) do
            local free_m = sta_ref:get_free_mem ()
            check_mem ( free_m, sta_ref.name )
        end
    end
    --]]

    -- choose smallest set of keys
    -- fixme: still differs over all APs maybe
    -- better each ap should run its own set of keys

    if (  keys == nil ) then
        keys = self.rpc.get_keys ()
    end
    pprint ( keys )
    local min_len = # ( keys [ 1 ] )
    local key_index = 1
    for i, key_list in ipairs ( keys ) do
        if ( #key_list < min_len ) then
            min_len = #key_list
            key_index = i
        end
    end

    local stop = false
    local counter = 1

    -- randomize keys
    local keys_random = misc.randomize_list ( keys [ key_index ] )

    -- save experiment order
    local fname = self.output_dir .. "/experiment_order.txt"
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        for _, key in ipairs ( keys_random ) do
            file:write ( key .. '\n' )
        end
        file:close()
    end

    local ret = true
    local err = nil
    -- run expriments
    print ( "Run " .. min_len .. " experiments." )

    for _, key in ipairs ( keys_random ) do 
        local exp_header = "* Start experiment " .. counter .. " of " .. min_len
                            .. " with key " .. ( key or "none" ) .. " *"
        print ( exp_header )

        ret, err = self.rpc.run_experiment ( command, args, ap_names, is_fixed, key, counter, min_len, channel, htmode )
        if ( ret == false ) then
            return ret, err
        end

        print ("* Transfer Measurement Result *")

        local node_names = self:list_nodes ()
        for _, ref_name in ipairs ( node_names ) do
            
            local stats = self.rpc.get_stats ( ref_name )

            if ( self.stats [ ref_name ] == nil ) then
                local mac = self:get_mac ( ref_name )
                local opposite_macs = self:get_opposite_macs ( ref_name )

                local measurement = Measurement:create ( ref_name, mac, opposite_macs, nil, self.output_dir )
                measurement.node_mac_br = self:get_mac_br ()
                self.stats [ ref_name ] = measurement

                local stations = {}
                for station, _ in pairs ( stats.rc_stats ) do
                    stations [ #stations + 1 ] = station
                end
                measurement:enable_rc_stats ( stations ) -- resets rc_stats
            end

            merge_map ( stats [ 'cpusage_stats' ] , self.stats [ ref_name ].cpusage_stats )
            merge_map ( stats [ 'rc_stats' ] , self.stats [ ref_name ].rc_stats )
            merge_map ( stats [ 'regmon_stats' ] , self.stats [ ref_name ].regmon_stats )
            merge_map ( stats [ 'tcpdump_pcaps' ] , self.stats [ ref_name ].tcpdump_pcaps )
            merge_map ( stats [ 'iperf_s_outs' ] , self.stats [ ref_name ].iperf_s_outs )
            merge_map ( stats [ 'iperf_c_outs' ] , self.stats [ ref_name ].iperf_c_outs )

            local status, err = self.stats [ ref_name ]:write ()
            if ( status == false ) then
                print ( "err: can't access directory '" ..  ( output_dir or "unset" )
                                .. "': " .. ( err or "unknown error" ) )
            else
                print ( self.stats [ ref_name ]:__tostring() )
            end
            self.stats [ ref_name ] = nil
        end

        counter = counter + 1
    end

    return ret, err

end

-- -------------------------
-- Logging
-- -------------------------

function ControlNodeRef:set_cut ()
    if ( self.log_ref ~= nil ) then
        self.log_ref:set_cut ()
    end
end

function ControlNodeRef:send_error ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_error ( self.name, msg )
    end
end

function ControlNodeRef:send_info ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_info ( self.name, msg )
    end
end

function ControlNodeRef:send_warning ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_warning ( self.name, msg )
    end
end

function ControlNodeRef:send_debug ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_debug ( self.name, msg )
    end
end
