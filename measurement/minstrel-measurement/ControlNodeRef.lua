
local posix = require ('posix') -- sleep
require ("rpc")
require ("lpc")
local misc = require 'misc'
local net = require ('Net')
require ('NetIF')
local pprint = require ('pprint')

ControlNodeRef = { name = nil
                 , ctrl = nil
                 , rpc = nil
                 , output_dir = nil
                 , stats = nil   -- maps node name to statistics
                 }

function ControlNodeRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ControlNodeRef:create ( name, ctrl_if, output_dir )
    -- ctrl node iface, ctrl node (name) lookup
    local ctrl_net = NetIF:create ( ctrl_if )
    local ctrl_ip, rest = parse_ipv4 ( name )
    ctrl_net.addr = ctrl_ip
    if ( ctrl_net.addr == nil ) then
        -- name is a host name (and bo ip address)
        local ip_addr, _ = net.lookup ( name )
        if ( ip_addr ~= nil ) then
            ctrl_net.addr = ip_addr
        end 
    end

    local o = ControlNodeRef:new { name = name, ctrl = ctrl_net, output_dir = output_dir, stats = {}  }
    return o
end

function ControlNodeRef:__tostring ()
    return self.rpc.__tostring ()
end

function ControlNodeRef:get_pid ()
    return self.rpc.get_pid ()
end

function ControlNodeRef:check_bridges ()
    return self.rpc.check_bridges ()
end

function ControlNodeRef:restart_wifi_debug ()
    self.rpc.restart_wifi_debug()
end

function ControlNodeRef:set_nameserver ( nameserver )
    self.rpc.set_nameserver ( nameserver )
end

function ControlNodeRef:set_nameservers ( nameserver )
    self.rpc.set_nameservers ( nameserver )
end

function ControlNodeRef:get_board ()
    return self.rpc.get_board ()
end

function ControlNodeRef:get_boards ()
    return self.rpc.get_boards ()
end

function ControlNodeRef:set_date ( ... )
    return self.rpc.set_date ( ... )
end

function ControlNodeRef:set_dates ()
    return self.rpc.set_dates ()
end

function ControlNodeRef:set_ani ( enabled )
    for _, node_name in ipairs ( self:list_nodes() ) do
        self.rpc.set_ani ( node_name, enabled )
    end
end

function ControlNodeRef:add_aps ( ap_configs )
    for _, ap_config in ipairs ( ap_configs ) do
        self.rpc.add_ap ( ap_config.name,  ap_config.ctrl_if, ap_config.rsa_key )
    end
end

function ControlNodeRef:add_stas ( sta_configs )
    for _, sta_config in ipairs ( sta_configs ) do
        self.rpc.add_sta ( sta_config.name,  sta_config.ctrl_if, sta_config.rsa_key )
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

function ControlNodeRef:get_opposite_macs ( node_name )
    return self.rpc.get_opposite_macs ( node_name )
end

function ControlNodeRef:list_stations ( ap_name )
    return self.rpc.list_stations ( ap_name )
end

function ControlNodeRef:start_nodes ( log_addr, log_port )
    return self.rpc.start_nodes ( log_addr, log_port )
end

function ControlNodeRef:connect_nodes ( port )
    return self.rpc.connect_nodes ( port )
end

function ControlNodeRef:disconnect_nodes ()
    return self.rpc.disconnect_nodes ()
end

function ControlNodeRef:prepare_aps ()
    local ap_names = self.rpc.list_aps()
    for _, ap_name in ipairs ( ap_names ) do
        local wifis = self.rpc.list_phys ( ap_name )
        self.rpc.set_phy ( ap_name, wifis[1] )
        if ( self.rpc.enable_wifi ( ap_name, true ) == true ) then
            local ssid = self.rpc.get_ssid ( ap_name )
            print ( "SSID: " .. ssid )
        end
    end
end

function ControlNodeRef:prepare_stas ()
    for _, sta_name in ipairs ( self.rpc.list_stas() ) do
        local wifis = self.rpc.list_phys ( sta_name )
        self.rpc.set_phy ( sta_name, wifis[1] )
        self.rpc.enable_wifi ( sta_name, true )
    end
end

-- set mode of AP to 'ap'
-- set mode of STA to 'sta'
-- set ssid of AP and STA to ssid
-- fixme: set interface static address
-- fixme: setup dhcp server for wlan0
function ControlNodeRef:associate_stas ( connections )
    for ap, stas in pairs ( connections ) do
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

function ControlNodeRef:link_stas ( connections )
    for ap, stas in pairs ( connections ) do
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

function ControlNodeRef:start ( ctrl_port, log_file, log_port )
    local cmd = {}
    cmd [1] = "lua"
    cmd [2] = "/usr/bin/runControl"
    cmd [3] = "--port"
    cmd [4] = ctrl_port 
    cmd [5] = "--ctrl_if"
    cmd [6] = self.ctrl.iface
    cmd [7] = "--output"
    cmd [8] = self.output_dir
    if ( log_file ~= nil and log_port ~= nil ) then
        cmd [9] = "--log_file"
        cmd [10] = log_file
        cmd [11] = "--log_port"
        cmd [12] = log_port 
    end

    print ( cmd )
    local pid, _, _ = misc.spawn ( unpack ( cmd ) )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:start_remote ( ctrl_port, log_file, log_port )
    local remote_cmd = "lua /usr/bin/runControl"
                 .. " --port " .. ctrl_port 
                 .. " --ctrl_if " .. self.ctrl.iface
                 .. " --output " .. self.output_dir

    if ( log_file ~= nil and log_port ~= nil ) then
        remote_cmd = remote_cmd .. " --log_file " .. log_file 
                       .. " --log_port " .. log_port 
    end
    print ( remote_cmd )
    -- fixme:  "-i", node_ref.rsa_key, 
    local pid, _, _ = misc.spawn ( "ssh", "root@" .. self.ctrl.addr, remote_cmd )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:connect ( ctrl_port )
    self.rpc = net.connect ( self.ctrl.addr, ctrl_port, 10, self.name, 
                               function ( msg ) print ( msg ) end )
    return self.rpc
end

function ControlNodeRef:disconnect ()
    net.disconnect ( self.rpc )
end


function ControlNodeRef:stop_control ()
    local log = self.rpc.stop()
    return log
end

function ControlNodeRef:stop ( pid )
    ps.kill ( pid, ps.SIGINT )
    ps.kill ( pid, ps.SIGINT )
    lpc.wait ( pid )
end

function ControlNodeRef:stop_remote ( addr, pid )
    local remote_cmd = "lua /usr/bin/kill_remote " .. pid .. " --INT -i 2"
    local ssh, exit_code = misc.execute ( "ssh", "root@" .. addr, remote_cmd )
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

function ControlNodeRef:hosts_known ()
    return self.rpc.hosts_known ()
end

function ControlNodeRef:run_experiments ( command, args, ap_names, is_fixed )

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

    print ()

    self.stats = {}

        --[[
        for _, ap_ref in ipairs ( self.ap_refs ) do
            local free_m = ap_ref:get_free_mem ()
            if ( check_mem ( free_m, ap_ref.name ) == false ) then
                return false
            end
            for _, sta_ref in ipairs ( ap_ref.refs ) do
                local free_m = sta_ref:get_free_mem ()
                if ( check_mem ( free_m, sta_ref.name ) == false ) then
                    return false
                end
            end
        end
        --]]

    -- choose smallest set of keys
    -- fixme: still differs over all APs maybe
    -- better each ap should run its own set of keys

    local keys = self.rpc.get_keys ()
    pprint ( self.rpc.get_keys () )
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
    -- TODO: randomize ap and station order
    local keys_random = {}
    math.randomseed ( os.time() )
    local set = {}
    while table_size ( keys_random ) < table_size ( keys [ key_index ] ) do

        local nxt = math.random (1, table_size ( keys [ key_index ] ) )
        if ( set [ nxt ] ~= true ) then
            set [ nxt ] = true
            keys_random [ #keys_random + 1 ] = keys [ key_index ] [ nxt ]
        end

    end

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
    -- run expriments
    print ( "Run " .. min_len .. " experiments." )

    for _, key in ipairs ( keys_random ) do 
        local exp_header = "* Start experiment " .. counter .. " of " .. min_len
                            .. " with key " .. ( key or "none" ) .. " *"
        print ( exp_header )

        ret = self.rpc.run_experiment ( command, args, ap_names, is_fixed, key, counter, min_len )

        print ("* Transfer Measurement Result *")
        local stats = self.rpc.get_stats ()
        for ref_name, stats in pairs ( stats ) do
            if ( self.stats [ ref_name ] == nil ) then
                self.stats [ ref_name ] = {}
                self.stats [ ref_name ] [ 'cpusage_stats' ] = {}
                self.stats [ ref_name ] [ 'rc_stats' ] = {}
                self.stats [ ref_name ] [ 'regmon_stats' ] = {}
                self.stats [ ref_name ] [ 'tcpdump_pcaps' ] = {}
            end
            merge_map ( stats [ 'cpusage_stats' ] , self.stats [ ref_name ] [ 'cpusage_stats' ] )
            merge_map ( stats [ 'rc_stats' ] , self.stats [ ref_name ] [ 'rc_stats' ] )
            merge_map ( stats [ 'regmon_stats' ] , self.stats [ ref_name ] [ 'regmon_stats' ] )
            merge_map ( stats [ 'tcpdump_pcaps' ] , self.stats [ ref_name ] [ 'tcpdump_pcaps' ] )
        end

        counter = counter + 1
    end

    return ret

end
