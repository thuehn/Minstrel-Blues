
local posix = require ('posix') -- sleep
require ('rpc')
local lpc = require ('lpc')
local misc = require ('misc')
local pprint = require ('pprint')
local config = require ('Config') -- find_node
local net = require ('Net')
local ps = require ('posix.signal') --kill

require ('NetIfRef')
require ('MeasurementOption')
require ('Measurements')
require ('LogNodeRef')

ControlNodeRef = { name = nil           -- hostname of the control node ( String )
                 , ssh_port = nil       -- ssh port ( Number )
                 , lua_bin = nil        -- lua binary path ( String )
                 , ctrl_net_ref = nil   -- reference to control interface ( NetRef )
                 , rpc = nil            -- rpc client ( userdata )
                 , output_dir = nil     -- path to measurment result ( String )
                 , distance = nil       -- approx.distance between node just for the log file ( String )
                 , net_if = nil         -- local network interface ( NetIF )
                 , log_ref = nil        -- reference to logger ( LogNodeRef )
                 , nameserver = nil     -- IP of the nameserver ( String )
                 , ctrl_port = nil      -- port of control node ( Number )
                 , aps_config = nil     -- list of AP configs
                 , sta_config = nil     -- list of STA configs
                 , connections = nil    -- list of APs and connections to STAs
                 , mesh_nodes_config = nil -- list of mesh nodes configs
                 , ctrl_pid = nil       -- PID of control node process
                 , retries = nil        -- number of retries for rpc and wifi connections
                 , online = nil         -- fetch data online
                 , dump_to_dir = nil    -- dump collected traces to local directory at each device until experiments are finished
                 , measurements = nil   -- list of running measurements
                 , mopts = nil          -- additional options and propteries backuped in measurements options.txt file
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
                               , ctrl_arg
                               , ap_args, sta_args
                               , mesh_args
                               , connections
                               , ap_setups, sta_setups, mesh_setups
                               , command
                               , retries
                               , online
                               , dump_to_dir
                               )
    if ( retries == nil ) then error ( "retries" ) end
    print ( "retries: " .. retries )
    -- access points
    local ap_names = {}
    for _, ap in ipairs ( ap_args ) do
        local parts = split ( ap, "," )
        ap_names [ #ap_names + 1 ] = parts [ 1 ]
    end
    local aps_config = Config.select_configs ( ap_setups, ap_names )

    -- stations
    local sta_names = {}
    for _, sta in ipairs ( sta_args ) do
        local parts = split ( sta, "," )
        sta_names [ #sta_names + 1 ] = parts [ 1 ]
    end
    local stas_config = Config.select_configs ( sta_setups, sta_names )

    -- mesh nodes
    local mesh_names = {}
    for _, node in ipairs ( mesh_args ) do
        local parts = split ( node, "," )
        mesh_names [ #mesh_names + 1 ] = parts [ 1 ]
    end
    local mesh_nodes_config = Config.select_configs ( mesh_setups, mesh_names )
    
    -- check configs
    if ( ( aps_config ~= nil and table_size ( aps_config ) == 0 
            and stas_config ~= nil and table_size ( stas_config ) == 0 )
        or ( mesh_nodes_config ~= nil and table_size ( mesh_nodes_config ) == 0 ) ) then
        return nil
    end

    -- control
    local ctrl_config = Config.select_config ( nodes, ctrl_arg )
    if ( ctrl_config == nil ) then return nil end

    print ( "Configuration:" )
    print ( "==============" )
    print ( )
    print ( "Command: " .. command )
    print ( )
    print ( "Control: " .. Config.cnode_to_string ( ctrl_config ) )
    print ( )

    if ( aps_config ~= nil and table_size ( aps_config ) > 0 ) then
        print ( "Access Points:" )
        print ( "--------------" )

        for _, ap in ipairs ( aps_config ) do
            print ( Config.cnode_to_string ( ap ) )
        end
    end

    if ( stas_config ~= nil and table_size ( stas_config ) > 0 ) then
        print ( )
        print ( "Stations:" )
        print ( "---------" )

        for _, sta_config in ipairs ( stas_config ) do
            print ( Config.cnode_to_string ( sta_config ) )
        end
        print ( )
    end

    if ( meshs_config ~= nil and table_size ( meshs_config ) > 0 ) then
        print ( )
        print ( "Mesh:" )
        print ( "---------" )

        for _, mesh_config in ipairs ( meshs_config ) do
            print ( Config.cnode_to_string ( mesh_config ) )
        end
        print ( )
    end

    -- Config.save ( output_dir, ctrl_config, aps_config, stas_config, mesh_nodes_config )
    -- stations.txt
    -- accesspoints.txt
    -- control.txt
    -- experiment_order.txt
    -- meshs.txt
    -- wifi_config.txt

    local ctrl_net_ref = NetIfRef:create ( ctrl_config ['ctrl_if'] )
    ctrl_net_ref:set_addr ( ctrl_config ['name'] )

    local o = ControlNodeRef:new { name = ctrl_config ['name']
                                 , ssh_port = tonumber ( ctrl_config ['ssh_port'] ) or 22
                                 , lua_bin = ctrl_config ['lua_bin'] or "/usr/bin/lua"
                                 , ctrl_net_ref = ctrl_net_ref
                                 , ctrl_port = ctrl_port
                                 , output_dir = output_dir
                                 , distance = distance
                                 , net_if = net_if
                                 , nameserver = nameserver
                                 , aps_config = aps_config
                                 , stas_config = stas_config
                                 , mesh_nodes_config
                                 , connections = connections
                                 , retries = retries
                                 , online = online
                                 , dump_to_dir = dump_to_dir
                                 , measurements = {}
                                 }

    o.mopts = {}
    o.mopts [ "accesspoints" ] = MeasurementsOption:create ( "accesspoints", "List", ap_names )
    o.mopts [ "stations" ] = MeasurementsOption:create ( "stations", "List", sta_names )
    o.mopts [ "meshs" ] = MeasurementsOption:create ( "meshs", "List", mesh_names )
    o.mopts [ "control" ] = MeasurementsOption:create ( "control", "String", ctrl_config.name )
    MeasurementsOption.write_file ( o.output_dir, o.mopts )

    if ( log_port ~= nil and log_fname ~= nil ) then
        o.log_ref = LogNodeRef:create ( net_if.addr, log_port, retries )
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
        local is_mesh = self.mesh_node_config ~= nil and table_size ( self.mesh_nodes_config ) > 0
        if ( is_mesh ~= true ) then
            self:add_aps ()
            self:add_stas ()
        else
            self:add_mesh_nodes ()
        end

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

function ControlNodeRef:add_mesh_nodes ()
    for _, node_config in ipairs ( self.mesh_nodes_config ) do
        self.rpc.add_mesh_node ( node_config.name, node_config.lua_bin or "/usr/bin/lua", node_config.ctrl_if,
                                 node_config.rsa_key )
    end
end

function ControlNodeRef:list_nodes ()
    return self.rpc.list_nodes ()
end

function ControlNodeRef:list_aps ()
    return self.rpc.list_aps ()
end

function ControlNodeRef:list_stations ( ap_name )
    return self.rpc.list_stations ( ap_name )
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

function ControlNodeRef:init_nodes ( disable_autostart
                                   , disable_reachable
                                   , disable_synchonize
                                   )
    if ( table_size ( self:list_nodes () ) == 0 ) then
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

    local seconds = tonumber ( self.retries or 10 ) / 3
    if ( seconds < 3 ) then seconds = 3 end
    print ( "Wait " .. tostring ( seconds ) .. " seconds for nodes initialisation" )
    posix.sleep ( seconds )

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

    if ( table_size ( self.aps_config ) > 0 ) then
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
    else
        if ( self:prepare_meshs () == false ) then
            return false, "preparation of mesh nodes failed!"
        end

        self:asociate_mesh ()
        --fixme: link to mesh_id
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
                    print ( "SSID: " .. ( ssid or "unset" ) )
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

function ControlNodeRef:prepare_meshs ()
    for _, node_name in ipairs ( self.rpc.list_nodes () ) do
        local config = config.find_node ( node_name, self.nodes_config )
        if ( config == nil ) then
            print ( "config for node " .. node_name .. " not found" )
            return false
        end
        local phys = self.rpc.list_phys ( node_name )
        local found = false
        for _, phy in ipairs ( phys ) do
            if ( string.sub ( config.radio, 6, 6 ) == string.sub ( phy, 4, 4 ) ) then
                self.rpc.set_phy ( node_name, phy )
                self.rpc.enable_wifi ( node_name, true )
            end
            found = true
        end
        if ( found == false ) then
            print ( "configured radio " .. config.radio .. " for " .. node_name .. " not found" )
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
            print ( " associate " .. ap .. " with " .. sta )
            self.rpc.add_station ( ap, sta )
        end
    end
end

function ControlNodeRef:associate_mesh ()
    for node, stas in pairs ( self.connections ) do
        for _, sta in ipairs ( stas ) do
            print ( " associate " .. node .. " with " .. sta )
            self.rpc.add_station ( node, sta )
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
    local cmd = { self.lua_bin or "/usr/bin/lua"
                , "/usr/bin/runControl"
                , "--port"
                , self.ctrl_port
                , "--ctrl_if"
                , self.ctrl_net_ref.iface
                , "--output"
                , self.output_dir
                , "--retries"
                , self.retries
                }

    if ( self.online == true ) then
        cmd [ #cmd + 1 ] = "--online"
    end
    if ( self.log_ref ~= nil and self.net_if.addr ~= nil ) then
        cmd [ #cmd + 1 ] = "--log_ip"
        cmd [ #cmd + 1 ] = self.net_if.addr
        cmd [ #cmd + 1 ] = "--log_port"
        cmd [ #cmd + 1 ] = self.log_ref.port
    end

    if ( self.dump_to_dir ~= nil ) then
        cmd [ #cmd + 1 ] = "-d"
        cmd [ #cmd + 1 ] = self.dump_to_dir
    end

    print ( table_tostring ( cmd, nil, "" ) )
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
                 .. " --retries " .. self.retries
    if ( self.online == true ) then
        remote_cmd = remote_cmd .. " --online"
    end

    if ( self.log_ref ~= nil and self.net_if.addr ~= nil ) then
        remote_cmd = remote_cmd .. " --log_ip " .. self.net_if.addr
                       .. " --log_port " .. self.log_ref.port
    end
    if ( self.dump_to_dir ~= nil ) then
        remote_cmd = remote_cmd .. " -d " .. self.dump_to_dir
    end
    print ( remote_cmd )
    -- fixme:  "-i", node_ref.rsa_key, 
    local pid, _, _ = misc.spawn ( "ssh", "-p", self.ssh_port, "root@" .. self.ctrl_net_ref.addr, remote_cmd )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:connect_control ()
    print ( "connect " .. self.ctrl_net_ref:__tostring() )
    self.rpc = net.connect ( self.ctrl_net_ref.addr, self.ctrl_port, self.retries, self.name,
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

-- fixme: sometimes this waits forever
function ControlNodeRef:stop_local ()
    print ( "kill control:" .. ( self.ctrl_pid or "none" ) )
    -- lua should terminate by two times sigint, but sometimes it didn't
    --ps.kill ( self.ctrl_pid, ps.SIGINT )
    --ps.kill ( self.ctrl_pid, ps.SIGINT )
    ps.kill ( self.ctrl_pid )
    ps.kill ( self.ctrl_pid )
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

-- fixme: MESH
function ControlNodeRef:init_experiments ( command, args, ap_names, is_fixed )
    print ( "Init Experiments" )

    local ret = self.rpc.init_experiments ( command, args, ap_names, is_fixed )

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
    local reached = self.rpc.reachable ()
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


function ControlNodeRef:create_measurement ( node_names, key )
    for _, ref_name in ipairs ( node_names ) do

        print ( "transfer node: " .. ref_name )

        local mac = self:get_mac ( ref_name )
        local opposite_macs = self:get_opposite_macs ( ref_name )

        local measurements = Measurements:create ( ref_name, mac, opposite_macs, nil, self.output_dir, self.online )

        local stations = self.rpc.list_stations ( ref_name )
        measurements:enable_rc_stats ( stations ) -- resets rc_stats

        local added, err_msg = measurements:add_key ( key, self.output_dir )
        if ( not added and err_msg ~= nil ) then
            print ( "ERROR: " .. err_msg )
        end
        measurements:set_node_mac_br ( self:get_mac_br () )

        self.measurements [ ref_name ] = measurements
    end
end

function ControlNodeRef:write_measurement ( node_names, online, finish, key )
    print ("* Transfer Measurement Result *")

    local max_size = 1024 * 1024 -- 1 megabyte at once
    for _, ref_name in ipairs ( node_names ) do

        print ( "transfer node: " .. ref_name )

        local size = self.rpc.get_tcpdump_size ( ref_name, key )
        local tcpdump_pcap = self.measurements [ ref_name ].tcpdump_meas [ key ].stats
        local i = 0
        repeat
            local succ, res = self.rpc.get_tcpdump_pcap ( ref_name, key, ( max_size * i ) + 1, max_size )
            if ( succ == false ) then
                print ( "ERROR: ControlNodeRef:write_measurement:" .. ( res or "unknown" ) )
                return
            end
            local pcap = res
            if ( pcap ~= nil ) then
                tcpdump_pcap = tcpdump_pcap .. pcap
            end
            i = i + 1
        until ( ( ( i + 1 ) * max_size ) + 1 ) > size
        self.measurements [ ref_name ].tcpdump_meas [ key ].stats = tcpdump_pcap

        local stations = self:list_stations ( ref_name )
        for _, station in ipairs ( stations ) do
            if ( self.measurements [ ref_name ].rc_stats_meas ~= nil
                 and self.measurements [ ref_name ].rc_stats_meas [ station ] ~= nil
                 and self.measurements [ ref_name ].rc_stats_meas [ station ] [ key ] ~= nil ) then
                self.measurements [ ref_name ].rc_stats_meas [ station ] [ key ].stats
                    = ( self.measurements [ ref_name ].rc_stats_meas [ station ] [ key ].stats or "" )
                      .. self.rpc.get_rc_stats ( ref_name, station, key )
            end
        end

        self.measurements [ ref_name ].cpusage_meas [ key ].stats
            = self.measurements [ ref_name ].cpusage_meas [ key ].stats
              .. self.rpc.get_cpusage_stats ( ref_name, key )

        self.measurements [ ref_name ].regmon_meas [ key ].stats
            = self.measurements [ ref_name ].regmon_meas [ key ].stats
              .. self.rpc.get_regmon_stats ( ref_name, key )
        
        local iperf_s_out = self.rpc.get_iperf_s_out ( ref_name )
        merge_map ( iperf_s_out, self.measurements [ ref_name ].iperf_s_outs )
        
        local iperf_c_out = self.rpc.get_iperf_c_out ( ref_name )
        merge_map ( iperf_c_out, self.measurements [ ref_name ].iperf_c_outs )

        print ( "stats fetched" )

        local status, err = self.measurements [ ref_name ]:write ( online, finish, key )
        if ( status == false ) then
            print ( "err: can't access directory '" ..  ( output_dir or "unset" )
                            .. "': " .. ( err or "unknown error" ) )
        else
            print ( self.measurements [ ref_name ]:__tostring() )
        end

        if ( finish == true ) then
            self.measurements [ ref_name ] = nil
        end

        if ( dmesg == true ) then
            self:get_dmesg ( ref_name, key )
        end
    end

end

-- fixme: MESH
function ControlNodeRef:run_experiments ( command, args, ap_names, is_fixed, keys, channel, htmode, dmesg )

    --[[
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

    for _, ap_ref in ipairs ( self.ap_refs ) do
        local free_m = ap_ref:get_free_mem ()
        check_mem ( free_m, ap_ref.name )
        for _, sta_ref in ipairs ( ap_ref.refs ) do
            local free_m = sta_ref:get_free_mem ()
            check_mem ( free_m, sta_ref.name )
        end
    end
    --]]

    local current_channel = self.rpc.get_channel ()
    local current_htmode = self.rpc.get_htmode ()

    -- save wifi channel and htmode
    self.mopts [ "wifi_channel" ] = MeasurementsOption:create ( "wifi_channel", "String", channel or current_channel )
    self.mopts [ "wifi_htmode" ] = MeasurementsOption:create ( "wifi_htmode", "String", htmode or current_htmode )
    self.mopts [ "wifi_distance" ] = MeasurementsOption:create ( "wifi_distance", "String", self.distance )
    MeasurementsOption.write_file ( self.output_dir, self.mopts )

    self.rpc.randomize_nodes ()

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
    self.mopts [ "experiment_order" ] = MeasurementsOption:create ( "experiment_order", "List", keys_random )
    MeasurementsOption.write_file ( self.output_dir, self.mopts )

    local ret = true
    local err = nil
    -- run expriments
    print ( "Run " .. min_len .. " experiments." )

    local node_names = self:list_nodes ()

    if ( dmesg == true ) then
        for _, ref_name in ipairs ( node_names ) do
            self:get_dmesg ( ref_name, "init" )
        end
    end

    for _, key in ipairs ( keys_random ) do 
        local exp_header = "* Start experiment " .. counter .. " of " .. min_len
                            .. " with key " .. ( key or "none" ) .. " *"
        print ( exp_header )

        -- fixme: MESH
        ret, err = self.rpc.init_experiment ( command, args, ap_names, is_fixed, key, counter, min_len, channel, htmode )
        if ( ret == false ) then
            return ret, err
        end

        self:create_measurement ( node_names, key )
        if ( self.online == true ) then
            repeat
                ret, err = self.rpc.exp_next_data ( key )
                if ( ret == false ) then
                    print ( "ERROR: ControlNodeRef:run_experiments exp_next_data failed: " .. ( ret or "unknown" ) )
                    return ret, err
                end
                self:write_measurement ( node_names, self.online, false, key )
                posix.sleep (1)
            until self.rpc.exp_has_data ( key ) == false
        end

        ret, err = self.rpc.finish_experiment ( key )
        self:write_measurement ( node_names, self.online, true, key )

        counter = counter + 1
    end

    return ret, err
end

function ControlNodeRef:get_dmesg ( ref_name, key )
    -- dmesg
    local dmesg_out = self.rpc.get_dmesg ( ref_name )
    if ( dmesg_out ~= nil ) then
        if ( isDir ( self.output_dir .. "/" .. ref_name ) == false ) then
            lfs.mkdir ( self.output_dir .. "/" .. ref_name )
        end
        local fname = self.output_dir .. "/" .. ref_name .. "/dmesg-" .. key .. ".txt"
        if ( isFile ( fname ) == true ) then
            fname = fname .. "." .. os.time ()
        end
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            file:write ( dmesg_out )
            file:close ()
        end
    end
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
        self.log_ref:send_error ( self.name .. "-Ref", msg )
    end
end

function ControlNodeRef:send_info ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_info ( self.name .. "-Ref", msg )
    end
end

function ControlNodeRef:send_warning ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_warning ( self.name .. "-Ref", msg )
    end
end

function ControlNodeRef:send_debug ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_debug ( self.name .. "-Ref", msg )
    end
end
