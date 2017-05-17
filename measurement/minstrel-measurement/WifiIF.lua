
require ('NetIF')
require ('parsers/iw_info')
require ('parsers/iw_link')

local misc = require ('misc')
local pprint = require ('pprint')
local lpc = require ('lpc')
local uci = require ('Uci')

WifiIF = NetIF:new()
local debugfs = "/sys/kernel/debug/ieee80211"

function WifiIF:create ( lua_bin, iface, addr, mon, phy, node )
    local o = WifiIF:new ( { lua_bin = lua_bin
                           , iface = iface
                           , addr = addr
                           , mon = mon
                           , phy = phy
                           , node = node -- logging, kill
                           , regmon_proc = nil
                           , cpusage_proc = nil
                           , rc_stats_procs = {}
                           , tcpdump_proc = nil
                           , iperf_client_procs = {}
                           , iperf_server_proc = nil
                           } )

    return o
end

function WifiIF:set_channel_htmode ( channel, htmode, proc_version )
    self.node:send_info ( "set channel and htmode of " .. ( self.iface or "none" )
                        .. " to " .. ( channel or "none" ) .. " " .. ( htmode or "none" ) )
    if ( proc_version.system == "LEDE" ) then
        local var = "wireless.radio"
        var = var .. string.sub ( self.phy, 4, string.len ( self.phy ) )
        var = var .. ".channel"
        local _, exit_code = uci.set_var ( var, channel )
        local var = "wireless.radio"
        var = var .. string.sub ( self.phy, 4, string.len ( self.phy ) )
        var = var .. ".htmode"
        local _, exit_code = uci.set_var ( var, htmode )
    else
        if ( htmode == "HT40" and tonumber ( channel ) >= 1 and tonumber ( channel ) <= 7 ) then
            htmode = "HT40+"
            self.node:send_info ( "htmode HT40 without direction (+/-). " .. htmode .. " selected" )
        elseif ( htmode == "HT40" and tonumber ( channel ) >= 5 and tonumber ( channel ) <= 11 ) then
            htmode = "HT40-"
            self.node:send_info ( "htmode HT40 without direction (+/-). " .. htmode .. " selected" )
        end
        local _,_ = misc.execute ( "ifconfig", self.iface, "down" )
        -- interface has to be disabled when setting channel, freq or htmode
        -- command failed: Device or resource busy (-16)
        local str, exit_code = misc.execute ( "iw", "phy", self.phy, "set", "channel", channel, htmode )
        local _,_ = misc.execute ( "ifconfig", self.iface, "up" )
    end
end

function WifiIF:get_iw_info ()
    self.node:send_info ( "send iw info for " .. ( self.iface or "none" ) )
    local str, exit_code = misc.execute ( "iw", self.iface, "info" )
    if ( str ~= nil and exit_code == 0) then
        return str
    end
    return nil
end

-- AP only
-- wireless.default_radio0.ssid='LEDE'
function WifiIF:get_ssid ()
    self.node:send_info ( "send ssid for " .. ( self.iface or "none" ) )
    local str, exit_code = misc.execute ( "iw", self.iface, "info" )
    if ( str ~= nil and exit_code == 0) then
        local iwinfo = parse_iwinfo ( str )
        if ( iwinfo ~= nil ) then
            self.node:send_info ( " ssid " .. ( iwinfo.ssid or "none" ) )
            return iwinfo.ssid, nil
        end
    end
    return nil, nil
end

-- iw dev mon0 info
-- iw phy phy0 interface add mon0 type monitor
-- ifconfig mon0 up
function WifiIF:add_monitor ()
    self.node:send_debug ("iw dev " .. self.mon .. " info" )
    local _, exit_code = misc.execute ( "iw", "dev", self.mon, "info" )
    if ( exit_code ~= 0 ) then
        self.node:send_info ( "Adding monitor " .. self.mon .. " to " .. self.phy)
        self.node:send_debug ("iw phy " .. self.phy .. " interface add " .. self.mon .. " type monitor" )
        local _, exit_code = misc.execute ( "iw", "phy", self.phy, "interface", "add", self.mon, "type", "monitor" )
        if ( exit_code ~= 0 ) then
            self.node:send_error ( "Add monitor failed with exit code: " .. exit_code )
            return
        end
    else
        self.node:send_info ( "Monitor " .. self.mon .. " not added to " .. self.phy )
    end
    self.node:send_info ( "enable monitor " .. self.mon )
    self.node:send_debug ( "ifconfig " .. self.mon .. " up" )
    local _, exit_code = misc.execute ("ifconfig", self.mon, "up")
    if ( exit_code ~= 0 ) then
        self.node:send_error ( "add monitor for device " .. self.phy .. "failed with exit code: " .. exit_code )
    end
end

-- iw dev mon0 info
-- iw dev mon0 del
function WifiIF:remove_monitor ()
    local _, exit_code = misc.execute ( "iw", "dev", self.mon, "info" )
    if ( exit_code == 0 ) then
        self.node:send_info ( "Removing monitor " .. self.mon .. " from " .. self.phy )
        self.node:send_debug ( "iw dev " .. self.mon .. " del" )
        local _, exit_code = misc.execute ( "iw", "dev", self.mon, "del" )
        if (exit_code ~= 0) then
            self.node:send_error ( "Remove monitor failed with exit code. " .. exit_code )
        end
    end
end

function WifiIF:get_mac ( bridged )
    local iface = self.iface
    if ( bridged ~= nil and bridged == true ) then
        local bridge = self:check_bridge ( iface )
        if ( bridge ~= nil ) then
            iface = bridge
        end
    end
    self.node:send_info ( "send mac for " .. iface )
    local content = misc.execute ( "ifconfig", iface )
    local ifconfig = parse_ifconfig ( content )
    if ( ifconfig == nil or ifconfig.mac == nil ) then return nil end
    self.node:send_info (" mac for " .. iface .. ": " .. ifconfig.mac )
    return ifconfig.mac
end

function WifiIF:check_bridge ()
    local content = misc.execute ( "brctl", "show" )
    if ( content ~= nil ) then
        local brctl = parse_brctl ( content )
        for _, interface in ipairs ( brctl.interfaces ) do
            if ( self.iface == interface ) then
                return brctl.name
            end
        end
    end
    return nil
end

function WifiIF:get_iw_link ( parse )
    self.node:send_debug ( "iw dev " .. ( self.iface or "none" ) .. " link" )
    self.node:send_info ( "send iw link for " .. ( self.iface or "none" ) )
    if ( self.iface ~= nil ) then
        local content, exit_code = misc.execute ( "iw", "dev", self.iface, "link" )
        --self:send_debug (" " .. ( content or "none" ) )
        --self:send_debug ( "iw link exit code : " .. tostring (exit_code) )
        if ( exit_code > 0 or content == nil) then return nil end
        if ( parse ~= nil and parse == true ) then
            local iwlink = parse_iwlink ( content )
            return iwlink
        else
            return content
        end
    end
end

function WifiIF:set_ani ( enabled )
    self.node:send_info ( "set ani for " .. ( self.phy or "none" ) .. " to " .. tostring ( enabled ) )
    if ( self.phy ~= nil and debugfs ~= nil ) then
        local filename = debugfs .. "/" .. self.phy .. "/" .. "ath9k" .. "/"  .. "ani"
        if ( isFile ( filename ) ) then
            local file = io.open ( filename, "w" )
            if ( file ~= nil ) then
                if ( enabled ) then
                    file:write ( 1 )
                else
                    file:write ( 0 )
                end
            file:close()
            end
        end
    end
end

function WifiIF:set_ldpc ( enabled, proc_version )
    self.node:send_info ( "set ldpc for " .. ( self.phy or "none" ) .. " to " .. tostring ( enabled ) )
    if ( proc_version.system == "LEDE" ) then
        local var = "wireless.radio"
        var = var .. string.sub ( self.phy, 4, string.len ( self.phy ) )
        var = var .. ".ldpc"
        local value = '1'
        if ( enabled == false ) then
            value = '0'
        end
        local _, exit_code = uci.set_var ( var, value )
        return ( exit_code ~= 0 )
    else
        self.node:send_error ("NYI WifiIF set_ldpc")
        return false
    end
end

function WifiIF:list_stations ()
    local stations = debugfs .. "/" .. self.phy .. "/netdev:" .. self.iface .. "/stations/"
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

-- --------------------------
-- regmon stats
-- --------------------------

local fetch_file_bin = "/usr/bin/fetch_file"

function WifiIF:start_regmon_stats ( sampling_rate )
    if ( self.regmon_proc ~= nil ) then
        self.node:send_error ( "Not collecting regmon stats for " 
                               .. self.iface .. ", " .. self.phy .. ". Alraedy running" )
        return nil
    end
    local file = debugfs .. "/" .. self.phy .. "/regmon/register_log"
    if ( not isFile ( file ) ) then
        self.node:send_warning ( "no regmon-stats for " .. self.iface .. ", " .. self.phy )
        self.regmon_proc = nil
        return nil
    end
    self.node:send_info ( "start collecting regmon stats for " .. self.iface .. ", " .. self.phy )
    local pid, stdin, stdout = misc.spawn ( self.lua_bin, fetch_file_bin, "-l", "-i", sampling_rate, file )
    self.regmon_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function WifiIF:get_regmon_stats ()
    if ( self.regmon_proc == nil ) then 
        self.node:send_error ( "no regmon process running" )
        return nil 
    end
    self.node:send_info ( "send regmon-stats" )
    local content = self.regmon_proc.stdout:read ( "*a" )
    self.regmon_proc.stdin:close ()
    self.regmon_proc.stdout:close ()
    self.node:send_info ( string.len ( content ) .. " bytes from regmon" )
    self.regmon_proc = nil
    return content
end

function WifiIF:stop_regmon_stats ()
    if ( self.regmon_proc == nil ) then 
        self.node:send_error ( "no regmon process running" )
        return nil 
    end
    self.node:send_info ( "stop collecting regmon stats with pid " .. self.regmon_proc.pid )
    local exit_code
    if ( self.node:kill ( self.regmon_proc.pid ) ) then
        exit_code = lpc.wait ( self.regmon_proc.pid )
    end
    return exit_code
end

-- --------------------------
-- cpusage
-- --------------------------

local cpusage_bin = "/usr/bin/cpusage_single"

function WifiIF:start_cpusage ()
    if ( self.cpusage_proc ~= nil ) then
        self.node:send_error (" Cpuage not started. Already running.")
        return nil
    end
    self.node:send_info ( "start cpusage" )
    local pid, stdin, stdout = misc.spawn ( cpusage_bin )
    self.cpusage_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function WifiIF:get_cpusage ()
    if ( self.cpusage_proc == nil ) then 
        self.node:send_error ( "no cpusage process running" )
        return nil 
    end
    self.node:send_info ( "send cpusage" )
    local content = self.cpusage_proc.stdout:read ( "*a" )
    self.cpusage_proc.stdin:close ()
    self.cpusage_proc.stdout:close ()
    self.node:send_info ( string.len ( content ) .. " bytes from cpusage" )
    self.cpusage_proc = nil
    return content
end

function WifiIF:stop_cpusage ()
    if ( self.cpusage_proc == nil ) then 
        self.node:send_error ( "no cpusage process running" )
        return nil 
    end
    self.node:send_info ( "stop cpusage with pid " .. self.cpusage_proc.pid )
    local exit_code
    if ( self.node:kill ( self.cpusage_proc.pid ) ) then
        exit_code = lpc.wait ( self.cpusage_proc.pid )
    end
    return exit_code
end

-- --------------------------
-- rc_stats
-- --------------------------

function WifiIF:start_rc_stats ( station, sampling_rate )
    if ( sampling_rate == nil ) then sampling_rate = 500000000 end
    if ( self.rc_stats_procs [ station ] ~= nil ) then
        self.node:send_error ( "rc stats for station " .. station .. " already running" )
        return nil
    end
    self.node:send_info ( "start collecting rc_stats station " .. station 
                          .. " on " .. ( self.iface or "none" ) .. " (" .. ( self.phy or "none" ).. ")" )
    local file = debugfs .. "/" .. self.phy .. "/netdev:" .. self.iface .. "/stations/"
                         .. station .. "/rc_stats_csv"
    if ( isFile ( file ) == true ) then
        local pid, stdin, stdout = misc.spawn ( self.lua_bin, fetch_file_bin, "-i", sampling_rate, file )
        self.rc_stats_procs [ station ] = { pid = pid, stdin = stdin, stdout = stdout }
        self.node:send_info ( "rc stats for station " .. station .. " started with pid: " .. pid )
        return pid
    else
        self.node:send_error ( "rc stats for station " .. station .. " not started. file is missing" )
        self.node:send_debug ( file )
        return nil
    end
end

function WifiIF:get_rc_stats ( station )
    if ( station == nil ) then
        self.node:send_error ( "Cannot send rc_stats because the station argument is nil!" )
        return nil
    end
    self.node:send_info ( "send rc-stats for " .. self.iface ..  ", station " .. station )
    if ( self.rc_stats_procs [ station ] == nil ) then 
        self.node:send_warning ( " no rc-stats for " .. station .. " found" )
        return nil 
    end
    self.node:send_debug ( "rc_stats process: " .. self.rc_stats_procs [ station ].pid )
    local content = self.rc_stats_procs [ station ].stdout:read ("*a")
    self.rc_stats_procs [ station ].stdin:close()
    self.rc_stats_procs [ station ].stdout:close()
    self.node:send_info ( string.len ( content ) .. " bytes from rc_stats" )
    self.rc_stats_procs [ station ] = nil
    return content 
end

function WifiIF:stop_rc_stats ( station )
    if ( self.rc_stats_procs [ station ] == nil 
        or self.rc_stats_procs [ station ].pid == nil ) then 
        self.node:send_error ( " rc_stats for station " .. ( station or "unset" ) .. " is not running!" )
        return nil
    end
    self.node:send_info ( "stop collecting rc stats with pid " .. self.rc_stats_procs [ station ].pid )
    local exit_code
    if ( self.node:kill ( self.rc_stats_procs [ station ].pid ) ) then
        exit_code = lpc.wait ( self.rc_stats_procs [ station ].pid )
    end
    return exit_code
end

-- --------------------------
-- tcpdump
-- --------------------------

-- todo: add phy to pcap fname

local tcpdump_bin = "/usr/sbin/tcpdump"

-- -U packet-buffered output instead of line buffered (-l)
-- tcpdump -l -w - | tee -a file
-- tcpdump -i mon0 -s 150 -U
--  -B capture buffer size
--  -s snapshot length ( default 262144)
function WifiIF:start_tcpdump ( fname )
    if ( self.tcpdump_proc ~= nil ) then
        self.node:send_error (" Tcpdump not started. Already running.")
        return nil
    end
    --local snaplen = 0 -- 262144
    local snaplen = 150
    --local snaplen = 256
    self.node:send_info ( "start tcpdump for " .. ( self.mon or "none" ) .. " writing to " .. ( fname or "none" ) )
    self.node:send_debug ( tcpdump_bin .. " -i " .. ( self.mon or "none" ) 
                           .. " -s " .. ( snaplen or "none" ) .. " -U -w " .. ( fname or "none" ) )
    local pid, stdin, stdout = misc.spawn ( tcpdump_bin, "-i", self.mon, "-s", snaplen, "-U", "-w", fname )
    self.tcpdump_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function WifiIF:get_tcpdump_offline ( fname )
    self.node:send_info ( "send tcpdump offline for file " .. ( fname or "none" ) )
    local file = io.open ( fname, "rb" )
    if ( file == nil ) then 
        self.node:send_error ( "no tcpdump file found" )
        return nil 
    end
    local content = file:read ( "*a" )
    file:close ()
    self.node:send_info ( "remove tcpump pcap file " .. ( fname or "none" ) )
    os.remove ( fname )
    self.tcpdump_proc.stdin:close ()
    self.tcpdump_proc.stdout:close ()
    self.tcpdump_proc = nil
    return content
end

function WifiIF:stop_tcpdump ()
    if ( self.tcpdump_proc == nil ) then
        self.node:send_error ( "No tcpdump running." )
        return nil
    end
    self.node:send_info ( "stop tcpdump with pid " .. self.tcpdump_proc.pid )
    local exit_code
    if ( self.node:kill ( self.tcpdump_proc.pid ) ) then
        exit_code = lpc.wait ( self.tcpdump_proc.pid )
    end
    return exit_code
end

-- --------------------------
-- iperf
-- --------------------------

local iperf_bin = "/usr/bin/iperf"

function WifiIF:start_tcp_iperf_s ( iperf_port )
    if ( self.iperf_server_proc ~= nil ) then
        self.node:send_error (" Iperf Server (tcp) not started. Already running.")
        return nil
    end
    self.node:send_info ( "start TCP iperf server at port " .. ( iperf_port or "none" ) )
    self.node:send_debug ( iperf_bin .. " -s -p " .. ( iperf_port or "none" ) )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-s", "-p", iperf_port )
    self.iperf_server_proc = { pid = pid, stdin = stdin, stdout = stdout }
    --local out = misc.read_nonblock ( self.iperf_server_proc.stdout, 500, 1024 )
    --if ( out ~= nil ) then
    --    self.node:send_info ( out )
    --end
    return pid
end

-- iperf -s -u -p 12000
function WifiIF:start_udp_iperf_s ( iperf_port )
    if ( self.iperf_server_proc ~= nil ) then
        self.node:send_error (" Iperf Server (udp) not started. Already running.")
        return nil
    end
    self.node:send_info ( "start UDP iperf server at port " .. ( iperf_port or "none" ) )
    self.node:send_debug ( iperf_bin .. " -s -u -p " .. ( iperf_port or "none" ) )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-s", "-u", "-p", iperf_port )
    self.iperf_server_proc = { pid = pid, stdin = stdin, stdout = stdout }
    --local out = misc.read_nonblock ( self.iperf_server_proc.stdout, 500, 1024 )
    --if ( out ~= nil ) then
    --    self.node:send_info ( out )
    --end
    return pid
end

-- iperf -c 192.168.1.240 -p 12000 -n 500MB
function WifiIF:run_tcp_iperf ( iperf_port, addr, tcpdata, wait )
    if ( addr == nil ) then
        self.node:send_error (" Iperf client (tcp) not started. Address is unset" )
        return nil
    end
    if ( self.iperf_client_procs [ addr ] ~= nil ) then
        self.node:send_error (" Iperf client (tcp) not started for address " .. addr .. ". Already running." )
        return nil
    end
    self.node:send_info ( "run TCP iperf at port " .. ( iperf_port or "none" )
                                .. " to addr " .. addr 
                                .. " with tcpdata " .. ( tcpdata or "none" ) )
    self.node:send_debug ( iperf_bin .. " -c " .. addr .. " -p " .. ( iperf_port or "none" ) .. " -n " .. tcpdata )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-c", addr, "-p", iperf_port, "-n", tcpdata )
    self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    local exit_code
    local out
    if ( wait == true ) then
        exit_code = lpc.wait ( pid )
        out = misc.read_nonblock ( self.iperf_client_procs [ addr ].stdout, 500, 1024 )
        if ( out ~= nil ) then
            self.node:send_info ( out )
        end
        self.iperf_client_procs [ addr ].stdin:close ()
        self.iperf_client_procs [ addr ].stdout:close ()
        self.iperf_client_procs [ addr ] = nil
    end
    return pid, exit_code, out
end

-- rate: bitrate of data generation, i.e. "10M"
-- duration: duration of sending data, i.e. "10" for 10 seconds
-- amount: amount of data in bytes, i.e. 10485760 for 10MB
function WifiIF:run_udp_iperf ( iperf_port, addr, rate, duration, amount, wait )
    if ( addr == nil ) then
        self.node:send_error (" Iperf client (udp) not started. Address is unset" )
        return nil
    end
    if ( self.iperf_client_procs [ addr ] ~= nil ) then
        self.node:send_error (" Iperf client (udp) not started for address " .. addr .. ". Already running." )
        return nil
    end
    if ( duration ~= nil ) then
        self.node:send_info ( "run UDP iperf at port " .. ( iperf_port or "none" )
                                    .. " to addr " .. ( addr or "none" )
                                    .. " with rate " .. rate .. " and duration " .. duration )
        self.node:send_debug ( iperf_bin .. " -u" .. " -c " .. addr .. " -p " .. ( iperf_port or "none" )
                            .. " -b " .. rate .. " -t " .. duration )

        local pid, stdin, stdout = misc.spawn ( iperf_bin, "-u", "-c", addr, "-p", iperf_port,
                                                "-b", rate, "-t", duration )
        self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    elseif ( amount ~= nil ) then
        self.node:send_info ( "run UDP iperf at port " .. ( iperf_port or "none" )
                                    .. " to addr " .. ( addr or "none" )
                                    .. " with rate " .. rate .. " and amount " .. amount )
        self.node:send_debug ( iperf_bin .. " -u" .. " -c " .. addr .. " -p " .. ( iperf_port or "none" )
                            .. " -b " .. rate .. " -n " .. amount )

        local pid, stdin, stdout = misc.spawn ( iperf_bin, "-u", "-c", addr, "-p", iperf_port,
                                                "-b", rate, "-n", amount )
        self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    else
        self.node:send_error (" Iperf client (udp) not started. No duration and no amount set." )
        return nil
    end
    local exit_code
    local out
    if ( wait == true ) then
        exit_code = lpc.wait ( pid )
        out = misc.read_nonblock ( self.iperf_client_procs [ addr ].stdout, 500, 1024 )
        if ( out ~= nil ) then
            self.node:send_info ( out )
        end
        self.iperf_client_procs [ addr ].stdin:close ()
        self.iperf_client_procs [ addr ].stdout:close ()
        self.iperf_client_procs [ addr ] = nil
    end
    return pid, exit_code, out
end

-- iperf -c 224.0.67.0 -u -T 32 -t 3 -i 1 -B 192.168.1.1
-- iperf -c 224.0.67.0 -u --ttl 1 -t 120 -b 100M -l 1500 -B 10.10.250.2
-- iperf -u -c 224.0.67.0 -p 12000 -T 32 -t 10 -b 1MB -B 192.168.1.1
function WifiIF:run_multicast ( iperf_port, addr, multicast_addr, ttl, bitrate, duration, wait )
    if ( addr == nil ) then
        self.node:send_error (" Iperf client (multicast) not started. Address is unset" )
        return nil
    end
    if ( self.iperf_client_procs [ addr ] ~= nil ) then
        self.node:send_error (" Iperf client (mcast) not started for address " .. addr .. ". Already running.")
        return nil
    end
    self.node:send_info ( "run UDP iperf at port " .. ( iperf_port or "none" )
                                .. " to addr " .. addr 
                                .. " with ttl and duration " .. ttl .. ", " .. duration )
    self.node:send_debug ( iperf_bin .. " -u " .. " -c " .. multicast_addr  .. " -p " .. ( iperf_port or "none" )
                                .. " -T " .. ttl .. " -t " .. duration .. " -b " .. bitrate .. " -B " .. addr )
    local pid, stdin, stdout = misc.spawn ( iperf_bin, "-u", "-c", multicast_addr, "-p", iperf_port,
                                         "-T", ttl, "-t", duration, "-b", bitrate, "-B", addr )
    self.iperf_client_procs [ addr ] = { pid = pid, stdin = stdin, stdout = stdout }
    local exit_code
    local out
    if ( wait == true ) then
        exit_code = lpc.wait ( pid )
        out = misc.read_nonblock ( self.iperf_client_procs [ addr ].stdout, 500, 1024 )
        if ( out ~= nil ) then
            self.node:send_info ( out )
        end
        self.iperf_client_procs [ addr ].stdin:close ()
        self.iperf_client_procs [ addr ].stdout:close ()
        self.iperf_client_procs [ addr ] = nil
    end
    return pid, exit_code, out
end

function WifiIF:wait_iperf_c ( addr )
    if ( addr == nil ) then
        self.node:send_error ( " wait for iperf client failed, addr is not set." )
        return
    end
    if ( self.iperf_client_procs [ addr ] == nil ) then
        self.node:send_error ( " iperf client is not running." )
        return
    end
    self.node:send_info ( "wait for TCP/UDP client iperf for address " .. addr ) 
    local exit_code = lpc.wait ( self.iperf_client_procs [ addr ].pid )
    local out = misc.read_nonblock ( self.iperf_client_procs [ addr ].stdout, 500, 1024 )
    if ( out ~= nil ) then
        self.node:send_info ( out )
    end
    self.iperf_client_procs [ addr ].stdin:close ()
    self.iperf_client_procs [ addr ].stdout:close ()
    self.iperf_client_procs [ addr ] = nil
    return exit_code, out
end

function WifiIF:stop_iperf_server ()
    if ( self.iperf_server_proc == nil ) then
        self.node:send_error ( " iperf server is not running." )
        return
    end
    self.node:send_info ( "stop iperf server with pid " .. self.iperf_server_proc.pid )
    local exit_code
    if ( self.node:kill ( self.iperf_server_proc.pid, posix.signal.SIGKILL ) ) then
        exit_code = lpc.wait ( self.iperf_server_proc.pid )
    end
    local out = misc.read_nonblock ( self.iperf_server_proc.stdout, 500, 1024 )
    if ( out ~= nil ) then
        self.node:send_info ( out )
    end
    self.iperf_server_proc.stdin:close ()
    self.iperf_server_proc.stdout:close ()
    self.iperf_server_proc = nil
    return exit_code, out
end
