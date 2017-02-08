require ('rpc')
require ('spawn_pipe')
require ('parentpid')
local unistd = require ('posix.unistd')
require ('NetIF')
require ('misc')
require ('parsers/iw_link')
require ('parsers/ifconfig')
require ('parsers/dhcp_lease')
require ("parsers/ex_process")

local iperf_bin = "iperf"
local lease_fname = "/tmp/dhcp.leases"

-- TODO: 
-- - STA connect to AP
-- - split Node into NodeAP, NodeSTA

Node = { name = nil, wifis = nil, ctrl = nil 
       , iperf_port = nil, tcpdump_proc = nil
       , cpusage_proc = nil
       , log_port = nil
       , regmon_proc = nil
       , rc_stats_procs = nil
       , iperf_sever_proc = nil
       , iperf_client_procs = nil
       }

function Node:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Node:create ( name, ctrl, iperf_port, log_ip, log_port )
    local o = Node:new({ name = name, ctrl = ctrl, wifis = {}
                       , iperf_port = iperf_port, log_ip = log_ip, log_port = log_port 
                       , rc_stats_procs = {}
                       , iperf_client_procs = {}
                       })
    if ( name == nil) then
        error ( "A Node needs to have a name set, but it isn't!" )
    end
    local phys = list_phys()
    for i, phy in ipairs ( phys ) do
        local netif = NetIF:create ( "radio" .. i-1 )
        o.wifis [ #o.wifis + 1 ] = netif
        netif.phy = phy
        -- mon: maybe obsolete, but some devices doesn't support default monitoring, they have prism monitors, i.e. prism0
        netif.mon = "mon" .. tostring(i-1)
        netif.iface = get_interface_name ( phy )
        -- doesn't work in APs with bridged lan over switchdevice and wifi
        netif.addr = get_ip_addr ( netif.iface )
    end
    return o
end

function Node:__tostring() 
    local name = "none"
    if ( self.name ~= nil) then
        name = self.name
    end
    local out = name .. "\n"
                .. self.ctrl:__tostring()
                .. "\n"
    for i, wifi in ipairs ( self.wifis ) do
        if (i ~= 1) then
            out = out .. ", "
        end
        out = out .. wifi:__tostring()
    end
    return out
end

function get_ip_addr ( iface )
    if ( iface == nil ) then error ( "argument iface unset!" ) end
    local ifconfig_proc = spawn_pipe( "ifconfig", iface )
    ifconfig_proc['proc']:wait()
    local ifconfig = parse_ifconfig ( ifconfig_proc['out']:read("*a") )
    close_proc_pipes ( ifconfig_proc )
    if (ifconfig == nil or ifconfig.addr == nil) then 
        return nil
    else
        return ifconfig.addr
    end
end

function Node:find_wifi_device ( phy )
    for _, dev in ipairs ( self.wifis ) do
        if ( dev.phy == phy) then
            return dev
        end
    end
    return nil
end

-- fixme: try to catch address in use
function Node:run( port )
    if rpc.mode == "tcpip" then
        self:send_info("Service " .. self.name .. " started")
        self:set_cut()
        rpc.server(port);
    else
        print ( "Err: tcp/ip supported only" )
    end
end

local debugfs = "/sys/kernel/debug/ieee80211"

-- --------------------------
-- wifi
-- --------------------------
-- uci show wireless
-- wireless.@wifi-iface[1].key=''
-- uci show network
-- network.lan.ipaddr='192.168.10.1'
-- network.wan.ifname='eth0.2'
-- network.wan.proto='dhcp'
-- 

-- AP only
-- use uci:
-- root@lede-ap:~# uci show wireless.default_radio0.ssid
-- wireless.default_radio0.ssid='LEDE'
-- root@lede-ap:~# uci show wireless.default_radio1.ssid
-- wireless.default_radio0.ssid='LEDE'
function Node:get_ssid( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info("send ssid for " .. iface)
    local iwinfo = spawn_pipe("iw", iface, "info")
    local exit_code = iwinfo['proc']:wait()
    if (exit_code == 0) then
        -- TODO: parse response
        local str = iwinfo ['out']:read("*all")
        str = string.gsub ( str, "\t", " " )
        str = string.gsub ( str, "\n", " " )
        local tokens = split ( str, " " )
        for i, token in ipairs( tokens ) do
            if ( token == "ssid") then
                close_proc_pipes ( iwinfo )
                return tokens [ i + 1 ]
            end
        end
    end
    close_proc_pipes ( iwinfo )
    return nil
end

function Node:restart_wifi()
    local wifi = spawn_pipe("wifi")
    local exit_code = wifi['proc']:wait()
    close_proc_pipes ( wifi )
    self:send_info("restart wifi")
    return exit_code == 0
end

-- iw dev mon0 info
-- iw phy phy0 interface add wlan0 type monitor
-- ifconfig wlan0 up
-- fixme: command failed: Too many open files in system (-23)
function Node:add_monitor ( phy )
    local dev = self:find_wifi_device ( phy )
    local mon = dev.mon
    local iw_info = spawn_pipe("iw", "dev", mon, "info")
    local exit_code = iw_info['proc']:wait()
    close_proc_pipes ( iw_info )
    if (exit_code ~= 0) then
        self:send_info("Adding monitor " .. mon .. " to " .. phy)
        local iw_add = spawn_pipe("iw", "phy", phy, "interface", "add", mon, "type", "monitor")
        local exit_code = iw_add['proc']:wait()
        close_proc_pipes ( iw_add )
        if (exit_code ~= 0) then
            self:send_error("Add monitor failed: " .. exit_code)
        end
    else
        self:send_info("Monitor " .. mon .. " not added to " .. phy .. ": already exists")
    end
    self:send_info("enable monitor " .. mon)
    local ifconfig = spawn_pipe("ifconfig", mon, "up")
    local exit_code = ifconfig['proc']:wait()
    if (exit_code ~= 0) then
        self:send_error("add monitor for device " .. phy .. "failed with exit code " .. exit_code)
    end
    close_proc_pipes ( ifconfig )
end

-- iw dev mon0 info
-- iv dev mon0 del
function Node:remove_monitor ( phy )
    local dev = self:find_wifi_device ( phy )
    local mon = dev.mon
    local iw_info = spawn_pipe("iw", "dev", mon, "info")
    local exit_code = iw_info['proc']:wait()
    close_proc_pipes ( iw_info )
    if (exit_code == 0) then
        self:send_info("Removing monitor " .. mon .. " from " .. phy)
        local iw_add = spawn_pipe("iw", "dev", mon, "del")
        local exit_code = iw_add['proc']:wait()
        close_proc_pipes ( iw_add )
        if (exit_code ~= 0) then
            self:send_error("Remove monitor failed: " .. exit_code)
        end
    end
end


function list_phys ()
    local phys = {}
    for file in lfs.dir( debugfs ) do
        if (file ~= "." and file ~= "..") then
            phys [ #phys + 1 ] = file
        end
    end
    table.sort ( phys )
    return phys
end

function get_interface_name ( phy )
    local dname = debugfs .. "/" .. phy
    for file in lfs.dir( dname ) do
        if ( string.sub( file, 1, 7 ) == "netdev:" and string.sub ( file, 8, 10 ) ~= "mon" ) then
            return string.sub( file, 8 )
        end
    end
    return nil
end

function Node:wifi_devices ()
    self:send_info( "Send phy devices." )
    local phys = list_phys()
    self:send_info(" phys: " .. foldr ( string.concat, "" , phys ) )
    return phys
end

function Node:list_stations ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local stations = debugfs .. "/" .. phy .. "/netdev:" .. iface .. "/stations/"
    local out = {}
    for _, name in ipairs ( scandir ( stations ) ) do
        if ( name ~= "." and name ~= "..") then
            out [ #out + 1 ] = name
        end
    end
    return out
end

function Node:stations ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local list = self:list_stations ( phy )
    self:send_info("Send stations for " .. iface )
    return list
end

function Node:set_ani ( phy, enabled )
    self:send_info("set ani for " .. phy .. " to " .. tostring ( enabled ) )
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
    self:send_info("send mac for " .. iface )
    local ifconfig_proc = spawn_pipe( "ifconfig", iface )
    ifconfig_proc['proc']:wait()
    local ifconfig = parse_ifconfig ( ifconfig_proc['out']:read("*a") )
    close_proc_pipes ( ifconfig_proc )
    if ( ifconfig == nil or ifconfig.mac == nil ) then return nil end
    self:send_info(" mac for " .. iface .. ": " .. ifconfig.mac )
    return ifconfig.mac
end

function Node:get_addr ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info("send ipv4 addr for " .. iface )
    local addr = get_ip_addr ( iface )
    if ( addr == nil ) then
        self:send_error(" interface " .. iface .. " has no ipv4 addr assigned")
        return nil 
    else
        self:send_info(" addr for " .. iface .. ": " .. addr )
        return addr
    end
end

-- returns addr when host with mac has a dhcp lease else nil
function Node:has_lease ( mac )
    self:send_info("send ipv4 addr for " .. mac .. " from lease" )
    local file = io.open ( lease_fname )
    if ( not isFile ( lease_fname ) ) then return nil end
    local content = file:read("*a")
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

function Node:tx_rate_indices( phy, station )
    self:send_info("List tx rates for station " .. station .. " at device " .. phy)
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = debugfs .. "/" .. phy .. "/netdev:" .. iface .. "/stations/" .. station .. "/rc_stats_csv"
    local rates = {}
    -- TODO: csv parser
    local file = io.open( fname )
    if ( file ~= nil ) then
        local content = file:read("*a")
        for _, line in ipairs ( split (content, '\n') ) do
            local fields = split (line, ',')
            if ( fields[6] ~= nil ) then
                rates [ #rates + 1 ] = tonumber ( fields[6] )
            end
        end
        table.sort ( rates )
        file:close()
    end
    return rates
end

-- fixme: tx_power_levels
-- funtion tx_power_levels ( phy, station )
-- end

-- set the power level by index (i.e. 25 is the index of the highest power level, sometimes 50)
-- usally two different power levels differs by a multiple of 1mW (25 levels) or 0.5mW (50 power levels)
-- todo: set tx_power with newly created debugfs entry
function Node:set_tx_power ( phy, station, tx_power )
    self:send_info("Set tx power level for station " .. station .. " at device " .. phy .. " to " .. tx_power)
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local fname = "/sys/kernel/debug/ieee80211/" .. phy .."/netdev:" .. iface .. "/txpower"
    local file = io.open ( fname )
    if ( file ~= nil) then
        file:write ( tostring ( tx_power ) )
        file:flush()
        file:close()
    end
end

-- rate can be set for 
--      - monitored device at 'monitor_tx_rate' (fixme: not in tree)
--      - broadcast at 'bcast_tx_rate' (fixme: not in tree)
--      - per station at 'rate_scale_table' (fixme: not in tree)
function Node:set_tx_rate ( phy, station, tx_rate_idx )
    self:send_info("Set tx rate index for station " .. station .. " at device " .. phy .. " to " .. tx_rate_idx)
    local fname = debugfs .. "/rc/" .. "fixed_rate_idx"
    local file = io.open ( fname )
    if ( file ~= nil) then
        file:write ( tostring ( tx_rate_idx ) )
        file:flush()
        file:close()
    end
end

-- returns the ssid when iface is connected
-- otherwise nil is returned
function Node:get_linked_ssid ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local iwlink_proc = spawn_pipe( "iw", "dev", iface, "link" )
    iwlink_proc['proc']:wait()
    local iwlink = parse_iwlink ( iwlink_proc['out']:read("*a") )
    close_proc_pipes ( iwlink_proc )
    if (iwlink == nil) then return nil end
    return iwlink.ssid
end

-- returns the remote iface when iface is connected
-- otherwise nil is returned
function Node:get_linked_iface ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local iwlink_proc = spawn_pipe( "iw", "dev", iface, "link" )
    iwlink_proc['proc']:wait()
    local iwlink = parse_iwlink ( iwlink_proc['out']:read("*a") )
    close_proc_pipes ( iwlink_proc )
    if (iwlink == nil) then return nil end
    return iwlink.iface
end

-- returns the remote mac when iface is connected
-- otherwise nil is returned
function Node:get_linked_mac ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local iwlink_proc = spawn_pipe( "iw", "dev", iface, "link" )
    iwlink_proc['proc']:wait()
    local iwlink = parse_iwlink ( iwlink_proc['out']:read("*a") )
    close_proc_pipes ( iwlink_proc )
    if (iwlink == nil) then return nil end
    return iwlink.mac
end

-- --------------------------
-- rc_stats
-- --------------------------

function Node:start_rc_stats ( phy, stations )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    self:send_info("start collecting rc stats for " .. iface .. ", " .. phy)
    local out = {}
    for _, station in ipairs ( stations ) do
        self:send_info ( " start collecting rc_stats stations: " .. station )
        local file = debugfs .. "/" .. phy .. "/netdev:" .. iface .. "/stations/"
                        .. station .. "/rc_stats_csv"
        local rc_stats = spawn_pipe ( "lua", "bin/fetch_file.lua", "-i", "50000", file )
        if ( rc_stats ['err_msg'] ~= nil ) then
            self:send_error("fetch_file: " .. rc_stats ['err_msg'] )
        end
        self.rc_stats_procs [ station ] = rc_stats
        self:send_info("rc stats for station " .. station .. " started " .. rc_stats['proc']:__tostring())
        out [ #out + 1 ] = rc_stats['proc']:__tostring()
    end
    return out
end

function Node:get_rc_stats ( phy, station )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    if ( station == nil ) then
        self:send_error ( "Cannot send rc_stats because the station argument is nil!" )
        return nil
    end
    self:send_info("send rc-stats for " .. iface ..  ", station " .. station)
    if ( self.rc_stats_procs [ station ] == nil) then return nil end
    local content = self.rc_stats_procs [ station ] [ 'out' ]:read("*a")
    self:send_info ( string.len ( content ) .. " bytes from rc_stats" )
    close_proc_pipes ( self.rc_stats_procs [ station ] )
    return content 
end

function Node:stop_rc_stats ( pid )
    if ( pid == nil ) then 
        self:send_error ( "Cannot kill rc stats because pid is nil!" )
        return nil
    end
    self:send_info("stop collecting rc stats with pid " .. pid)
    return kill ( pid )
end

-- --------------------------
-- regmon stats
-- --------------------------

function Node:start_regmon_stats ( phy )
    local dev = self:find_wifi_device ( phy )
    local iface = dev.iface
    local file = debugfs .. "/" .. phy .. "/regmon/register_log"
    if (not isFile(file)) then
        self:send_warning("no regmon-stats for " .. iface .. ", " .. phy)
        self.regmon_proc = nil
        return nil
    end
    self:send_info("start collecting regmon stats for " .. iface .. ", " .. phy)
    local regmon = spawn_pipe( "lua", "bin/fetch_file.lua", "-l", "-i", "50000", file )
    self.regmon_proc = regmon
    return regmon['proc']:__tostring()
end

function Node:get_regmon_stats ()
    self:send_info("send regmon-stats")
    if (self.regmon_proc == nil) then 
        self:send_error("no regmon process running" )
        return nil 
    end
    local content = self.regmon_proc['out']:read("*a")
    self:send_info ( string.len ( content ) .. " bytes from regmon" )
    close_proc_pipes ( self.regmon_proc )
    return content
end

function Node:stop_regmon_stats ( pid )
    self:send_info("stop collecting regmon stats with pid " .. pid)
    return kill ( pid )
end

-- --------------------------
-- cpusage
-- --------------------------

local cpusage_dump_fname = "/tmp/cpusage_dump"
function Node:start_cpusage ()
    self:send_info("start cpusage")
    local cpusage = spawn_pipe( "cpusage_single" )
    self.cpusage_proc = cpusage
    return cpusage['proc']:__tostring()
end

function Node:get_cpusage()
    self:send_info("send cpusage")
    if ( self.cpusage_proc == nil ) then return nil end
    local a = self.cpusage_proc['out']:read("*all")
    self:send_info ( string.len ( a ) .. " bytes from cpusage" )
    close_proc_pipes ( self.cpusage_proc )
    return a
end

function Node:stop_cpusage ( pid )
    self:send_info("stop cpusage with pid " .. pid)
    -- self.cpusage_proc = nil -- needed to read pipe
    return kill ( pid )
end

-- --------------------------
-- tcpdump
-- --------------------------

-- TODO: lock
-- -U packet-buffered output instead of line buffered (-l)
-- tcpdump -l | tee file
-- tcpdump -i mon0 -s 150 -U
-- tcpdump: mon0: SIOCETHTOOL(ETHTOOL_GET_TS_INFO) ioctl failed: No such device
function Node:start_tcpdump ( phy, fname )
    local dev = self:find_wifi_device ( phy )
    local mon = dev.mon
    self:send_info("start tcpdump for " .. mon)
    local tcpdump = spawn_pipe( "tcpdump", "-i", mon, "-s", "150", "-U", "-w", fname)
--    local tcpdump, _ = spawn_pipe2( { "tcpdump", "-i", mon, "-s", "150", "-U", "-w", "-" },
--                                 { "tee", "-a", fname } )
    self.tcpdump_proc = tcpdump
--    repeat
        local line = tcpdump['err']:read('*line')
        if line then self:send_info(line) end
--    until line == nil
    return tcpdump['proc']:__tostring()
end

function Node:get_tcpdump_offline ( fname )
    self:send_info("send tcpdump offline for file " .. fname)
    local file = io.open ( fname, "rb" )
    if ( file == nil ) then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

-- TODO: unlock
function Node:stop_tcpdump ( pid )
    self:send_info("stop tcpdump with pid " .. pid)
    return kill ( pid )
end

-- --------------------------
-- iperf
-- --------------------------

-- TODO: lock
-- fixme: rpc function name to long
function Node:start_tcp_iperf_s ()
    self:send_info("start TCP iperf server at port " .. self.iperf_port)
    local iperf = spawn_pipe(iperf_bin, "-s", "-p", self.iperf_port)
    self.iperf_server_proc = iperf
    if ( iperf['proc'] == nil ) then
        self:send_error ( "udp iperf server not started" )
    end
    for i=1,4 do
        local msg = iperf['out']:read("*l")
        self:send_info(msg)
    end
    return iperf['proc']:__tostring()
end

-- TODO: lock
-- iperf -s -u -p 12000
-- fixme: rpc function name to long
function Node:start_udp_iperf_s ()
    self:send_info("start UDP iperf server at port " .. self.iperf_port)
    local iperf = spawn_pipe(iperf_bin, "-s", "-u", "-p", self.iperf_port)
    self.iperf_server_proc = iperf
    if ( iperf['proc'] == nil ) then
        self:send_error ( "tcp iperf server not started" )
        return nil 
    end
    for i=1,5 do
        local msg = iperf['out']:read("*l")
        self:send_info(msg)
    end
    return iperf['proc']:__tostring()
end

-- iperf -c 192.168.1.240 -p 12000 -n 500MB
function Node:run_tcp_iperf ( addr, tcpdata, wait )
    self:send_info("run TCP iperf at port " .. self.iperf_port 
                                .. " to addr " .. addr 
                                .. " with tcpdata " .. tcpdata)
    local iperf = spawn_pipe(iperf_bin, "-c", addr, "-p", self.iperf_port, "-n", tcpdata)
    if ( iperf['proc'] == nil ) then 
        self:send_error ( "tcp iperf client not started" )
        return nil 
    end
    local iperf_str = iperf['proc']:__tostring()
    iperf_proc = parse_process( iperf_str )
    self.iperf_client_procs[ iperf_proc['pid'] ] = iperf
    if ( wait == true) then
        self:wait_iperf_c (iperf_proc['pid'])
    end
    return iperf_proc['pid']
end

-- iperf -u -c 192.168.1.240 -p 12000 -l 1500B -b 600000 -t 240
function Node:run_udp_iperf ( addr, size, rate, interval, wait )
    self:send_info("run UDP iperf at port " .. self.iperf_port 
                                .. " to addr " .. addr 
                                .. " with size, rate and interval " .. size .. ", " .. rate .. ", " .. interval)
    local bitspersec = size * 8 * rate
    local iperf = spawn_pipe ( iperf_bin, "-u", "-c", addr, "-p", self.iperf_port, "-l", size .. "B", "-b", bitspersec, "-t", interval)
    if ( iperf['proc'] == nil ) then
        self:send_error ( "udp iperf client not started" )
        return nil
    end
    local iperf_str = iperf['proc']:__tostring()
    iperf_proc = parse_process( iperf_str )
    self.iperf_client_procs[ iperf_proc['pid'] ] = iperf
    if ( wait == true) then
        self:wait_iperf_c (iperf_proc['pid'])
    end
    return iperf_proc['pid']
end

-- iperf -c 224.0.67.0 -u -T 32 -t 3 -i 1 -B 192.168.1.1
-- iperf -c 224.0.67.0 -u --ttl 1 -t 120 -b 100M -l 1500 -B 10.10.250.2
function Node:run_multicast ( addr, multicast_addr, ttl, size, interval, wait )
    self:send_info("run UDP iperf at port " .. self.iperf_port 
                                .. " to addr " .. addr 
                                .. " with ttl and interval " .. ttl .. ", " .. interval)
    local iperf = spawn_pipe ( iperf_bin, "-u", "-c", multicast_addr, "-p", self.iperf_port
                             , "-T", ttl, "-t", interval, "-b", size, "-B", addr)
    if ( iperf['proc'] == nil ) then
        self:send_error ( "udp multicast iperf client not started" )
        return nil 
    end
    local iperf_str = iperf['proc']:__tostring()
    iperf_proc = parse_process( iperf_str )
    self.iperf_client_procs[ iperf_proc['pid'] ] = iperf
    if ( wait == true) then
        self:wait_iperf_c (iperf_proc['pid'])
    end
    return iperf_proc['pid']
end

function Node:wait_iperf_c ( pid )
    self:send_info("wait for TCP/UDP client iperf") 
    local exit_code = self.iperf_client_procs[ pid ]['proc']:wait()
    repeat
        local line = self.iperf_client_procs[ pid ]['out']:read("*l")
        if line ~= nil then self:send_info ( line ) end
    until line == nil
    close_proc_pipes ( self.iperf_client_procs[ pid ] )
    self.iperf_client_procs [ pid ] = nil
end

-- TODO: unlock
function Node:stop_iperf_server ( pid )
    self:send_info("stop iperf server with pid " .. pid)
    local exit_code = kill ( pid )
    repeat
        local line = self.iperf_server_proc['out']:read("*l")
        if line ~= nil then self:send_info ( line ) end
    until line == nil
    close_proc_pipes ( self.iperf_server_proc )
    return exit_code
end

-- -------------------------
-- posix
-- -------------------------

function Node:get_pid()
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

function Node:connect_logger ()
    function connect ()
        local l, e = rpc.connect (self.log_ip, self.log_port)
        return l, e
    end
    local status, logger, err = pcall ( connect )
    -- TODO: print this message a single time only
    if (status == false) then
        print ( "Err: Connection to Logger failed" )
        print ("Err: no logger at address: " .. self.log_ip .. " on port: " .. self.log_port)
        return nil
    else
        return logger
    end
end

function Node:disconnect_logger ( logger )
    if (logger ~= nil) then
        rpc.close (logger)
    end
end

function Node:set_cut ()
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.set_cut ()    
    end
    self:disconnect_logger ( logger )
end

function Node:send_error( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_error( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function Node:send_info( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_info( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end

function Node:send_warning( msg )
    local logger = self:connect_logger()
    if (logger ~= nil) then
        logger.send_warning( self.name, msg )    
    end
    self:disconnect_logger ( logger )
end
