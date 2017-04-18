
-- TODO: extend lpc with stderr
-- TODO: extract wifi functionss into new class
--          rpc.wifi [ self.cur_wifi ].set_ssid ( ssid )
--       to support multiple radios

require ('NodeBase')

require ('WifiIF')
local misc = require ('misc')
local uci = require ('Uci')
local net = require ('Net')
local posix = require ('posix') -- sleep

require ('lpc')

require ('parsers/iw_link')
require ('parsers/ifconfig')
require ('parsers/dhcp_lease')
require ('parsers/rc_stats_csv')
require ('parsers/iw_info')

local lease_fname = "/tmp/dhcp.leases"
local debugfs = "/sys/kernel/debug/ieee80211"

Node = NodeBase:new()

function Node:create ( name, ctrl, port, log_port, log_addr )
    if ( name == nil) then
        error ( "A Node needs to have a name set, but it isn't!" )
    end
    local o = Node:new ( { name = name
                         , ctrl = ctrl
                         , port = port
                         , log_addr = log_addr
                         , log_port = log_port 
                         , wifis = {}
                         } )

    self:get_proc_version ()
    local phys, err = net.list_phys ()
    if ( phys == nil or table_size ( phys ) == 0 ) then
        o:send_error ( err )
        return o
    end
    if ( ctrl ~= nil and ctrl.addr == nil ) then
        ctrl:get_addr ( )
    end
    for i, phy in ipairs ( phys ) do
        local netif = WifiIF:create ()
        netif.node = o
        netif.phy = phy
        netif.mon = "mon" .. tostring ( i - 1 )
        netif.iface, _ = net.get_interface_name ( phy )
        if ( netif.iface == nil ) then
            o:send_warning ( "Cannot determine radio interface name. radio is disabled, enabling" )
            o:enable_wifi ( true, phy )
            o:restart_wifi ( phy )
            posix.sleep (3)
            netif.iface, msg = net.get_interface_name ( phy )
            if ( netif.iface == nil ) then
                o:send_error ( "Empty ieee80211 debugfs: please check permissions and kernel config, i.e. ATH9K_DEBUGFS: " .. msg )
                return nil
            else
                netif.addr, msg = net.get_addr ( netif.iface )
                o.wifis [ phy ] = netif
            end
        else
            netif.addr, msg = net.get_addr ( netif.iface )
            o.wifis [ phy ] = netif
        end
    end
    return o
end

function Node:enable_wifi ( enabled, phy )
    if ( phy == nil ) then return false end
    if ( enabled == nil ) then enabled = false end
    if ( self.proc_version.system == "LEDE" ) then
        local value = 1
        if ( enabled == true ) then 
            value = 0
        else
            value = 1
        end
        local var = "wireless.radio"
        var = var .. string.sub ( phy, 4, string.len ( phy ) )
        var = var .. ".disabled"
        self:send_debug ( " enable wifi: " .. var .. " = " .. tostring ( not enabled ) )
        local _, exit_code = uci.set_var ( var, value )
        local var = "wireless.default_radio"
        var = var .. string.sub ( phy, 4, string.len ( phy ) )
        var = var .. ".disabled"
        self:send_debug ( " enable wifi: " .. var .. " = " .. tostring ( not enabled ) )
        local _, exit_code = uci.set_var ( var, value )
        return ( exit_code == 0 )
    end
    return true
end

function Node:restart_wifi ( phy )
    if ( phy == nil ) then return nil end
    self:send_debug ("restart wifi" )
    if ( self.proc_version.system == "LEDE" ) then
        local wifi, err = misc.execute ( "/sbin/wifi" )
        self:send_info( "restart wifi done: " .. wifi )
        return true
    elseif ( self.proc_version.system == "Gentoo" ) then
        local init_script = "/etc/init.d/net." .. self.iface
        if ( isFile ( init_script ) ) then
            local wifi, err = misc.execute ( init_script, "restart")
            self:send_info( "restart wifi done (" .. ( self.iface or "none" ) .. "): " .. ( wifi or "none" ) )
            return ( err == 0 )
        end
        self:send_debug ( "Cannot restart wifi. No init script found for phy " .. ( self.phy or "none" ) )
        return false
    end
    return false
end

function Node:__tostring() 
    local name = "none"
    if ( self.name ~= nil ) then
        name = self.name
    end
    local out = name .. "\n"
                .. self.ctrl:__tostring ()
                .. "\n"
    local i = 1
    for _, wifi in pairs ( self.wifis ) do
        if ( i ~= 1 ) then
            out = out .. ", "
        end
        out = out .. wifi:__tostring ()
        i = i + 1
    end
    return out
end

function Node:get_ctrl_addr ()
    self:send_info ( "send ipv4 addr of control interface " .. self.ctrl.iface )
    return self.ctrl.addr 
end

function Node:get_regmon_rate ()
    if ( self.proc_version.system == "LEDE" ) then
        local var = "regmon.regmon.samplingrate"
        return tonumber ( uci.get_var ( var ) )
    else
        return 500000000
    end
end

-- --------------------------
-- wifi
-- --------------------------

function Node:phy_devices ()
    self:send_info( "Send phy devices." )
    local phys = {}
    for phy, _ in pairs ( self.wifis ) do
        phys [ #phys + 1 ] = phy
    end
    self:send_info (" phys: " .. table_tostring ( phys ) )
    return phys
end

function Node:find_wifi_device ( phy )
    if ( phy == nil ) then
        self:send_error ( "phy argument is not set" )
        return nil
    end
    local dev = self.wifis [ phy ]
    if ( dev == nil ) then
        self:send_error ( "device not found" )
    end
    return dev
end

function Node:get_iw_info ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_iw_info ()
    end
    return nil
end

function Node:get_ssid ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_ssid ()
    end
    return nil
end

function Node:add_monitor ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        dev:add_monitor ()
    end
end

function Node:remove_monitor ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        dev:remove_monitor ()
    end
end

function Node:list_stations ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:list_stations ()
    end
    return {}
end

function Node:visible_stations ( phy )
    local list = self:list_stations ( phy )
    self:send_info ( "Send stations for " .. ( phy or "none" ) .. ": " .. table_tostring ( list ) )
    return list
end

function Node:set_ani ( phy, enabled )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        dev:set_ani ( enabled )
    end
end

function Node:get_mac ( phy, bridged )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_mac ( bridged )
    end
    return nil
end

function Node:get_iface ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev.iface
    end
    return nil
end

function Node:get_mon ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev.mon
    end
    return nil
end

function Node:get_addr ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        self:send_info ( "send ipv4 addr for " .. dev.iface )
        if ( dev.addr == nil ) then
            self:send_error ( " interface " .. dev.iface .. " has no ipv4 addr assigned" )
            return nil 
        else
            self:send_info ( " addr for " .. dev.iface .. ": " .. dev.addr )
            return dev.addr
        end
    end
    return nil
end

-- returns addr when host with mac has a dhcp lease else nil
function Node:has_lease ( mac )
    self:send_info ("send ipv4 addr for " .. ( mac or "none" ) .. " from lease" )
    local file = io.open ( lease_fname )
    if ( not isFile ( lease_fname ) ) then return nil end
    local content = file:read ("*a")
    for _, line in ipairs ( split ( content, '\n' ) ) do
        local lease = parse_dhcp_lease ( line )
        if ( lease ~= nil and lease.mac == mac ) then
            file:close()
            return lease.addr
        end
    end
    file:close()
    return nil
end

function Node:link_to_ssid ( ssid, phy )
    uci_link_to_ssid ( ssid, phy )
end

function Node:get_iw_link ( phy, parse )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_iw_link ( parse )
    end
    return nil
end

-- returns the ssid when iface is connected
-- otherwise nil is returned
function Node:get_linked_ssid ( phy )
    self:send_info ( "Get linked ssid for device " .. ( phy or "none" ) )
    local iwlink = self:get_iw_link ( phy, true )
    if ( iwlink == nil or iwlink.ssid == nil ) then return nil end
    self:send_info ( " linked ssid: " .. iwlink.ssid )
    return iwlink.ssid
end

-- returns the remote iface when iface is connected
-- otherwise nil is returned
function Node:get_linked_iface ( phy )
    self:send_info ( "Get linked interface for device " .. ( phy or "none" ) )
    local iwlink = self:get_iw_link ( phy, true )
    if ( iwlink == nil or iwlink.iface == nil ) then return nil end
    self:send_info ( " linked iface: " .. iwlink.iface )
    return iwlink.iface
end

-- returns the remote mac when iface is connected
-- otherwise nil is returned
function Node:get_linked_mac ( phy )
    self:send_info ( "Get linked mac for device " .. ( phy or "none" ) )
    local iwlink = self:get_iw_link ( phy, true )
    if ( iwlink == nil or iwlink.mac == nil) then return nil end
    self:send_info ( " linked mac: " .. iwlink.mac )
    return iwlink.mac
end

-- returns the signal when iface is connected
-- otherwise nil is returned
function Node:get_linked_signal ( phy )
    self:send_info ( "Get linked signal for device " .. ( phy or "none" ) )
    local iwlink = self:get_iw_link ( phy, true )
    if ( iwlink == nil or iwlink.signal == nil ) then return nil end
    self:send_info ( " linked signal: " .. iwlink.signal )
    return iwlink.signal
end

-- returns the rate index when iface is connected
-- otherwise nil is returned
function Node:get_linked_rate_idx ( phy )
    self:send_info ( "Get linked rate index for device " .. ( phy or "none" ) )
    local iwlink = self:get_iw_link ( phy, true )
    if ( iwlink == nil or ( iwlink.rate_idx == nil and iwlink.rate == nil ) ) then return nil end
    self:send_info ( " linked rate index: " .. ( iwlink.rate_idx or iwlink.rate ) )
    return ( iwlink.rate_idx or iwlink.rate )
end

function Node:check_bridge ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:check_bridge ()
    end
    return nil
end

-- --------------------------
-- Fixed Settings
-- --------------------------

function Node:get_rc_stats_lines ( phy, station )
    if ( phy == nil ) then
        self:send_error ( "cannot get rc_stats. phy is unset" )
        return {}
    end
    if ( station == nil ) then
        self:send_error ( "cannot get rc_stats. station is unset" )
        return {}
    end
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        local fname = debugfs .. "/" .. dev.phy .. "/netdev:" .. dev.iface .. "/stations/" .. station .. "/rc_stats_csv"
        local lines = {}
        local file = nil
        if ( fname ~= nil ) then
            file = io.open ( fname )
        end
        if ( file ~= nil ) then
            local content = file:read ("*a")
            for i, line in ipairs ( split ( content, "\n" ) ) do
                if ( line ~= ""
                        and string.sub ( line, 1, 5 ) ~= "Total"
                        and string.sub ( line, 1, 7 ) ~= "Average"
                        and string.sub ( line, 1, 18 ) ~= "              best"
                        and string.sub ( line, 1, 4 ) ~= "mode"
                   ) then
                    lines [ #lines + 1 ] = parse_rc_stats_csv ( line )
                end
            end
        end
        return lines
    end
    return {}
end

-- read rc_stats and collects rate names
function Node:tx_rate_names ( phy, station )
    self:send_info ( "List tx rate names for station " .. ( station or "none" ) .. " at device " .. ( phy or "none" ) )
    local lines = self:get_rc_stats_lines ( phy, station )
    local names = {}
    for _, rc_line in ipairs ( lines ) do
        names [ #names + 1 ] = rc_line.rate.name
    end
    return names
end

-- reads rc_stats and collects rate indices
function Node:tx_rate_indices ( phy, station )
    self:send_info ( "List tx rate indices for station " .. ( station or "none" ) .. " at device " .. ( phy or "none" ) )
    local lines = self:get_rc_stats_lines ( phy, station )
    local rates = {}
    for _, rc_line in ipairs ( lines ) do
        rates [ #rates + 1 ] = rc_line.rate.idx
    end
    return rates
end

-- fixme: tx_power_levels ( per rate )
function Node:tx_power_indices ( phy, station )
    if ( phy == nil ) then return nil end
    tx_powers = {}
    for i = 1, 25 do
        tx_powers[i] = i
    end
    return tx_powers
end

function Node:write_value_to_sta_debugfs ( fname, value )
    if ( isFile ( fname ) == false ) then
        self:send_error ( "file doesn't exists: " .. fname )
    end
    local file = nil
    if ( fname ~= nil ) then
        file = io.open ( fname, "w" )
    end
    if ( file ~= nil ) then
        file:write ( tostring ( value ) )
        file:flush()
        file:close()
        return true
    end
    return false
end

function Node:read_value_from_sta_debugfs ( fname )
    if ( isFile ( fname ) == false ) then
        self:send_error ( "file doesn't exists: " .. fname )
    end
    local file = nil
    if ( fname ~= nil ) then
        file = io.open ( fname, "r" )
    end
    local value
    if ( file ~= nil ) then
        local content = file:read ("*a")
        value = tonumber ( content )
        file:close ()
    end
    return value
end

-- set the power level by index (i.e. 25 is the index of the highest power level, sometimes 50)
-- usally two different power levels differs by a multiple of 1mW (25 levels) or 0.5mW (50 power levels)
function Node:set_tx_power ( phy, station, tx_power )
    if ( phy == nil ) then return nil end
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .."/netdev:" .. iface .. "/stations/" .. station .. "/fixed_txpower"
    self:send_info ( "Set tx power level for station " .. station .. " at device " .. phy .. " to " .. tx_power )
    if ( self:write_value_to_sta_debugfs ( fname, tx_power ) == false ) then
        self:send_error ( "Set tx power level for station " .. station .. " at device " .. phy .. " failed. Unsupported" )
    end
end

function Node:get_tx_power ( phy, station )
    if ( phy == nil ) then return nil end
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .."/netdev:" .. iface .. "/stations/" .. station .. "/fixed_txpower"
    self:send_info ( "Get tx power level for station " .. station .. " from device " .. phy )
    local level = self:read_value_from_sta_debugfs ( fname )
    if ( level ~= nil ) then
        self:send_info(" tx power level for station " .. station .. " at device " .. phy .. " is " .. level)
    else
        self:send_error ( "Get tx power level for station " .. station .. " from device " .. phy .. " failed. Unsupported" )
    end
    return level
end

-- /etc/config/wireless: add  option txpower '20' to config wifi-device 'radio{0,1}' section
-- needs restart_wifi ("/sbin/wifi;") call after
function Node:set_global_tx_power ( phy, tx_power )
    if ( phy == nil ) then return nil end
    local var = "wireless.radio"
    var = var .. string.sub ( phy, 4, string.len ( phy ) )
    var = var .. ".txpower"
    local _, exit_code = uci.set_var ( var, tx_power )
end

-- /etc/config/wireless: add  option txpower '20' to config wifi-device 'radio{0,1}' section
function Node:get_global_tx_power ( phy )
    if ( phy == nil ) then return nil end
    local var = "wireless.radio"
    var = var .. string.sub ( phy, 4, string.len ( phy ) )
    var = var .. ".txpower"
    local value = uci.get_var ( var )
    if ( value ~= nil ) then
        self:send_info(" global tx power level at device " .. phy .. " is " .. value, type ( value ) )
        return tonumber ( value )
    else
        self:send_error ( "Get global tx power level from device " .. phy .. " failed. Unsupported" )
        return nil
    end
end

function Node:set_tx_rate ( phy, station, tx_rate_idx )
    if ( phy == nil ) then return nil end
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .."/netdev:" .. iface .. "/stations/" .. station .. "/fixed_txrate"
    self:send_info ( "Set tx rate index for station " .. ( station or "none" )
                                                      .. " at device " .. ( phy or "none" )
                                                      .. " to " .. ( tx_rate_idx or "none" ) )
    if ( self:write_value_to_sta_debugfs ( fname, tx_rate_idx ) == false ) then
        self:send_error ( "Set tx rate level for station " .. station .. " at device " .. phy .. " failed. Unsupported" )
    end
end

function Node:get_tx_rate ( phy, station )
    if ( phy == nil ) then return nil end
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .."/netdev:" .. iface .. "/stations/" .. station .. "/fixed_txrate"
    self:send_info ( "Get tx rate index for station " .. station .. " from device " .. phy )
    local rate = self:read_value_from_sta_debugfs ( fname )
    if ( rate ~= nil ) then
        self:send_info(" tx rate index for station " .. station .. " at device " .. phy .. " is " .. rate)
    else
        self:send_error ( "Get tx rate index for station " .. station .. " from device " .. phy .. " failed. Unsupported" )
    end
    return rate
end

-- /sys/kernel/debug/ieee80211/phy0/rc/fixed_rate_idx
function Node:set_global_tx_rate ( phy, tx_rate_idx )
    if ( phy == nil ) then return nil end
    local fname = debugfs .. "/" .. phy .."/rc/fixed_rate_idx"
    self:send_info ( "Set global tx rate index at device " .. ( phy or "none" )
                                                      .. " to " .. ( tx_rate_idx or "none" ) )
    if ( self:write_value_to_sta_debugfs ( fname, tx_rate_idx ) == false ) then
        self:send_error ( "Set global tx rate level at device " .. phy .. " failed. Unsupported" )
    end
end

-- /sys/kernel/debug/ieee80211/phy0/rc/fixed_rate_idx
function Node:get_global_tx_rate ( phy )
    if ( phy == nil ) then return nil end
    local fname = debugfs .. "/" .. phy .."/rc/fixed_rate_idx"
    self:send_info ( "Get global tx rate index from device " .. phy )
    local rate = self:read_value_from_sta_debugfs ( fname )
    if ( rate ~= nil ) then
        self:send_info(" global tx rate index at device " .. phy .. " is " .. rate)
    else
        self:send_error ( "Get global tx rate index from device " .. phy .. " failed. Unsupported" )
    end
    return rate
end

-- --------------------------
-- rc_stats
-- --------------------------

function Node:start_rc_stats ( phy, station )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:start_rc_stats ( station )
    end
    return nil
end

function Node:get_rc_stats ( phy, station )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_rc_stats ( station )
    end
    return nil
end

function Node:stop_rc_stats ( phy, station )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:stop_rc_stats ( station )
    end
    return nil
end

-- --------------------------
-- regmon stats
-- --------------------------

function Node:start_regmon_stats ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        local sampling_rate = self:get_regmon_rate ()
        return dev:start_regmon_stats ( sampling_rate )
    end
    return nil
end

function Node:get_regmon_stats ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_regmon_stats ()
    end
    return nil
end

function Node:stop_regmon_stats ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:stop_regmon_stats ()
    end
    return nil
end

-- --------------------------
-- cpusage
-- --------------------------

function Node:start_cpusage ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:start_cpusage ()
    end
    return nil
end

function Node:get_cpusage ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_cpusage ()
    end
    return nil
end

function Node:stop_cpusage ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:stop_cpusage ()
    end
    return nil
end

-- --------------------------
-- tcpdump
-- --------------------------

function Node:start_tcpdump ( phy, fname )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:start_tcpdump ( fname )
    end
    return nil
end

function Node:get_tcpdump_offline ( phy, fname )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:get_tcpdump_offline ( fname )
    end
    return nil
end

function Node:stop_tcpdump ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:stop_tcpdump ()
    end
    return nil
end

-- --------------------------
-- iperf
-- --------------------------

-- fixme: rpc function name to long
function Node:start_tcp_iperf_s ( phy, iperf_port )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:start_tcp_iperf_s ( iperf_port )
    end
    return nil
end

-- fixme: rpc function name to long
function Node:start_udp_iperf_s ( phy, iperf_port )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:start_udp_iperf_s ( iperf_port )
    end
    return nil
end

function Node:run_tcp_iperf ( phy, iperf_port, addr, tcpdata, wait )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:run_tcp_iperf ( iperf_port, addr, tcpdata, wait )
    end
    return nil
end

function Node:run_udp_iperf ( phy, iperf_port, addr, rate, duration, wait )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:run_udp_iperf ( iperf_port, addr, rate, duration, wait )
    end
    return nil
end

function Node:run_multicast ( phy, iperf_port, addr, multicast_addr, ttl, bitrate, duration, wait )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:run_multicast ( iperf_port, addr, multicast_addr, ttl, bitrate, duration, wait )
    end
    return nil
end

function Node:wait_iperf_c ( phy, addr )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:wait_iperf_c ( addr )
    end
    return nil
end

function Node:stop_iperf_server ( phy )
    local dev = self:find_wifi_device ( phy )
    if ( dev ~= nil ) then
        return dev:stop_iperf_server ()
    end
    return nil
end
