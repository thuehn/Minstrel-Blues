-- run a single measurement between one station (STA) and one access point (AP)

-- TODO:
-- - openwrt package: split luarpc from measurement package 
-- - openwrt package: fetch sources for luarpc and lua-ex with git
-- - openwrt package for argparse
-- - rpc: transfer tcpdump binary lines/packages (broken)
-- - scp: store public ssh keys of all control devices on each ap/sta node
-- - analyse pcap
-- - create NodeCTRL, NodeAPRef, NodeSTARef

require ('functional') -- head
local argparse = require "argparse"
require "NetIF"
require ("rpc")
require ("spawn_pipe")
require ("parsers/ex_process")
require ('parsers/cpusage')
require ('pcap')
require ('misc')

function reachable ( ip ) 
    local ping = spawn_pipe("ping", "-c1", ip)
    local exitcode = ping['proc']:wait()
    return exitcode == 0
end

local parser = argparse("singleRun", "Run minstrel blues single AP/STA mesurement")

-- TODO: use networks instead of hosts, each ap

parser:option ("-c --config", "config file name", nil)

parser:option ("--sta_wifi_ip", "STA Wifi IP-Address")
parser:option ("--sta_wifi_if", "STA Wifi Interface")
parser:option ("--sta_wifi_mon", "STA Wifi Monitor Interface")

parser:option ("--sta_ctrl_ip", "STA Control IP-Address")
parser:option ("--sta_ctrl_if", "STA Control Interface")


parser:option ("--ap_wifi_ip", "AP Wifi IP-Address")
parser:option ("--ap_wifi_if", "AP Wifi Interface")
parser:option ("--ap_wifi_mon", "AP Wifi Interface")

parser:option ("--ap_ctrl_ip", "AP Control IP-Address")
parser:option ("--ap_ctrl_if", "AP Control Monitor Interface")

parser:option ("--ctrl_port", "Port for control RPC", "12346" )

parser:option ("--log_ip", "IP of Logging node" )
parser:option ("-L --log_port", "Logging RPC port", "12347" )

parser:flag ("--disable_ani", "Runs experiment with ani disabled", false )

parser:option ("-t --tcpdata", "Amount of TCP data", "500MB" )
parser:option ("-s --packet_sizes", "Amount of UDP data", "1500" )
parser:option ("-r --packet_rates", "Rates of UDP data", "50,200,600,1200" )
parser:option ("-i --cct_intervals", "send iperf traffic intervals in milliseconds", "20000,50,100,1000" )
parser:option ("--interval", "Intervals of TCP and UDP data", "240" )

parser:flag ("--disable_reachable", "Don't try to test the reachability of nodes", false )
parser:flag ("--disable_autostart", "Don't try to start nodes via ssh", false )

parser:flag ("--dry_run", "Don't measure anything", false )

local args = parser:parse()

function show_config_error( option )
    print ( parser:get_usage() )
    print ( )
    print ( "Error: option '--" .. option .. "' missing and no config file specified")
    os.exit()
end

stations = {}
aps = {}

nodes = {}
for _,v in ipairs(stations) do nodes[#nodes+1] = v end
for _,v in ipairs(aps) do nodes[#nodes+1] = v end

function find_node( name, nodes ) 
    for _,node in ipairs(nodes) do 
        if node.name == name then return node end 
    end
    return nil
end

-- load config from a file
-- (loadfile, dofile, loadstring)  
if (args.config ~= nil) then
    require(string.sub(args.config,1,#args.config-4))
    if (table_size ( stations ) ~= 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain one station node description in var 'stations'. " .. count)
        os.exit()
    end
    if (table_size ( aps ) ~= 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain one access point node description in var 'aps'. " .. count)
        os.exit()
    end
    local ap = find_node( "AP", aps )
    if (ap == nil) then
        print ( "Error: config file '" .. args.config .. "' have to specify a node named 'AP' in the 'nodes' table. " .. count)
        os.exit()
    end
    local sta = find_node ( "STA", stations )
    if (sta == nil) then
        print ( "Error: config file '" .. args.config .. "' have to specify a node named 'STA' in the 'nodes' table. " .. count)
        os.exit()
    end
    -- overwrite config file setting with command line settings
    if (args.ap_wifi_if ~= nil) then ap.wifi_if = args.ap_wifi_if end 
    if (args.ap_wifi_ip ~= nil) then ap.wifi_ip = args.ap_wifi_ip end 
    if (args.ap_wifi_mon ~= nil) then ap.wifi_mon = args.ap_wifi_mon end 
    if (args.ap_ctrl_if ~= nil) then ap.ctrl_if = args.ap_ctrl_if end 
    if (args.ap_ctrl_ip ~= nil) then ap.ctrl_ip = args.ap_ctrl_ip end 

    if (args.sta_wifi_if ~= nil) then sta.wifi_if = args.sta_wifi_if end 
    if (args.sta_wifi_ip ~= nil) then sta.wifi_ip = args.sta_wifi_ip end 
    if (args.sta_wifi_mon ~= nil) then sta.wifi_mon = args.sta_wifi_mon end 
    if (args.sta_ctrl_if ~= nil) then sta.ctrl_if = args.sta_ctrl_if end 
    if (args.sta_ctrl_ip ~= nil) then sta.ctrl_ip = args.sta_ctrl_ip end 
else
    if (args.ap_wifi_if == nil) then show_config_error ( "ap_wifi_if") end
    if (args.ap_wifi_ip == nil) then show_config_error ( "ap_wifi_ip") end
    if (args.ap_wifi_mon == nil) then show_config_error ( "ap_wifi_mon") end
    if (args.ap_ctrl_if == nil) then show_config_error ( "ap_ctrl_if") end
    if (args.ap_ctrl_ip == nil) then show_config_error ( "ap_ctrl_ip") end

    if (args.sta_wifi_if == nil) then show_config_error ( "sta_wifi_if") end
    if (args.sta_wifi_ip == nil) then show_config_error ( "sta_wifi_ip") end
    if (args.sta_wifi_mon == nil) then show_config_error ( "sta_wifi_mon") end
    if (args.sta_ctrl_if == nil) then show_config_error ( "sta_ctrl_if") end
    if (args.sta_ctrl_ip == nil) then show_config_error ( "sta_ctrl_ip") end

    aps[1] = { name = "AP"
             , wifi_if = args.ap_wifi_if
             , wifi_ip = args.ap_wifi_ip
             , wifi_mon = args.ap_wifi_mon
             , ctrl_if = args.ap_ctrl_if
             , ctrl_ip = args.ap_ctrl_ip
             , ctrl_if = args.ap_ctrl_if
             }
    stations[1] = { name = "STA"
                  , wifi_if = args.sta_wifi_if
                  , wifi_ip = args.sta_wifi_ip
                  , wifi_mon = args.sta_wifi_mon
                  , ctrl_if = args.sta_ctrl_if
                  , ctrl_ip = args.sta_ctrl_ip
                  , ctrl_if = args.sta_ctrl_if
                  }
    nodes[1] = aps[1]
    nodes[2] = stations[1]
end

local ap_node = find_node( "AP", aps )
local sta_node = find_node ( "STA", stations )

-- new class Node (NetIF x NetIF)
local sta_wifi = NetIF:create("STA wifi", sta_node['wifi_if'], sta_node['wifi_ip'], sta_node['wifi_mon'])
local sta_ctrl = NetIF:create("STA ctrl", sta_node['ctrl_if'], sta_node['ctrl_ip'], nil)
local sta = { }
sta['wifi'] = sta_wifi
sta['ctrl'] = sta_ctrl

local ap_wifi = NetIF:create("AP wifi", ap_node['wifi_if'], ap_node['wifi_ip'], ap_node['wifi_mon'])
local ap_ctrl = NetIF:create("AP ctrl", ap_node['ctrl_if'], ap_node['ctrl_ip'], nil)
local ap = { }
ap['wifi'] = ap_wifi
ap['ctrl'] = ap_ctrl

-- print configuration
print("Configuration:")
print("==============")
print()
print (sta_wifi)
print (sta_ctrl)
print (ap_wifi)
print (ap_ctrl)
print()


function connect_node ( addr, port )
    function connect ()
        local l, e = rpc.connect ( addr, port )
        return l, e
    end
    local status, slave, err = pcall ( connect )
    if (status == false) then
        print ( "Err: Connection to node failed" )
        print ( "Err: no node at address: " .. addr .. " on port: " .. port )
        return nil
    else
        return slave
    end
end

-- check reachability 
local reached = {}
if (args.disable_reachable == false) then
    for _, node in ipairs ( { ap_node, sta_node } ) do
        if reachable ( node.ctrl_ip ) then
            reached[node.name] = true
            print ( node.name .. ": ONLINE" )
        else
            reached[node.name] = false
            print ( tostring(node.name) .. ": OFFLINE" )
            os.exit(1)
        end
    end
end
print ()

-- and auto start nodes
if (args.disable_autostart == false) then
    for _, node in ipairs ( { ap_node, sta_node } ) do
        if ( reached[node.name] ) then
            local remote_cmd = "lua runNode.lua"
                        .. " --name " .. node.name 
                        .. " --wifi_ip " .. node.wifi_ip
                        .. " --ctrl_ip " .. node.ctrl_ip
                        .. " --log_ip " .. args.log_ip 
            print ( remote_cmd )
            local ssh = spawn_pipe("ssh", "root@" .. node.ctrl_ip, remote_cmd)
--[[        local exit_code = ssh['proc']:wait()
            if (exit_code == 0) then
                print (node.name .. ": node started" )
            else
                print (node.name .. ": node not started, exit code: " .. exit_code)
                print ( ssh['err']:read("*all") )
                os.exit(1)
            end --]]
        end
    end
    print ("wait a second for nodes initialisation")
    os.sleep (4)
end

if rpc.mode ~= "tcpip" then
    print ( "Err: rpc mode tcp/ip is supported only" )
    os.exit(1)
end

ap_slave = connect_node (ap_ctrl.addr, args.ctrl_port)
sta_slave = connect_node (sta_ctrl.addr, args.ctrl_port)

if ( ap_slave == nil or sta_slave == nil) then
    print ("connection failed!")
    os.exit(1)
end

print()

local sta_mac = sta_slave.get_mac ( sta_wifi.iface )
if ( sta_mac ~= nil) then
    print ("STA mac: " ..  sta_mac)
else
    print ("STA mac: no ipv4 assigned?")
end
local sta_addr = sta_slave.get_addr ( sta_wifi.iface )
if ( sta_addr ~= nil ) then
    print ("STA addr: " ..  sta_addr)
else
    print ("STA addr: no ipv4 assigned")
    if ( sta_mac ~= nil ) then
        local addr = ap_slave.has_lease ( sta_mac )
        if ( addr ~= nil ) then
            print ("STA addr (ap lease): " ..  sta_addr)
        end
    end
end
print()

local ap_mac = ap_slave.get_mac ( "br-lan" )
if ( ap_mac ~= nil) then
    print ("AP mac: " ..  ap_mac)
else
    print ("AP mac: no ipv4 assigned")
end
local ap_addr = ap_slave.get_addr ( "br-lan" )
if ( ap_addr ~= nil ) then
    print ("AP addr: " ..  ap_addr)
else
    print ("AP addr: no ipv4 assigned")
end
print()
local ap_phys = ap_slave.wifi_devices()
local sta_phys = sta_slave.wifi_devices()

local phy_str = ""
for _, phy in ipairs ( ap_phys ) do
    if (phy_str == "") then 
        phy_str = phy_str .. phy
    else 
        phy_str = phy_str .. "," .. phy 
    end
end
print ("AP wifi devices: " .. phy_str)

local phy_str = ""
for _, phy in ipairs ( sta_phys ) do
    if (phy_str == "") then 
        phy_str = phy_str .. phy
    else 
        phy_str = phy_str .. "," .. phy 
    end
end
print ("STA wifi devices: " .. phy_str)
print ()

local ssid = ap_slave.get_ssid( ap_node.wifi_if )
print (ssid)
print ()

print ( "STATIONS on " .. ap_wifi.iface)
print ( "==================")
print ( )
local wifi_stations = ap_slave.stations( ap_phys[1] )
for _, station in ipairs ( wifi_stations ) do
    print ( station )
    print ("-----------------")
end
print ()

-- check whether station is connected
-- got the right station? query mac from STA
if ( table_size ( wifi_stations ) < 1 ) then
    print ("no station connected with access point")
    os.exit(1)
end

if (args.dry_run) then 
    print ( "dry run is set, quit here" )
    os.exit(1)
end

ap_slave.add_monitor( ap_phys[1] )
sta_slave.add_monitor( sta_phys[1] )

ap_slave.set_ani ( ap_phys[1], not args.disable_ani )
sta_slave.set_ani ( sta_phys[1], not args.disable_ani )

local regmon_stats = {}
local rc_stats = {}
for _, station in ipairs ( wifi_stations ) do
    rc_stats[ station ] = {}
end
local cpusage_stats = {}
local tcpdump_pcaps = {}

local size = head ( split ( args.packet_sizes, "," ) )
local runs = 1
for _,interval in ipairs ( split( args.cct_intervals, ",") ) do

    -- fixme: attenuate
    -- https://github.com/thuehn/Labbrick_Digital_Attenuator

    for _,rate in ipairs ( split( args.packet_rates, ",") ) do

        for run = 1, runs do

            local key = tostring(rate) .. "-" .. tostring(interval) .. "-" .. tostring(run)

            print ( "run iperf with size, rate, interval " .. size .. ", " .. rate .. ", " .. interval )

            -- start udp iperf server on STA
            local iperf_s_proc_str = sta_slave.start_udp_iperf_s()
            local iperf_s_proc = parse_process ( iperf_s_proc_str )
            --print ( "IPERF_s pid: " .. iperf_s_proc['pid'])
            
            -- restart wifi on STA
            local succ = sta_slave.restart_wifi()
            if (succ) then
                print ("wifi on STA restarted")
            else
                print ("restart wifi on STA failed")
            end

            -- add monitor on STA
            sta_slave.add_monitor( sta_phys[1] )

            repeat
                print ("wait for stations to come up ... ")
                os.sleep(1)
                local wifi_stations_cur = ap_slave.stations( ap_phys[1] )
                local miss = false
                for _, str in ipairs ( wifi_stations ) do
                    if ( table.contains ( wifi_stations_cur, str ) == false ) then
                        miss = true
                        break
                    end
                end
            until miss

            local connected = false
            repeat
                local ssid = sta_slave.get_linked_ssid ( sta_wifi.iface )
                if (ssid == nil) then 
                    print ("Warning: station not connected")
                    os.sleep (1)
                else
                    print ("station connected to " .. ssid)
                    connected = true
                end
            until connected

            print ("start measurement")

            -- -------------------------------
            -- start measurement on AP and STA
            -- -------------------------------
            
            -- regmon stats
            local regmon_proc_str = ap_slave.start_regmon_stats ( ap_phys[1] )
            local regmon_proc = nil
            if ( regmon_proc_str ~= nil ) then
                regmon_proc = parse_process ( regmon_proc_str )
            end

            -- rc stats
            local rc_stats_procs = ap_slave.start_rc_stats ( ap_phys[1] )
            local rc_procs = {}
            for _, rc_proc_str in ipairs ( rc_stats_procs ) do
                rc_procs [ #rc_procs + 1 ] = parse_process ( rc_proc_str )
            end

            -- cpusage stats
            local cpusage_proc_str = ap_slave.start_cpusage()
            local cpusage_proc = parse_process ( cpusage_proc_str )

            local tcpdump_fname = "/tmp/" .. key .. ".pcap"
            local tcpdump_proc_str = ap_slave.start_tcpdump( tcpdump_fname )
            local tcpdump_proc = parse_process ( tcpdump_proc_str )
            -- print ( "TCPDUMP pid: " .. tcpdump_proc['pid'])

            -- -------------------------------------------------------
            -- Measurement
            -- -------------------------------------------------------

            -- start iperf client on AP
            local iperf_c_proc_str = ap_slave.run_udp_iperf( size, rate, args.interval )
            --print (iperf_c_proc_str)
            --local iperf_c_proc = parse_process( iperf_c_proc_str )
            --print ( "IPERF_c pid: " .. iperf_c_proc['pid'])

            
            -- -------------------------------
            -- stop measurement on AP and STA
            -- -------------------------------
            
            -- regmon 
            if ( regmon_proc ~= nil) then
                ap_slave.stop_regmon_stats( regmon_proc['pid'] )
            end
            -- rc_stats
            for _, rc_proc in ipairs ( rc_procs ) do
                ap_slave.stop_rc_stats( rc_proc['pid'] )
            end

            -- cpusage
            -- stop cpuage before reading, because io:read wait for closed pipe
            ap_slave.stop_cpusage( cpusage_proc['pid'] )

            -- stop iperf server on STA
            sta_slave.stop_iperf_server( iperf_s_proc['pid'] )

            -- stop pcap tracing
            local exit_code = ap_slave.stop_tcpdump( tcpdump_proc['pid'] )


            -- ------------------------
            -- collect traces
            -- ------------------------

            -- regmon 
            regmon_stats [ key ] = ap_slave.get_regmon_stats()
            
            -- rc_stats
            for _, station in ipairs ( wifi_stations ) do
                rc_stats [ station ] [ key ] = ap_slave.get_rc_stats ( station )
            end
            
            -- cpusage
            cpusage_stats [ key ] = ap_slave.get_cpusage()

            -- tcpdump
            tcpdump_pcaps[ key ] = ap_slave.get_tcpdump_offline ( tcpdump_fname )

        end -- run

    end -- rate

    -- fixme: stop attenuate

end -- cct

-- regmon stats
-- print ( tostring ( table_size ( regmon_stats ) ) )
for key, stat in pairs ( regmon_stats ) do
    print ( "regmon-" .. key .. ": " .. string.len(stat) .. " bytes" )
    --print (stat)
end

-- rc_stats
for _, station in ipairs ( wifi_stations ) do
    if ( rc_stats ~= nil and rc_stats [ station ] ~= nil) then
        for key, stat in pairs ( rc_stats [ station ] ) do
            print ( "rc_stats-" .. station .. "-" .. key .. ": " .. string.len(stat) .. " bytes" )
            -- if (stat ~= nil) then print (stat) end
        end
    end
end

-- cpusage stats
for key, stat in pairs ( cpusage_stats ) do
    print ( "cpusage_stats-" .. key .. ": " .. string.len(stat) .. " bytes" )
    for _, str in ipairs ( split ( stat, "\n" ) ) do
        local cpustat = parse_cpusage ( str )
--        print (cpustat)
    end
end

-- tcpdump pcap
for key, stats in pairs ( tcpdump_pcaps ) do
    print ( "tcpdump_pcap-" .. key .. ": " )
    local fname = "/tmp/" .. key .. ".pcap"
    local file = io.open(fname, "wb")
    file:write ( stats )
    file:close()
    cap = pcap.open_offline( fname )
    if (cap ~= nil) then
        -- cap:set_filter(filter, nooptimize)

        for capdata, timestamp, wirelen in cap.next, cap do
            print(timestamp, wirelen, #capdata)
        end

        cap:close()
    else
        print ("pcap open failed: " .. fname)
    end
end

-- for _ in 1, runs do
--  start tcp iperf server on STA
--  restart wifi on STA
--  add monitor on STA
--  start measurement on STA and AP
--  start iperf client on AP
--  stop measurement on STA and AP
--  stop iperd serber on AP and STA
-- end

-- query lua pid before closing rpc connection
-- maybe to kill nodes later
local pids = {}
pids[1] = ap_slave.get_pid()
pids[2] = sta_slave.get_pid()

rpc.close(ap_slave)
rpc.close(sta_slave)

-- kill nodes if desired by the user
if (args.disable_autostart == false) then
    for i, node in ipairs ( { ap_node, sta_node } ) do -- fixme: zip nodes with pids
        local ssh = spawn_pipe("ssh", "root@" .. node.ctrl_ip, "kill " .. pids[i])
        local exit_code = ssh['proc']:wait()
    end
end

