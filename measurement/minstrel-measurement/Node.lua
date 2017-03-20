
-- TODO: extend lpc with stderr
-- TODO: extract wifi functionss into new class
--          rpc.wifi [ self.cur_wifi ].set_ssid ( ssid )
--       to support multiple radios

require ('NodeBase')

require ('NetIF')
local misc = require ('misc')
local uci = require ('Uci')
local net = require ('Net')

require ('lpc')

require ('parsers/iw_link')
require ('parsers/ifconfig')
require ('parsers/dhcp_lease')
require ('parsers/rc_stats_csv')
require ('parsers/iw_info')

local lua_bin = "/usr/bin/lua"
local tcpdump_bin = "/usr/sbin/tcpdump"
local cpusage_bin = "/usr/bin/cpusage_single"
local fetch_file_bin = "/usr/bin/fetch_file"
local iperf_bin = "/usr/bin/iperf"

local lease_fname = "/tmp/dhcp.leases"
local debugfs = "/sys/kernel/debug/ieee80211"

Node = NodeBase:new()

function Node:create ( name, ctrl, port, log_port, log_addr, iperf_port )
    local o = Node:new ( { name = name
                         , ctrl = ctrl
                         , port = port
                         , log_addr = log_addr
                         , log_port = log_port 
                         , wifis = {}
                         , iperf_port = iperf_port
                         , tcpdump_proc = nil
                         , cpusage_proc = nil
                         , regmon_proc = nil
                         , rc_stats_procs = {}
                         , iperf_client_procs = {}
                         , iperf_server_procs = {}
                         } )

    if ( name == nil) then
        error ( "A Node needs to have a name set, but it isn't!" )
    end
    local phys, err = net.list_phys()
    if ( phys == nil ) then
        o:send_error ( err )
        return o
    end
    if ( ctrl ~= nil and ctrl.addr == nil ) then
        ctrl:get_addr ( )
    end
    for i, phy in ipairs ( phys ) do
        local netif = NetIF:create ()
        netif.phy = phy
        netif.mon = "mon" .. tostring ( i - 1 )
        netif.iface, msg = net.get_interface_name ( phy )
        if ( netif.iface == nil ) then
            o:send_error ( "Empty ieee80211 debugfs: please check permissions and kernel config, i.e. ATH9K_DEBUGFS: " .. msg )
        else
            netif.addr, msg = net.get_addr ( netif.iface )
            o.wifis [ #o.wifis + 1 ] = netif
        end
    end
    return o
end

function Node:__tostring() 
    local name = "none"
    if ( self.name ~= nil ) then
        name = self.name
    end
    local out = name .. "\n"
                .. self.ctrl:__tostring ()
                .. "\n"
    for i, wifi in ipairs ( self.wifis ) do
        if (i ~= 1) then
            out = out .. ", "
        end
        out = out .. wifi:__tostring ()
    end
    return out
end

-- --------------------------
-- wifi
-- --------------------------

function Node:phy_devices ()
    self:send_info( "Send phy devices." )
    local phys = {}
    for _, wifi in ipairs ( self.wifis ) do
        phys [ #phys + 1 ] = wifi.phy
    end
    self:send_info(" phys: " .. foldr ( string.concat, "" , phys ) )
    return phys
end

function Node:find_wifi_device ( phy )
    for _, dev in ipairs ( self.wifis ) do
        if ( dev.phy == phy) then
            return dev
        end
    end
    return nil
end

function Node:enable_wifi ( enabled, phy )
    local var = "wireless.radio"
    var = var .. string.sub ( phy, 4, string.len ( phy ) )
    var = var .. ".disabled"
    self:send_debug ( " enable wifi: " .. var .. " = " .. tostring ( not enabled ) )
    local value = 1
    if ( enabled == true ) then 
        value = 0
    else
        value = 1
    end
    local _, exit_code = uci.set_var ( var, value )
    return exit_code == 0
end

-- AP only
-- wireless.default_radio0.ssid='LEDE'
function Node:get_ssid ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info ( "send ssid for " .. iface )
    local str, exit_code = misc.execute ( "iw", iface, "info" )
    if ( str ~= nil and exit_code == 0) then
        local iwinfo = parse_iwinfo ( str )
        if ( iwinfo ~= nil ) then
            return iwinfo.ssid, nil
        end
    end
    return nil, nil
end

function Node:restart_wifi()
    local wifi, err = misc.execute ( "/sbin/wifi" )
    self:send_info( "restart wifi: " .. wifi )
    return true
end

-- iw dev mon0 info
-- iw phy phy0 interface add mon0 type monitor
-- ifconfig mon0 up
function Node:add_monitor ( phy )
    local dev = self:find_wifi_device ( phy )
    local mon = dev.mon
    local _, exit_code = misc.execute ( "iw", "dev", mon, "info" )
    if ( exit_code ~= 0 ) then
        self:send_info ( "Adding monitor " .. mon .. " to " .. phy)
        self_send_debug ("iw phy " .. phy .. "interface add " .. mon .. " type monitor" )
        local _, exit_code = misc.execute ( "iw", "phy", phy, "interface", "add", mon, "type", "monitor" )
        if ( exit_code ~= 0 ) then
            self:send_error ( "Add monitor failed with exit code: " .. exit_code )
            return
        end
    else
        self:send_info ( "Monitor " .. mon .. " not added to " .. phy )
    end
    self:send_info ( "enable monitor " .. mon )
    self:send_debug ( "ifconfig " .. mon .. " up" )
    local _, exit_code = misc.execute ("ifconfig", mon, "up")
    if ( exit_code ~= 0 ) then
        self:send_error ( "add monitor for device " .. phy .. "failed with exit code: " .. exit_code )
    end
end

-- iw dev mon0 info
-- iw dev mon0 del
function Node:remove_monitor ( phy )
    local dev = self:find_wifi_device ( phy )
    local mon = dev.mon
    local _, exit_code = misc.execute ( "iw", "dev", mon, "info" )
    if ( exit_code == 0 ) then
        self:send_info ( "Removing monitor " .. mon .. " from " .. phy )
        self:send_debug ( "iw dev " .. mon .. " del" )
        local _, exit_code = misc.execute ( "iw", "dev", mon, "del" )
        if (exit_code ~= 0) then
            self:send_error ( "Remove monitor failed with exit code. " .. exit_code )
        end
    end
end

function Node:list_stations ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local stations = debugfs .. "/" .. phy .. "/netdev:" .. iface .. "/stations/"
    local out = {}
    if ( isDir ( stations ) ) then
        for _, name in ipairs ( scandir ( stations ) ) do
            if ( name ~= "." and name ~= "..") then
                out [ #out + 1 ] = name
            end
        end
    end
    return out
end

function Node:visible_stations ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local list = self:list_stations ( phy )
    self:send_info ( "Send stations for " .. iface .. ": " .. table_tostring ( list ) )
    return list
end

function Node:set_ani ( phy, enabled )
    self:send_info ( "set ani for " .. phy .. " to " .. tostring ( enabled ) )
    local filename = debugfs .. "/" .. phy .. "/" .. "ath9k" .. "/"  .. "ani"
    local file = io.open ( filename, "w" )
    if ( enabled ) then
        file:write(1)
    else
        file:write(0)
    end
    file:close()
end

function Node:get_mac ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info ( "send mac for " .. iface )
    local content = misc.execute ( "ifconfig", iface )
    local ifconfig = parse_ifconfig ( content )
    if ( ifconfig == nil or ifconfig.mac == nil ) then return nil end
    self:send_info (" mac for " .. iface .. ": " .. ifconfig.mac )
    return ifconfig.mac
end

function Node:get_addr ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info ( "send ipv4 addr for " .. iface )
    if ( dev.addr == nil ) then
        self:send_error ( " interface " .. iface .. " has no ipv4 addr assigned" )
        return nil 
    else
        self:send_info ( " addr for " .. iface .. ": " .. dev.addr )
        return dev.addr
    end
end

-- returns addr when host with mac has a dhcp lease else nil
function Node:has_lease ( mac )
    self:send_info("send ipv4 addr for " .. mac .. " from lease" )
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

function Node:get_iw_link ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local content, exit_code = misc.execute ( "iw", "dev", iface, "link" )
    --self:send_debug ( "iw link exit code : " .. tostring (exit_code) )
    if ( exit_code > 0 or content == nil) then return nil end
    local iwlink = parse_iwlink ( content )
    return iwlink
end

-- returns the ssid when iface is connected
-- otherwise nil is returned
function Node:get_linked_ssid ( phy )
    self:send_info ( "Get linked ssid for device " .. phy )
    local iwlink = self:get_iw_link ( phy )
    if ( iwlink == nil or iwlink.ssid == nil ) then return nil end
    self:send_info ( " linked ssid: " .. iwlink.ssid )
    return iwlink.ssid
end

-- returns the remote iface when iface is connected
-- otherwise nil is returned
function Node:get_linked_iface ( phy )
    self:send_info ( "Get linked interface for device " .. phy )
    local iwlink = self:get_iw_link ( phy )
    if ( iwlink == nil or iwlink.iface == nil ) then return nil end
    self:send_info ( " linked iface: " .. iwlink.iface )
    return iwlink.iface
end

-- returns the remote mac when iface is connected
-- otherwise nil is returned
function Node:get_linked_mac ( phy )
    self:send_info ( "Get linked mac for device " .. phy )
    local iwlink = self:get_iw_link ( phy )
    if ( iwlink == nil or iwlink.mac == nil) then return nil end
    self:send_info ( " linked mac: " .. iwlink.mac )
    return iwlink.mac
end

-- returns the signal when iface is connected
-- otherwise nil is returned
function Node:get_linked_signal ( phy )
    self:send_info ( "Get linked signal for device " .. phy )
    local iwlink = self:get_iw_link ( phy )
    if ( iwlink == nil or iwlink.signal == nil ) then return nil end
    self:send_info ( " linked signal: " .. iwlink.signal )
    return iwlink.signal
end

-- returns the rate index when iface is connected
-- otherwise nil is returned
function Node:get_linked_rate_idx ( phy )
    self:send_info ( "Get linked rate index for device " .. phy )
    local iwlink = self:get_iw_link ( phy )
    if ( iwlink == nil or ( iwlink.rate_idx == nil and iwlink.rate == nil ) ) then return nil end
    self:send_info ( " linked rate index: " .. ( iwlink.rate_idx or iwlink.rate ) )
    return ( iwlink.rate_idx or iwlink.rate )
end

function Node:check_bridge ( phy )
    return uci_check_bridge ( phy )
end

-- --------------------------
-- Fixed Settings
-- --------------------------

function Node:get_rc_stats_lines ( phy, station )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .. "/netdev:" .. iface .. "/stations/" .. station .. "/rc_stats_csv"
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

-- read rc_stats and collects rate names
function Node:tx_rate_names( phy, station )
    self:send_info ( "List tx rate names for station " .. station .. " at device " .. phy)
    local lines = self:get_rc_stats_lines ( phy, station )
    local names = {}
    for _, rc_line in ipairs ( lines ) do
        names [ #names + 1 ] = rc_line.rate.name
    end
    return names
end

-- reads rc_stats and collects rate indices
function Node:tx_rate_indices( phy, station )
    self:send_info ( "List tx rate indices for station " .. station .. " at device " .. phy )
    local lines = self:get_rc_stats_lines ( phy, station )
    local rates = {}
    for _, rc_line in ipairs ( lines ) do
        rates [ #rates + 1 ] = rc_line.rate.idx
    end
    return rates
end

-- fixme: tx_power_levels ( per rate )
function Node:tx_power_indices ( phy, station )
    tx_powers = {}
    for i = 1, 25 do
        tx_powers[i] = i
    end
    return tx_powers
end

function Node:write_value_to_sta_debugfs ( fname, value )
    if ( not isFile ( fname ) ) then
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
    if ( not isFile ( fname ) ) then
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
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .."/netdev:" .. iface .. "/stations/" .. station .. "/fixed_txpower"
    self:send_info ( "Set tx power level for station " .. station .. " at device " .. phy .. " to " .. tx_power )
    if ( self:write_value_to_sta_debugfs ( fname, tx_power ) == false ) then
        self:send_error ( "Set tx power level for station " .. station .. " at device " .. phy .. " failed. Unsupported" )
    end
end

function Node:get_tx_power ( phy, station )
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
-- needs "/sbin/wifi;" call after
function Node:set_global_tx_power ( phy, tx_power )
    local var = "wireless.radio"
    var = var .. string.sub ( phy, 4, string.len ( phy ) )
    var = var .. ".txpower"
    local _, exit_code = uci.set_var ( var, tx_power )
end

-- /etc/config/wireless: add  option txpower '20' to config wifi-device 'radio{0,1}' section
function Node:get_global_tx_power ( phy )
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
    local fname = debugfs .. "/" .. phy .."/rc/fixed_rate_idx"
    self:send_info ( "Set global tx rate index at device " .. ( phy or "none" )
                                                      .. " to " .. ( tx_rate_idx or "none" ) )
    if ( self:write_value_to_sta_debugfs ( fname, tx_rate_idx ) == false ) then
        self:send_error ( "Set global tx rate level at device " .. phy .. " failed. Unsupported" )
    end
end

-- /sys/kernel/debug/ieee80211/phy0/rc/fixed_rate_idx
function Node:get_global_tx_rate ( phy )
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
    if ( self.rc_stats_procs [ station ] ~= nil ) then
        self:send_error ( "rc stats for station " .. station .. " already running" )
        return nil
    end
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info ( "start collecting rc_stats station " .. station .. " on " .. iface .. " (" .. phy .. ")" )
    local file = debugfs .. "/" .. phy .. "/netdev:" .. iface .. "/stations/"
                        .. station .. "/rc_stats_csv"
    if ( isFile ( file ) ) then
        local pid, stdin, stdout = misc.spawn ( "lua", fetch_file_bin, "-i", 500000000, file )
        self.rc_stats_procs [ station ] = { pid = pid, stdin = stdin, stdout = stdout }
        self:send_info ( "rc stats for station " .. station .. " started with pid: " .. pid )
        return pid
    else
        self:send_error ( "rc stats for station " .. station .. " not started. file is missing" )
        return nil
    end
end

function Node:get_rc_stats ( phy, station )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    if ( station == nil ) then
        self:send_error ( "Cannot send rc_stats because the station argument is nil!" )
        return nil
    end
    self:send_info ( "send rc-stats for " .. iface ..  ", station " .. station )
    if ( self.rc_stats_procs [ station ] == nil ) then 
        self:send_warning ( " no rc-stats for " .. station .. " found" )
        return nil 
    end
    self:send_debug ( "rc_stats process: " .. self.rc_stats_procs [ station ].pid )
    local content = self.rc_stats_procs [ station ].stdout:read("*a")
    self.rc_stats_procs [ station ].stdin:close()
    self.rc_stats_procs [ station ].stdout:close()
    self:send_info ( string.len ( content ) .. " bytes from rc_stats" )
    self.rc_stats_procs [ station ] = nil
    return content 
end

function Node:stop_rc_stats ( station )
    if ( self.rc_stats_procs [ station ] == nil 
        or self.rc_stats_procs [ station ].pid == nil ) then 
        self:send_error ( " rc_stats for station " .. ( station or "unset" ) .. " is not running!" )
        return nil
    end
    self:send_info ( "stop collecting rc stats with pid " .. self.rc_stats_procs [ station ].pid )
    local exit_code
    if ( self:kill ( self.rc_stats_procs [ station ].pid ) ) then
        exit_code = lpc.wait ( self.rc_stats_procs [ station ].pid )
    end
    return exit_code
end

-- --------------------------
-- regmon stats
-- --------------------------

function Node:start_regmon_stats ( phy )
    if ( self.regmon_proc ~= nil ) then
        self:send_error ("Not collecting regmon stats for " 
            .. iface .. ", " .. phy .. ". Alraedy running" )
        return nil
    end
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local file = debugfs .. "/" .. phy .. "/regmon/register_log"
    if ( not isFile ( file ) ) then
        self:send_warning ( "no regmon-stats for " .. iface .. ", " .. phy )
        self.regmon_proc = nil
        return nil
    end
    self:send_info ("start collecting regmon stats for " .. iface .. ", " .. phy)
    local pid, stdin, stdout = misc.spawn ( "lua", fetch_file_bin, "-l", "-i", 500000000, file )
    self.regmon_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function Node:get_regmon_stats ()
    if (self.regmon_proc == nil) then 
        self:send_error ( "no regmon process running" )
        return nil 
    end
    self:send_info ( "send regmon-stats" )
    local content = self.regmon_proc.stdout:read("*a")
    self.regmon_proc.stdin:close ()
    self.regmon_proc.stdout:close ()
    self:send_info ( string.len ( content ) .. " bytes from regmon" )
    self.regmon_proc = nil
    return content
end

function Node:stop_regmon_stats ()
    if (self.regmon_proc == nil) then 
        self:send_error ( "no regmon process running" )
        return nil 
    end
    self:send_info ( "stop collecting regmon stats with pid " .. self.regmon_proc.pid )
    local exit_code
    if ( self:kill ( self.regmon_proc.pid ) ) then
        exit_code = lpc.wait ( self.regmon_proc.pid )
    end
    return exit_code
end

-- --------------------------
-- cpusage
-- --------------------------

function Node:start_cpusage ()
    if ( self.cpusage_proc ~= nil ) then
        self:send_error (" Cpuage not started. Already running.")
        return nil
    end
    self:send_info ( "start cpusage" )
    local pid, stdin, stdout = misc.spawn ( cpusage_bin )
    self.cpusage_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function Node:get_cpusage()
    if ( self.cpusage_proc == nil ) then 
        self:send_error ( "no cpusage process running" )
        return nil 
    end
    self:send_info ( "send cpusage" )
    local content = self.cpusage_proc.stdout:read ("*all")
    self.cpusage_proc.stdin:close ()
    self.cpusage_proc.stdout:close ()
    self:send_info ( string.len ( content ) .. " bytes from cpusage" )
    self.cpusage_proc = nil
    return content
end

function Node:stop_cpusage ()
    if ( self.cpusage_proc == nil ) then 
        self:send_error ( "no cpusage process running" )
        return nil 
    end
    self:send_info ( "stop cpusage with pid " .. self.cpusage_proc.pid )
    local exit_code
    if ( self:kill ( self.cpusage_proc.pid ) ) then
        exit_code = lpc.wait ( self.cpusage_proc.pid )
    end
    return exit_code
end

-- --------------------------
-- tcpdump
-- --------------------------

-- -U packet-buffered output instead of line buffered (-l)
-- tcpdump -l -w - | tee -a file
-- tcpdump -i mon0 -s 150 -U
--  -B capture buffer size
--  -s snapshot length ( default 262144)
function Node:start_tcpdump ( phy, fname )
    if ( self.tcpdump_proc ~= nil ) then
        self:send_error (" Tcpdump not started. Already running.")
        return nil
    end
    local dev = self:find_wifi_device ( phy )
    local mon = dev.mon
    --local snaplen = 0 -- 262144
    --local snaplen = 150
    local snaplen = 256
    local snaplen = 512
    self:send_info ( "start tcpdump for " .. mon .. " writing to " .. fname )
    self:send_debug ( tcpdump_bin .. " -i " .. mon .. " -s " .. snaplen .. " -U -w " .. fname )
    local pid, stdin, stdout = misc.spawn ( tcpdump_bin, "-i", mon, "-s", snaplen, "-U", "-w", fname )
    self.tcpdump_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function Node:get_tcpdump_offline ( fname )
    self:send_info ( "send tcpdump offline for file " .. fname )
    local file = io.open ( fname, "rb" )
    if ( file == nil ) then 
        self:send_error ( "no tcpdump file found" )
        return nil 
    end
    local content = file:read ("*a")
    file:close()
    self:send_info ( "remove tcpump pcap file " .. fname )
    os.remove ( fname )
    self.tcpdump_proc = nil
    return content
end

function Node:stop_tcpdump ()
    if ( self.tcpdump_proc == nil ) then
        self:send_error ( "No tcpdump running." )
        return nil
    end
    self:send_info("stop tcpdump with pid " .. self.tcpdump_proc.pid )
    local exit_code
    if ( self:kill ( self.tcpdump_proc.pid ) ) then
        exit_code = lpc.wait ( self.tcpdump_proc.pid )
    end
    return exit_code
end

-- --------------------------
-- iperf
-- --------------------------

-- fixme: rpc function name to long
function Node:start_tcp_iperf_s ()
    if ( self.iperf_server_proc ~= nil ) then
        self:send_error (" Iperf Server (tcp) not started. Already running.")
        return nil
    end
    self:send_info ( "start TCP iperf server at port " .. self.iperf_port )
    self:send_debug ( iperf_bin .. " -s -p " .. ( self.iperf_port or "none" ) )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-s", "-p", self.iperf_port )
    self.iperf_server_proc = { pid = pid, stdin = stdin, stdout = stdout }
    for i=1,4 do
        local msg = stdout:read("*l")
        if ( msg ~= nil ) then
            self:send_info(msg)
        end
    end
    return pid
end

-- iperf -s -u -p 12000
-- fixme: rpc function name to long
function Node:start_udp_iperf_s ()
    if ( self.iperf_server_proc ~= nil ) then
        self:send_error (" Iperf Server (udp) not started. Already running.")
        return nil
    end
    self:send_info ( "start UDP iperf server at port " .. self.iperf_port )
    self:send_debug ( iperf_bin .. " -s -u -p " .. ( self.iperf_port or "none" ) )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-s", "-u", "-p", self.iperf_port )
    self.iperf_server_proc = { pid = pid, stdin = stdin, stdout = stdout }
    for i=1,5 do
        local msg = stdout:read("*l")
        self:send_info(msg)
    end
    return pid
end

-- iperf -c 192.168.1.240 -p 12000 -n 500MB
function Node:run_tcp_iperf ( addr, tcpdata, wait )
    if ( self.iperf_client_procs [ addr ] ~= nil ) then
        self:send_error (" Iperf client (tcp) not started for address " .. addr .. ". Already running.")
        return nil
    end
    self:send_info ( "run TCP iperf at port " .. self.iperf_port 
                                .. " to addr " .. addr 
                                .. " with tcpdata " .. ( tcpdata or "none" ) )
    self:send_debug ( iperf_bin .. " -c " .. addr .. " -p " .. self.iperf_port .. " -n " .. tcpdata )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-c", addr, "-p", self.iperf_port, "-n", tcpdata )
    self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    local exit_code
    if ( wait == true ) then
        exit_code = lpc.wait ( pid )
        self.iperf_client_procs [ addr ].stdin:close ()
        self.iperf_client_procs [ addr ].stdout:close ()
        self.iperf_client_procs [ addr ] = nil
    end
    return pid, exit_code
end

-- iperf -u -c 192.168.1.240 -p 12000 -l 1500B -b 600000 -t 240
--function Node:run_udp_iperf ( addr, size, rate, interval, wait )
function Node:run_udp_iperf ( addr, rate, duration, wait )
    if ( self.iperf_client_procs [ addr ] ~= nil ) then
        self:send_error (" Iperf client (udp) not started for address " .. addr .. ". Already running.")
        return nil
    end
    self:send_info ( "run UDP iperf at port " .. ( self.iperf_port or "none" )
                                .. " to addr " .. ( addr or "none" )
                                .. " with rate " .. rate .. " and duration " .. duration )
    --self:send_info ( "run UDP iperf at port " .. ( self.iperf_port or "none" )
    --                            .. " to addr " .. ( addr or "none" )
    --                            .. " with size, rate and interval " .. size .. ", " .. rate .. ", " .. interval )
    --local bitspersec = size * 8 * rate
    self:send_debug ( iperf_bin .. " -u" .. " -c " .. addr .. " -p " .. self.iperf_port
                        .. " -b " .. rate .. " -t " .. duration )

    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-u", "-c", addr, "-p", self.iperf_port, 
                                            "-b", rate, "-t", duration )

    self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    local exit_code
    if ( wait == true ) then
        exit_code = lpc.wait ( pid )
        self.iperf_client_procs [ addr ].stdin:close ()
        self.iperf_client_procs [ addr ].stdout:close ()
        self.iperf_client_procs [ addr ] = nil
    end
    return pid, exit_code
end

-- iperf -c 224.0.67.0 -u -T 32 -t 3 -i 1 -B 192.168.1.1
-- iperf -c 224.0.67.0 -u --ttl 1 -t 120 -b 100M -l 1500 -B 10.10.250.2
-- iperf -u -c 224.0.67.0 -p 12000 -T 32 -t 10 -b 1MB -B 192.168.1.1
function Node:run_multicast ( addr, multicast_addr, ttl, bitrate, duration, wait )
    if ( self.iperf_client_procs [ addr ] ~= nil ) then
        self:send_error (" Iperf client (mcast) not started for address " .. addr .. ". Already running.")
        return nil
    end
    self:send_info ( "run UDP iperf at port " .. self.iperf_port 
                                .. " to addr " .. addr 
                                .. " with ttl and duration " .. ttl .. ", " .. duration )
    self:send_debug ( iperf_bin .. " -u " .. " -c " .. multicast_addr  .. " -p " .. self.iperf_port
                                .. " -T " .. ttl .. " -t " .. duration .. " -b " .. bitrate .. " -B " .. addr )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-u", "-c", multicast_addr, "-p", self.iperf_port,
                                         "-T", ttl, "-t", duration, "-b", bitrate, "-B", addr )
    self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    local exit_code
    if ( wait == true ) then
        exit_code = lpc.wait ( pid )
        self.iperf_client_procs [ addr ].stdin:close ()
        self.iperf_client_procs [ addr ].stdout:close ()
        self.iperf_client_procs [ addr ] = nil
    end
    return pid, exit_code
end

function Node:wait_iperf_c ( addr )
    if ( addr == nil ) then
        self:send_error ( " wait for iperf client failed, addr is not set." )
        return
    end
    if ( self.iperf_client_procs [ addr ] == nil ) then
        self:send_error ( " iperf client is not running." )
        return
    end
    self:send_info ( "wait for TCP/UDP client iperf for address " .. addr ) 
    local exit_code = lpc.wait ( self.iperf_client_procs [ addr ].pid )
--    repeat
--        local line = self.iperf_client_procs [ addr ].stdout:read ("*l")
--        if line ~= nil then self:send_info ( line ) end
--    until line == nil
    self.iperf_client_procs [ addr ].stdin:close ()
    self.iperf_client_procs [ addr ].stdout:close ()
    self.iperf_client_procs [ addr ] = nil
    return exit_code
end

function Node:stop_iperf_server ()
    if ( self.iperf_server_proc == nil ) then
        self:send_error ( " iperf server is not running." )
        return
    end
    self:send_info ( "stop iperf server with pid " .. self.iperf_server_proc.pid )
    local exit_code
    if ( self:kill ( self.iperf_server_proc.pid ) ) then
        exit_code = lpc.wait ( self.iperf_server_proc.pid )
    end
--    repeat
--        local line = self.iperf_server_proc.stdout:read ("*l")
--        if line ~= nil then self:send_info ( line ) end
--    until line == nil
    self.iperf_server_proc.stdin:close ()
    self.iperf_server_proc.stdout:close ()
    self.iperf_server_proc = nil
    return exit_code
end
