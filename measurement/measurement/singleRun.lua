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
require ('NetIF')
require ('AccessPointRef')
require ('StationRef')
require ("rpc")
require ("spawn_pipe")
require ("parsers/ex_process")
require ('parsers/cpusage')
require ('pcap')
require ('misc')
require ('Measurement')

function reachable ( ip ) 
    local ping = spawn_pipe("ping", "-c1", ip)
    local exitcode = ping['proc']:wait()
    close_proc_pipes ( ping )
    return exitcode == 0
end

local parser = argparse("singleRun", "Run minstrel blues single AP/STA mesurement")

-- TODO: use networks instead of hosts, each ap

parser:option ("-c --config", "config file name", nil)

parser:option ("--sta_radio", "STA Wifi Interface name", "radio0")

parser:option ("--sta_ctrl_ip", "STA Control IP-Address")
parser:option ("--sta_ctrl_if", "STA Control Interface")


parser:option ("--ap_radio", "AP Wifi Interface name", "radio0")

parser:option ("--ap_ctrl_ip", "AP Control IP-Address")
parser:option ("--ap_ctrl_if", "AP Control Monitor Interface")

parser:option ("--ctrl_port", "Port for control RPC", "12346" )

parser:option ("--log_ip", "IP of Logging node" )
parser:option ("-L --log_port", "Logging RPC port", "12347" )
parser:option ("-l --log_file", "Logging to File", "/tmp/measurement.log" )

parser:flag ("--disable_ani", "Runs experiment with ani disabled", false )

parser:option ("--runs", "Number of iterations", "1" )
parser:option ("-t --tcpdata", "Amount of TCP data", "500MB" )
parser:option ("-s --packet_sizes", "Amount of UDP data", "1500" )
parser:option ("-r --packet_rates", "Rates of UDP data", "50,200,600,1200" )
parser:option ("-i --cct_intervals", "send iperf traffic intervals in milliseconds", "20000,50,100,1000" )
parser:option ("--interval", "Intervals of TCP and UDP data", "1" )

parser:flag ("--disable_reachable", "Don't try to test the reachability of nodes", false )
parser:flag ("--disable_autostart", "Don't try to start nodes via ssh", false )

parser:flag ("--dry_run", "Don't measure anything", false )
parser:flag ("--udp_only", "Measure tcp", false )
parser:flag ("--tcp_only", "Measure udp", false )
parser:flag ("--multicast_only", "Measure multicast", false )

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
for _,v in ipairs(stations) do nodes [ #nodes + 1 ] = v end
for _,v in ipairs(aps) do nodes [ #nodes + 1 ] = v end

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
    if (args.ap_radio ~= nil) then ap.radio = args.ap_radio end 
    if (args.ap_ctrl_if ~= nil) then ap.ctrl_if = args.ap_ctrl_if end 
    if (args.ap_ctrl_ip ~= nil) then ap.ctrl_ip = args.ap_ctrl_ip end 

    if (args.sta_radio ~= nil) then sta.radio = args.sta_radio end 
    if (args.sta_ctrl_if ~= nil) then sta.ctrl_if = args.sta_ctrl_if end 
    if (args.sta_ctrl_ip ~= nil) then sta.ctrl_ip = args.sta_ctrl_ip end 
else
    if (args.ap_radio == nil) then show_config_error ( "ap_radio") end
    if (args.ap_ctrl_if == nil) then show_config_error ( "ap_ctrl_if") end
    if (args.ap_ctrl_ip == nil) then show_config_error ( "ap_ctrl_ip") end

    if (args.sta_radio == nil) then show_config_error ( "sta_radio") end
    if (args.sta_ctrl_if == nil) then show_config_error ( "sta_ctrl_if") end
    if (args.sta_ctrl_ip == nil) then show_config_error ( "sta_ctrl_ip") end

    aps[1] = { name = "AP"
             , radio = args.ap_radio
             , ctrl_if = args.ap_ctrl_if
             , ctrl_ip = args.ap_ctrl_ip
             , ctrl_if = args.ap_ctrl_if
             }
    stations[1] = { name = "STA"
                  , radio = args.sta_radio
                  , ctrl_if = args.sta_ctrl_if
                  , ctrl_ip = args.sta_ctrl_ip
                  , ctrl_if = args.sta_ctrl_if
                  }
    nodes[1] = aps[1]
    nodes[2] = stations[1]
end

function start_logger ( port )
    local logger = spawn_pipe ( "lua", "bin/Logger.lua", args.log_file, "--port", port )
    if ( logger ['err_msg'] ~= nil ) then
        print("Logger not started" .. logger ['err_msg'] )
    end
    close_proc_pipes ( logger )
    local str = logger['proc']:__tostring()
    print ( str )
    return parse_process ( str ) 
end

function stop_logger ( pid )
    kill = spawn_pipe("kill", pid)
    close_proc_pipes ( kill )
end

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

function multicast_measurement ( ap_ref, sta_ref, runs, udp_interval, tx_rates, tx_powers )

    local ap_stats = Measurement:create( ap_ref.rpc )
    ap_stats:enable_rc_stats ( ap_ref.stations )
    local sta_stats = Measurement:create( sta_ref.rpc )

    local tx_rates = ap_ref.rpc.tx_rate_indices( ap_ref.wifis[1], ap_ref.stations[1] )
    local tx_powers = {}
    for i = 1, 25 do
        tx_powers[1] = i
    end

    local sta_wifi_addr = sta_ref.rpc.get_addr ( sta_ref.wifis[1] )

    for run = 1, runs do

        for _, tx_rate in ipairs ( tx_rates ) do
            
            for _, tx_power in ipairs ( tx_powers ) do

                local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) .. "-" .. tostring(run)

                -- todo: for all stations

                ap_ref.rpc.set_tx_rate ( ap_ref.wifis[1], ap_ref.stations[1], tx_rate )
                ap_ref.rpc.set_tx_power ( ap_ref.wifis[1], ap_ref.stations[1], tx_power )
    
                -- restart wifi on STA
                sta_ref.rpc.restart_wifi()

                -- add monitor on AP and STA
                ap_ref.rpc.add_monitor( ap_ref.wifis[1] )
                -- fixme: mon0 not created because of too many open files (~650/12505)
                --   -- maybe mon0 already exists
                sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
                wait_linked ( sta_ref.rpc, sta_ref.wifis[1] )

                -- start measurement on STA and AP
                ap_stats:start ( ap_ref.wifis[1], key )
                sta_stats:start ( sta_ref.wifis[1], key )

                -- -------------------------------------------------------
                -- Experiment
                -- -------------------------------------------------------

                -- start iperf client on AP
                local addr = "224.0.67.0"
                local ttl = 32
                local iperf_c_proc_str = ap_ref.rpc.run_multicast( sta_wifi_addr, addr, ttl, udp_interval )

                -- -------------------------------------------------------

                -- stop measurement on STA and AP
                ap_stats:stop ()
                sta_stats:stop ()

                -- collect traces
                ap_stats:fetch ( ap_ref.wifis[1], key )
                sta_stats:fetch ( sta_ref.wifis[1], key )
            end
        end
    end

    return ap_stats, sta_stats
end

function tcp_measurement ( ap_ref, sta_ref, runs, tcpdata )
    
    local ap_stats = Measurement:create( ap_ref.rpc )
    ap_stats:enable_rc_stats ( ap_ref.stations )
    local sta_stats = Measurement:create( sta_ref.rpc )

    local sta_wifi_addr = sta_ref.rpc.get_addr ( sta_ref.wifis[1] )

    for run = 1, runs do

        local key = tostring ( run )

        -- start tcp iperf server on STA
        local iperf_s_proc_str = sta_ref.rpc.start_tcp_iperf_s()
        local iperf_s_proc = parse_process ( iperf_s_proc_str )

        -- restart wifi on STA
        sta_ref.rpc.restart_wifi()

        -- add monitor on AP and STA
        ap_ref.rpc.add_monitor( ap_ref.wifis[1] )
        -- fixme: mon0 not created because of too many open files (~650/12505)
        sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
        wait_linked ( sta_ref.rpc, sta_ref.wifis[1] )

        -- start measurement on STA and AP
        ap_stats:start ( ap_ref.wifis[1], key )
        sta_stats:start ( sta_ref.wifis[1], key )

        -- -------------------------------------------------------
        -- Experiment
        -- -------------------------------------------------------

        -- start iperf client on AP
        local iperf_c_proc_str = ap_ref.rpc.run_tcp_iperf( sta_wifi_addr, tcpdata )

        -- stop measurement on STA and AP
        ap_stats:stop ()
        sta_stats:stop ()

        -- stop iperf server on STA
        sta_ref.rpc.stop_iperf_server( iperf_s_proc['pid'] )
        
        -- collect traces
        ap_stats:fetch ( ap_ref.wifis[1], key )
        sta_stats:fetch ( sta_ref.wifis[1], key )
    end

    return ap_stats, sta_stats
end


function udp_measurement ( ap_ref, sta_ref, runs, packet_sizes, cct_intervals, packet_rates, udp_interval )

    local ap_stats = Measurement:create( ap_ref.rpc )
    ap_stats:enable_rc_stats ( ap_ref.stations )
    local sta_stats = Measurement:create( sta_ref.rpc )

    local sta_wifi_addr = sta_ref.rpc.get_addr ( sta_ref.wifis[1] )

    local size = head ( split ( packet_sizes, "," ) )
    for _,interval in ipairs ( split( cct_intervals, ",") ) do

        -- fixme: attenuate
        -- https://github.com/thuehn/Labbrick_Digital_Attenuator

        for _,rate in ipairs ( split ( packet_rates, ",") ) do

            for run = 1, runs do

                local key = tostring(rate) .. "-" .. tostring(interval) .. "-" .. tostring(run)

                print ( "run iperf with size, rate, interval " .. size .. ", " .. rate .. ", " .. interval )

                -- start udp iperf server on STA
                local iperf_s_proc_str = sta_ref.rpc.start_udp_iperf_s()
                local iperf_s_proc = parse_process ( iperf_s_proc_str )
            
                -- restart wifi on STA
                sta_ref.rpc.restart_wifi()

                -- add monitor on AP and STA
                ap_ref.rpc.add_monitor( ap_ref.wifis[1] )
                sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
                wait_linked ( sta_ref.rpc, sta_ref.wifis[1] )

                print ("start measurement")

                -- start measurement on AP and STA
                ap_stats:start ( ap_ref.wifis[1], key )
                sta_stats:start ( sta_ref.wifis[1], key )

                -- -------------------------------------------------------
                -- Experiment
                -- -------------------------------------------------------

                -- start iperf client on AP
                local iperf_c_proc_str = ap_ref.rpc.run_udp_iperf( sta_wifi_addr, size, rate, udp_interval )

                -- -------------------------------------------------------

                -- stop measurement on AP and STA
                ap_stats:stop ()
                sta_stats:stop ()

                -- stop iperf server on STA
                sta_ref.rpc.stop_iperf_server( iperf_s_proc['pid'] )

                -- collect traces
                ap_stats:fetch ( ap_ref.wifis[1], key )
                sta_stats:fetch ( sta_ref.wifis[1], key )

            end -- run
        end -- rate
        -- fixme: stop attenuate
    end -- cct

    --return ap_stats, sta_stats
    return ap_stats, sta_stats

end

-- waits until all stations appears on ap
-- not precise, sta maybe not really connected afterwards
-- but two or three seconds later
-- not used
function wait_station ( ap_ref )
    repeat
        print ("wait for stations to come up ... ")
        os.sleep(1)
        local wifi_stations_cur = ap_ref.rpc.stations( ap_phys[1] )
        local miss = false
        for _, str in ipairs ( wifi_stations ) do
            if ( table.contains ( wifi_stations_cur, str ) == false ) then
                miss = true
                break
            end
        end
    until miss
end

-- wait for station is linked to ssid
function wait_linked ( sta_rpc, phy )
    local connected = false
    repeat
        local ssid = sta_rpc.get_linked_ssid ( phy )
        if (ssid == nil) then 
            print ("Waiting: station not connected")
            os.sleep (1)
        else
            print ("station connected to " .. ssid)
            connected = true
        end
    until connected
end

-- ---------------------------------------------------------------


local ap_node = find_node ( "AP", aps )
local sta_node = find_node ( "STA", stations )

local sta_ctrl = NetIF:create ("ctrl", sta_node['ctrl_if'], sta_node['ctrl_ip'] )
local sta_ref = StationRef:create ("STA", sta_ctrl )
local sta = {}

local ap_ctrl = NetIF:create ("ctrl", ap_node['ctrl_if'], ap_node['ctrl_ip'] )
local ap_ref = AccessPointRef:create ("AP", ap_ctrl )
local ap = {}

-- print configuration
print ("Configuration:")
print ("==============")
print ()
print (sta_ref)
print (ap_ref)
print ()
print ( "run udp: " .. tostring( args.tcp_only == false and args.tcp_only == false and args.multicast_only == false) )
print ( "run tcp: " .. tostring( args.udp_only == false and args.tcp_only == false and args.multicast_only == false) )
print ( "run multicast: " .. tostring( args.udp_only == false and args.tcp_only == false and args.multicast_only == true) )
print ()

-- autostart logger
local logger_proc
if ( args.disable_autostart == false ) then
    logger_proc = start_logger ( args.log_port )
    if ( logger_proc == nil ) then
        print ("Logger not started.")
        os.exit(1)
    end
end

-- check reachability 
local reached = {}
if ( args.disable_reachable == false ) then
    for _, node in ipairs ( { ap_ref, sta_ref } ) do
        if reachable ( node.ctrl.addr ) then
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
if ( args.disable_autostart == false ) then
    for _, node in ipairs ( { ap_ref, sta_ref } ) do
        if ( reached[node.name] ) then
            local remote_cmd = "lua runNode.lua"
                        .. " --name " .. node.name 
                        .. " --log_ip " .. args.log_ip 
            print ( remote_cmd )
            local ssh = spawn_pipe("ssh", "root@" .. node.ctrl.addr, remote_cmd)
            close_proc_pipes ( ssh )
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

print ("connect to nodes")
local ap_rpc = connect_node (ap_ref.ctrl.addr, args.ctrl_port)
local sta_rpc = connect_node (sta_ref.ctrl.addr, args.ctrl_port)

if ( ap_rpc == nil or sta_rpc == nil) then
    print ("connection failed!")
    os.exit(1)
end

ap_ref.rpc = ap_rpc
sta_ref.rpc = sta_rpc
print()

local ap_phys = ap_rpc.wifi_devices()
print ("AP wifi devices:")
map ( print, ap_phys)
ap_ref:add_wifi ( ap_phys[1] )

local sta_phys = sta_rpc.wifi_devices()
print ("STA wifi devices:")
map ( print, sta_phys)
sta_ref:add_wifi ( sta_phys[1] )
local sta_mac = sta_rpc.get_mac ( sta_phys[1] )
ap_ref:add_station ( sta_mac )
print ()

local ssid = ap_rpc.get_ssid( ap_phys[1] )
print ("AP ssid: ".. ssid)
print ()

if ( sta_mac ~= nil) then
    print ("STA mac: " ..  sta_mac)
else
    print ("STA mac: no ipv4 assigned?")
end
local sta_addr = sta_rpc.get_addr ( sta_phys[1] )
if ( sta_addr ~= nil ) then
    print ("STA addr: " ..  sta_addr)
else
    print ("STA addr: no ipv4 assigned")
    if ( sta_mac ~= nil ) then
        local addr = ap_rpc.has_lease ( sta_mac )
        if ( addr ~= nil ) then
            print ("STA addr (ap lease): " ..  sta_addr)
        end
    end
end
print()

-- fixme: "br-lan" on bridged routers, instead
local ap_mac = ap_rpc.get_mac ( ap_phys[1] )
if ( ap_mac ~= nil) then
    print ("AP mac: " ..  ap_mac)
else
    print ("AP mac: no ipv4 assigned")
end
local ap_addr = ap_rpc.get_addr ( ap_phys[1] )
if ( ap_addr ~= nil ) then
    print ("AP addr: " ..  ap_addr)
else
    print ("AP addr: no ipv4 assigned")
end
print()

print ( "STATIONS on " .. ap_phys[1])
print ( "==================")
local wifi_stations = ap_rpc.stations( ap_phys[1] )
map ( print, wifi_stations )
print ()

-- check whether station is connected
-- got the right station? query mac from STA
--if ( table_size ( wifi_stations_target ) < 1 ) then
--    print ("no station connected with access point")
--    os.exit(1)
--end

print ( ap_ref:__tostring() )
print ( sta_ref:__tostring() )

if (args.dry_run) then 
    print ( "dry run is set, quit here" )
    stop_logger ( logger_proc['pid'] )
    os.exit(1)
end

ap_rpc.add_monitor( ap_phys[1] )
sta_rpc.add_monitor( sta_phys[1] )

ap_rpc.set_ani ( ap_phys[1], not args.disable_ani )
sta_rpc.set_ani ( sta_phys[1], not args.disable_ani )

local runs = tonumber ( args.runs )

if ( args.tcp_only == false and args.udp_only == false and args.multicast_only == true) then
    local ap_stats
    local sta_stats
    ap_stats, sta_stats 
        = multicast_measurement( ap_ref, sta_ref, runs, args.interval )
    print ()
    if ( ap_stats ~= nil ) then
        print ( "AP stats" )
        print ( ap_stats:__tostring() )
        print ()
    end
    if ( sta_stats ~= nil ) then
        print ( "STA stats" )
        print ( sta_stats:__tostring() )
        print ()
    end
end

if ( args.tcp_only == true and args.udp_only == false and args.multicast_only == false) then
    local ap_stats
    local sta_stats
    ap_stats, sta_stats 
        = tcp_measurement( ap_ref, sta_ref, runs, args.tcpdata )
    print ()
    if ( ap_stats ~= nil ) then
        print ( "AP stats" )
        print ( ap_stats:__tostring() )
        print ()
    end
    if ( sta_stats ~= nil ) then
        print ( "STA stats" )
        print ( sta_stats:__tostring() )
        print ()
    end
end

if ( args.tcp_only == false and args.udp_only == true and args.multicast_only == false) then
    local ap_stats
    local sta_stats
    ap_stats, sta_stats 
        = udp_measurement( ap_ref, sta_ref, runs, args.packet_sizes, args.cct_intervals, args.packet_rates, args.interval )
    print ()
    if ( ap_stats ~= nil ) then
        print ( "AP stats" )
        print ( ap_stats:__tostring() )
        print ()
    end
    if ( sta_stats ~= nil ) then
        print ( "STA stats" )
        print ( sta_stats:__tostring() )
        print ()
    end
end                 

-- query lua pid before closing rpc connection
-- maybe to kill nodes later
local pids = {}
pids[1] = ap_rpc.get_pid()
pids[2] = sta_rpc.get_pid()

rpc.close(ap_rpc)
rpc.close(sta_rpc)

-- kill nodes if desired by the user
if (args.disable_autostart == false) then
    for i, node in ipairs ( { ap_ref, sta_ref } ) do -- fixme: zip nodes with pids
        local ssh = spawn_pipe("ssh", "root@" .. node.ctrl.addr, "kill " .. pids[i])
        local exit_code = ssh['proc']:wait()
        close_proc_pipes ( ssh )
    end
end

if ( args.disable_autostart == false ) then
    stop_logger ( logger_proc['pid'] )
end
