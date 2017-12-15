
local pprint = require ('pprint')

local ps = require ('posix.signal') --kill
local posix = require ('posix') -- sleep
local lpc = require 'lpc'
local misc = require 'misc'
local net = require ('Net')

require ('NodeBase')

require ('NetIF')
require ('misc')
require ('Uci')

require ('AccessPointRef')
require ('StationRef')

require ('tcpExperiment')
require ('udpExperiment')
require ('mcastExperiment')
require ('EmptyExperiment')

ControlNode = NodeBase:new ()

function ControlNode:create ( name, ctrl, port, log_port, log_addr, output_dir, retries, online )
    local o = ControlNode:new ( { name = name
                                , ctrl = ctrl
                                , port = port
                                , log_port = log_port
                                , log_addr = log_addr
                                , output_dir = output_dir
                                , ap_refs = {}     -- list of access point nodes
                                , sta_refs = {}    -- list of station nodes
                                , node_refs = {}   -- list of all nodes
                                , pids = {}    -- maps node name to process id of lua node
                                , exp = nil
                                , keys = {}
                                , retries = retries
                                , online = online
                                , running = false
                                } )
    if ( o.ctrl.addr == nil ) then
        o.ctrl:get_addr ()
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

function ControlNode:restart_wifi_debug ()
    if ( table_size ( self.ap_refs ) == 0 ) then
        self:send_warning ( "Cannot start wifi on APs. Not initialized" )
        print ( "Cannot start wifi on APs. Not initialized" )
    end
    for _, ap_ref in ipairs ( self.ap_refs ) do
        ap_ref.restart_wifi ()
    end
end

function ControlNode:add_ap ( name, lua_bin, ctrl_if, rsa_key )
    self:send_info ( " add access point " .. name )
    local ref = AccessPointRef:create ( name, lua_bin, ctrl_if, rsa_key
                                      , self.output_dir, self.log_addr, self.log_port
                                      , self.retries )
    self.ap_refs [ #self.ap_refs + 1 ] = ref 
    self.node_refs [ #self.node_refs + 1 ] = ref
end

function ControlNode:add_sta ( name, lua_bin, ctrl_if, rsa_key, mac )
    self:send_info ( " add station " .. name )
    local ref = StationRef:create ( name, lua_bin, ctrl_if, rsa_key
                                  , self.output_dir, mac, self.log_addr, self.log_port
                                  , self.retries )
    self.sta_refs [ #self.sta_refs + 1 ] = ref 
    self.node_refs [ #self.node_refs + 1 ] = ref
end

function ControlNode:add_mesh_node ( name, lua_bin, ctrl_if, rsa_key, mac )
    self:send_info ( " add mesh_node " .. name )
    local ref = MeshNodeRef:create ( name, lua_bin, ctrl_if, rsa_key
                                  , self.output_dir, mac, self.log_addr, self.log_port
                                  , self.retries )
    self.node_refs [ #self.node_refs + 1 ] = ref
end
-- randomize ap and station order
function ControlNode:randomize_nodes ()
    --randomize aps
    local aps = self:list_aps ()
    local aps_random = misc.randomize_list ( aps )
    local ap_refs = {}
    for _, ap_name in ipairs ( aps_random ) do
        local ap_ref = self:find_node_ref ( ap_name )
        ap_refs [ #ap_refs + 1 ] = ap_ref
    end
    self.ap_refs = ap_refs
    --randomize stas
    local stas = self:list_stas ()
    local stas_random = misc.randomize_list ( stas )
    local sta_refs = {}
    for _, sta_name in ipairs ( stas_random ) do
        local sta_ref = self:find_node_ref ( sta_name )
        sta_refs [ #sta_refs + 1 ] = sta_ref
    end
    self.sta_refs = sta_refs
    if ( table_size ( self.ap_refs ) > 0 ) then
        -- copy to node_refs
        local node_refs = {}
        for _, ref in ipairs ( self.ap_refs ) do
            node_refs [ #node_refs + 1 ] = ref
        end
        for _, ref in ipairs ( self.sta_refs ) do
            node_refs [ #node_refs + 1 ] = ref
        end
        self.node_refs = node_refs
    else
        -- randomize mesh nodes
        local nodes = self:list_nodes ()
        local nodes_random = misc.randomize_list ( nodes )
        local node_refs = {}
        for _, name in ipairs ( nodes_random ) do
            local node_ref = self:find_node_ref ( name )
            node_refs [ #node_refs + 1 ] = node_ref
        end
        self.node_refs = node_refs
    end
    -- randomized associated stations
    for _, ap_ref in ipairs ( self.ap_refs ) do
        ap_ref:randomize_stations ()
    end
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

function ControlNode:get_mac_br ( node_name )
    local node_ref = self:find_node_ref ( node_name )
    if ( node_ref == nil ) then return nil end
    return node_ref:get_mac_br ()
end

function ControlNode:get_opposite_macs ( node_name )
    local node_ref = self:find_node_ref ( node_name )
    if ( node_ref == nil ) then return nil end
    return node_ref:get_opposite_macs ()
end

function ControlNode:get_opposite_macs_br ( node_name )
    local node_ref = self:find_node_ref ( node_name )
    if ( node_ref == nil ) then return nil end
    return node_ref:get_opposite_macs_br ()
end

function ControlNode:list_phys ( name )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
        if ( node_ref == nil ) then return {} end
        return node_ref.rpc.phy_devices ()
    else
        return { "phy0" }
    end
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
    self:send_info ( "link " .. (name or "none" ) .. " to ssid " .. ( ssid or "none" ) )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref ~= nil ) then
        self:send_info ( "link node " .. (node_ref.name or "none" )  .. " to ssid " .. ( ssid or "none" ) )
        node_ref:link_to_ssid ( ssid, node_ref.wifi_cur )
    end
end

function ControlNode:get_ssid ( name )
    self:send_info ( "get ssid " .. (name or "none" ) )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
        if ( node_ref ~= nil ) then
            self:send_info ( "get ssid from node_ref " .. ( node_ref.name or "none" ) )
            return node_ref.rpc.get_ssid ( node_ref.wifi_cur )
        else
            self:send_error ( "get ssid from node_ref " .. ( node_ref.name or "none" ) .. "failed. Not found" )
        end
    end
    return nil
end

function ControlNode:add_station ( ap, sta )
    local ap_ref = self:find_node_ref ( ap )
    local sta_ref = self:find_node_ref ( sta )
    if ( ap_ref == nil or sta_ref == nil ) then return nil end
    if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
        local mac = sta_ref.rpc.get_mac ( sta_ref.wifi_cur )
        ap_ref:add_station ( mac, sta_ref )
        sta_ref:set_ap_ref ( ap_ref )
    else
        self:send_debug ( sta_ref.macs [ "phy0" ] )
        if ( sta_ref.macs [ "phy0" ] ~= nil ) then
            ap_ref:add_station ( sta_ref.macs [ "phy0" ], sta_ref )
            sta_ref:set_ap_ref ( ap_ref )
            local addr = ap_ref.rpc.has_lease ( sta_ref.macs [ "phy0" ] )
            if ( addr ~= nil ) then
                sta_ref.addrs [ "phy0" ] = addr
            end
        end
    end
end

function ControlNode:list_stations ( ap )
    local ap_ref = self:find_node_ref ( ap )
    if ( ap_ref ~= nil ) then
        self:send_debug ( "send stations: " .. table_tostring ( ap_ref.stations ) )
        return ap_ref.stations or {}
    end
    return {}
end

function ControlNode:set_ani ( name, ani )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
        node_ref.rpc.set_ani ( node_ref.wifi_cur, ani )
    end
end

function ControlNode:set_ldpc ( name, enabled )
    local node_ref = self:find_node_ref ( name )
    if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
        node_ref.rpc.set_ldpc ( node_ref.wifi_cur, enabled )
    end
end

function ControlNode:find_node_ref( name ) 
    for _, node in ipairs ( self.node_refs ) do 
        if ( node.name == name ) then return node end
    end
    return nil
end

function ControlNode:set_nameservers ( nameserver )
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            node_ref:set_nameserver ( nameserver )
        end
    end
end

function ControlNode:check_bridges ()
    local no_bridges = true
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            local bridge_name = node_ref:check_bridge ( node_ref.ctrl_net_ref.phy )
            if ( bridge_name == nil ) then
                self:send_info ( node_ref.name .. " has no bridged setup" )
            end
            no_bridges = no_bridges and bridge_name == nil
        end
    end
    if ( no_bridges == false ) then
        self:send_warning ( "One or more nodes have a bridged setup" )
    end
    return no_bridges
end

function ControlNode:reachable ()
    local reached = {}
    self:send_debug ( "reachable " .. #self.node_refs .. " nodes" )
    for _, node_ref in ipairs ( self.node_refs ) do
        self:send_debug ( node_ref:__tostring() )
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            local addrs = {}
            local addr, rest = parse_ipv4 ( node_ref.name )
            if ( addr == nil ) then
                -- name is a hostname and no ip addr
                dig, _ = net.lookup ( node_ref.name )
                if ( dig ~= nil and dig.addr ~= nil and table_size ( dig.addr ) > 0 ) then
                    addrs = dig.addr
                end
            else
                addrs = { addr }
            end
            if ( table_size ( addrs ) == 0 ) then
                break
            end
            for _, addr in ipairs ( addrs ) do
                node_ref.ctrl_net_ref.addr = addr
                if ( net.ip_reachable ( addr ) ) then
                    reached [ node_ref.name ] = true
                    break
                else
                    reached [ node_ref.name ] = false
                end
            end
        end
    end
    return reached
end

function ControlNode:hosts_known ()
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            if ( self:host_known ( node_ref.name ) == false ) then
                return false
            end
        end
    end
    return true
end

function ControlNode:start_nodes ( rsa_key, distance )

    function start_node ( node_ref, log_addr, log_port )

        local remote_cmd = node_ref.lua_bin .. " /usr/bin/runNode"
                    .. " --name " .. node_ref.name 
                    .. " --ctrl_if " .. node_ref.ctrl_net_ref.iface
                    .. " --port " .. self.port 
                    .. " --retries " .. self.retries

        if ( log_addr ~= nil ) then
            remote_cmd = remote_cmd .. " --log_ip " .. log_addr 
        end
        if ( log_port ~= nil ) then
            remote_cmd = remote_cmd .. " --log_port " .. log_port
        end
        local ssh_command = { "ssh" }
        if ( rsa_key ~= nil ) then
            ssh_command [ #ssh_command + 1 ] = "-i"
            ssh_command [ #ssh_command + 1 ] = rsa_key
        end
        ssh_command [ #ssh_command + 1 ]  = "root@" .. ( node_ref.ctrl_net_ref.addr or "none" )
        ssh_command [ #ssh_command + 1 ] = remote_cmd
        self:send_info ( table_tostring ( ssh_command ) )
        local pid, _, _ = misc.spawn ( unpack ( ssh_command ) )
        return pid
    end
    self:send_debug ( "exeriment approximate distance: " .. ( distance or "not specified" ) )

    self:send_debug ( "start " .. #self.node_refs .. " nodes" )
    for _, node_ref in ipairs ( self.node_refs ) do
        self:send_debug ( node_ref:__tostring() )
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            self.pids [ node_ref.name ] = start_node ( node_ref, self.log_addr, self.log_port )
        end
    end
    return true
end

function ControlNode:connect_nodes ( ctrl_port )
    
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref:connect ( ctrl_port, function ( msg ) self:send_error ( msg ) end ) == false ) then
            return false
        end
    end

    -- query lua pid before closing rpc connection
    -- maybe to kill nodes later
    for _, node_ref in ipairs ( self.node_refs ) do 
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            if ( node_ref.rpc == nil ) then return false end
            self.pids [ node_ref.name ] = node_ref.rpc.get_pid ()
        end
    end

    return true
end

function ControlNode:disconnect_nodes ()
    for _, node_ref in ipairs ( self.node_refs ) do 
        node_ref:disconnect ()
    end
end

-- kill all running nodes with two times sigint(2)
-- (default kill signal is sigterm(15) )
function ControlNode:stop ( rsa_key )
    -- fixme: nodes should implement a stop function and kill itself with getpid
    -- and wait
    for i, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.rpc ~= nil and ( node_ref.is_passive == nil or node_ref.is_passive == false ) ) then
            self:send_info ( "stop node at " .. node_ref.ctrl_net_ref.addr .. " with pid " .. self.pids [ node_ref.name ] )
            local ssh
            local exit_code
            local remote_cmd = node_ref.lua_bin .. " /usr/bin/kill_remote " .. self.pids [ node_ref.name ] .. " --INT -i 2"
            self:send_debug ( remote_cmd )
            local ssh_command = { "ssh" }
            if ( rsa_key ~= nil ) then
                ssh_command [ #ssh_command + 1 ] = "-i"
                ssh_command [ #ssh_command + 1 ] = rsa_key
            end
            ssh_command [ #ssh_command + 1]  = "root@" .. ( node_ref.ctrl_net_ref.addr or "none" )
            ssh_command [ #ssh_command + 1 ] = remote_cmd
            self:send_debug ( table_tostring ( ssh_command ) )
            ssh, exit_code = misc.execute ( unpack ( ssh_command ) )
            if ( exit_code ~= 0 ) then
                self:send_debug ( "send signal -2 to remote pid " .. self.pids [ node_ref.name ] .. " failed" )
            end
        end
    end
end

function ControlNode:init_experiments ( command, args, ap_names, is_fixed )

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
    -- fixme: MESH
    self.keys = {}
    for i, ap_ref in ipairs ( self.ap_refs ) do
        self.keys[i] = self.exp:keys ( ap_ref )
    end
    return true
end

-- fixme: MESH
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

-- fixme: MESH
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

function ControlNode:get_tcpdump_size ( ref_name, key )
    self:send_info ( "*** Send tcpdump pcaps size from nodes for " .. ( ref_name or "unset" ) .. ". ***" )
    local node_ref = self:find_node_ref ( ref_name )
    if ( key == nil ) then
        return nil
    else
        --if ( node_ref.stats.tcpdump_pcaps [ key ] ) then
        --    return string.len ( node_ref.stats.tcpdump_pcaps [ key ] )
        if ( node_ref.stats.tcpdump_meas [ key ].stats ) then
            return string.len ( node_ref.stats.tcpdump_meas [ key ].stats )
        else
            return 0
        end
    end
end

function ControlNode:get_tcpdump_pcap ( ref_name, key, offset, count )
    self:send_info ( "*** Copy tcpdump pcap for key " .. ( key or nil ) 
                     .. " from nodes for " .. ( ref_name or "unset" ) .. ". ***" )
    --self:send_debug ( tostring ( collectgarbage ( "count" ) ) .. " kB" )
    local node_ref = self:find_node_ref ( ref_name )
    if ( node_ref == nil ) then
        self:send_debug ( "tcpdump pcaps copied: 0 bytes" )
        return false, "ControlNode:get_tcpdump_pcap failed: node_ref not found"
    end
    local out = nil
    if ( offset ~= nil and count ~= nil ) then
        local succ, res = node_ref:get_tcpdump_pcap ( key, offset, offset + count + 1 )
        if ( succ == false ) then
            return false, "ControlNode:get_tcpdump_pcap failed: " .. ( res or "unknown" )
        end
        out = res
    else
        local succ, res = node_ref:get_tcpdump_pcap ( key )
        if ( succ == false ) then
            return false, "ControlNode:get_tcpdump_pcap failed: " .. ( res or "unknown" )
        end
        out = res
    end
    self:send_debug ( "tcpdump pcaps copied: " .. string.len ( out ) .. " bytes" )
    return true, out
end

function ControlNode:get_rc_stats ( ref_name, station, key )
    self:send_info ( "*** Copy rc_stats from nodes for " .. ( ref_name or "unset" )
                        .. ", station " .. ( station or "none" )
                        .. ", key " .. ( key or "none" ) .. ". ***" )
    local out = nil
    local node_ref = self:find_node_ref ( ref_name )
    if ( node_ref == nil ) then
        return out
    end
    out = node_ref.stats.rc_stats_meas [ station ] [ key ].stats
    node_ref.stats.rc_stats_meas [ station ] [ key ].stats = ""
    --out = node_ref.stats.rc_stats [ station ] [ key ]
    --node_ref.stats.rc_stats [ station ] [ key ] = ""
    self:send_debug ( "rc stats copied: " .. string.len ( out ) )
    return out
end

function ControlNode:get_cpusage_stats ( ref_name, key )
    self:send_info ( "*** Copy cpusage_stats from nodes for " .. ( ref_name or "unset" )
                        .. " and key " .. ( key or "none" ) .. ". ***" )
    local out = nil
    local node_ref = self:find_node_ref ( ref_name )
    if ( node_ref == nil ) then
        return out
    end
    out = node_ref.stats.cpusage_meas [ key ].stats
    node_ref.stats.cpusage_meas [ key ].stats = ""
    --out = node_ref.stats.cpusage_stats [ key ]
    --node_ref.stats.cpusage_stats [ key ] = ""
    self:send_debug ( "cpusage stats copied and removed" )
    return out
end

function ControlNode:get_regmon_stats ( ref_name, key )
    self:send_info ( "*** Copy regmon_stats from nodes for " .. ( ref_name or "unset" )
                        .. " and key " .. ( key or "none" ) .. ". ***" )
    local out = nil
    local node_ref = self:find_node_ref ( ref_name )
    if ( node_ref == nil ) then
        return out
    end
    --out = node_ref.stats.regmon_stats [ key ]
    --node_ref.stats.regmon_stats [ key ] = ""
    out = node_ref.stats.regmon_meas [ key ].stats
    node_ref.stats.regmon_meas [ key ].stats = ""
    self:send_debug ( "regmon stats copied and removed" )
    return out
end

function ControlNode:get_iperf_s_out ( ref_name )
    self:send_info ( "*** Copy iperf server output from nodes for " .. ( ref_name or "unset" ) .. ". ***" )
    local out = {}
    local node_ref = self:find_node_ref ( ref_name )
    if ( node_ref == nil ) then
        return out
    end
    out = copy_map ( node_ref.stats.iperf_s_out )
    node_ref.stats.iperf_s_out = {}
    self:send_debug ( "iperf server out copied" )
    return out
end

function ControlNode:get_iperf_c_out ( ref_name )
    self:send_info ( "*** Copy iperf client output from nodes for " .. ( ref_name or "unset" ) .. ". ***" )
    local out = {}
    local node_ref = self:find_node_ref ( ref_name )
    if ( node_ref == nil ) then
        return out
    end
    out = copy_map ( node_ref.stats.iperf_c_out )
    node_ref.stats.iperf_c_out = {}
    self:send_debug ( "iperf client out copied" )
    return out
end

function ControlNode:get_dmesg ( ref_name )
    self:send_info ( "*** Copy stats from nodes for " .. ( ref_name or "unset" ) .. ". ***" )
    local node_ref = self:find_node_ref ( ref_name )
    return node_ref.rpc.get_dmesg ()
end

-- runs experiment 'exp' for all nodes 'ap_refs'
-- in parallel
function ControlNode:init_experiment ( command, args, ap_names, is_fixed, key, number, count, channel, htmode )

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

    if ( self.online ~= nil ) then
        self:send_info ( "fetch online: " .. tostring ( self.online )  )
    end
    -- fixme: MESH
    self:send_info ("*** Prepare measurement ***")
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:prepare_measurement ( ap_ref, self.online )
    end

    self:send_info ("*** Settle measurement ***")

    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do

        -- set channel and ht
        ap_ref.rpc.set_channel_htmode ( ap_ref.wifi_cur, channel, htmode )

        -- self:send_debug ( ap_ref:__tostring() )
        -- for _, station in ipairs ( ap_ref.rpc.visible_stations( ap_ref.wifi_cur ) ) do
        --     self:send_debug ( "station: " .. station )
        -- end
        local status, err = self.exp:settle_measurement ( ap_ref, key )
        if ( status == false ) then
            local msg = "experiment aborted, settledment failed."
            msg = msg .. " please check the wifi connnections of " .. ( ap_ref.name or "none" ) .. "."
            self:send_error ( msg )
            return false, msg
        end
        -- for _, station in ipairs ( ap_ref.rpc.visible_stations( ap_ref.wifi_cur ) ) do
        --     self:send_debug ( "station: " .. station )
        -- end

        -- fixme: MESH
        local rate_names = ap_ref.rpc.tx_rate_names ( ap_ref.wifi_cur, ap_ref.stations [1] )
        local msg = "rate names: "
        self:send_debug ( msg .. table_tostring ( rate_names, 80 - string.len ( msg ) ) )

        -- fixme: MESH
        local rates = ap_ref.rpc.tx_rate_indices ( ap_ref.wifi_cur, ap_ref.stations [1] )
        local msg = "rate indices: "
        self:send_debug ( msg .. table_tostring ( rates, 80 - string.len ( msg ) ) )

        -- fixme: MESH
        local powers = ap_ref.rpc.tx_power_indices ( ap_ref.wifi_cur, ap_ref.stations [1] )
        local msg = "power indices: "
        self:send_debug ( msg .. table_tostring ( powers, 80 - string.len ( msg ) ) )

        local iw_info = ap_ref.rpc.get_iw_info ( ap_ref.wifi_cur )
        local msg = "iw info: "
        self:send_info ( msg .. ( iw_info or "none" ), 80 - string.len ( msg ) )

        -- fixme: MESH
        for i, sta_ref in ipairs ( ap_ref.refs ) do

            sta_ref.rpc.set_channel_htmode ( sta_ref.wifi_cur, channel, htmode )

            if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then

                local iw_link = sta_ref.rpc.get_iw_link ( sta_ref.wifi_cur )
                local msg = "iw link: "
                -- fixme: should return string, not table value
                self:send_info ( msg .. ( iw_link or "none" ), 80 - string.len ( msg ) )
                
                local rate_name = sta_ref.rpc.get_linked_rate_idx ( sta_ref.wifi_cur )
                if ( rate_name ~= nil ) then
                    local rate_idx = find_rate ( rate_name, rate_names, rates )
                    self:send_debug ( " rate_idx: " .. ( rate_idx or "unset" ) )
                end

                local signal = sta_ref.rpc.get_linked_signal ( sta_ref.wifi_cur )
            end
        end

    end

    self:send_info ( "Waiting one extra second for initialised debugfs" )
    posix.sleep (1)

    self:send_info ("*** Start Measurements ***" )

    -- -------------------------------------------------------
    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do
         self.exp:start_measurement ( ap_ref, key )
    end

    -- -------------------------------------------------------
    -- Experiment
    -- -------------------------------------------------------

    self:send_info ("*** Start Experiment ***" )
    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do
         self.exp:start_experiment ( ap_ref, key )
    end

    self.running = true
    return true, nil
end

function ControlNode:exp_has_data ()
    self:send_info ( "Experiment running: " .. tostring ( self.running ) )
    return self.running, nil
end

function ControlNode:exp_next_data ( key )
    self.running = false
    self:send_info ("*** Fetch Measurements ***" )
    -- fixme: MESH
    for i, ap_ref in ipairs ( self.ap_refs ) do
        --self:send_debug ( tostring ( collectgarbage ( "count" ) ) .. " kB" )
        local succ, res = self.exp:fetch_measurement ( ap_ref, key )
        if ( succ == false ) then
            return false, "ControlNode:exp_next_data failed: " .. ( res or "unknown" )
        end
        local has_content = res
        self:send_debug ( "experiments has_content: " .. tostring ( has_content ) )
        self.running = self.running or ap_ref:is_exp_running ()
        self:send_debug ( "experiments running: " .. tostring ( self.running ) )
        --collectgarbage ()
        --self:send_debug ( tostring ( collectgarbage ( "count" ) ) .. " kB" )
    end
    return true, nil
end

function ControlNode:finish_experiment ( key )
    self:send_info ("*** Wait Experiment ***" )
    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:wait_experiment ( ap_ref, key )
    end

    -- -------------------------------------------------------

    self:send_info ("*** Stop Measurements ***" )
    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:stop_measurement ( ap_ref, key )
    end
    self.running = false

    self:send_info ("*** Fetch Measurements ***" )
    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do
        --self:send_debug ( tostring ( collectgarbage ( "count" ) ) .. " kB" )
        local succ, res = self.exp:fetch_measurement ( ap_ref, key )
        if ( succ == false ) then
            return false, "ControlNode:exp_next_data failed: " .. ( res or "unknown" )
        end
        local has_content = res
        self:send_debug ( "experiments has_content: " .. tostring ( has_content ) )
        --collectgarbage ()
        --self:send_debug ( tostring ( collectgarbage ( "count" ) ) .. " kB" )
    end

    self:send_info ("*** Unsettle measurement ***" )
    -- fixme: MESH
    for _, ap_ref in ipairs ( self.ap_refs ) do
        self.exp:unsettle_measurement ( ap_ref, key )
    end

    return true, nil
end

-- -------------------------
-- Hardware
-- -------------------------

function ControlNode:get_boards ()
    local map = {}
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            local board = node_ref:get_board ()
            map [ node_ref.name ] = board
        end
    end
    return map
end

function ControlNode:get_os_releases ()
    local map = {}
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
            local os_release = node_ref:get_os_release ()
            map [ node_ref.name ] = os_release
        end
    end
    return map
end

-- -------------------------
-- date
-- -------------------------

function ControlNode:set_dates ()
    local time = os.date( "*t", os.time() )
    for _, node_ref in ipairs ( self.node_refs ) do
        if ( node_ref.is_passive == nil or node_ref.is_passive == false ) then
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
end
