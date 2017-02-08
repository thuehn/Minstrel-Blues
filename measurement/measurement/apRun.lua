-- run a single measurement between one access point (AP) and stations

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
require ('Control')
require ('Experiment')


local parser = argparse("singleRun", "Run minstrel blues single AP/STA mesurement")

-- TODO: use networks instead of hosts, each ap

parser:option ("-c --config", "config file name", nil)

parser:option ("--sta_radio", "STA Wifi Interface name", "radio0")
parser:option ("--sta_ctrl_if", "STA Control Interface")


parser:option ("--ap_radio", "AP Wifi Interface name", "radio0")
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
    if (table_size ( stations ) < 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain one station node description in var 'stations'. " .. count)
        os.exit()
    end
    if (table_size ( aps ) ~= 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain one access point node description in var 'aps'. " .. count)
        os.exit()
    end
    local ap = find_node( "lede-ap", aps )
    if (ap == nil) then
        print ( "Error: config file '" .. args.config .. "' have to specify a node named 'lede-ap' in the 'nodes' table. " .. count)
        os.exit()
    end
    local sta = find_node ( "lede-sta", stations )
    if (sta == nil) then
        print ( "Error: config file '" .. args.config .. "' have to specify a node named 'lede-sta' in the 'nodes' table. " .. count)
        os.exit()
    end
    local sta2 = find_node ( "lede-ctrl", stations )
    if (sta == nil) then
        print ( "Error: config file '" .. args.config .. "' have to specify a node named 'lede-ctrl' in the 'nodes' table. " .. count)
        os.exit()
    end
    -- overwrite config file setting with command line settings
    if (args.ap_radio ~= nil) then ap.radio = args.ap_radio end 
    if (args.ap_ctrl_if ~= nil) then ap.ctrl_if = args.ap_ctrl_if end 

    if (args.sta_radio ~= nil) then sta.radio = args.sta_radio end 
    if (args.sta_ctrl_if ~= nil) then sta.ctrl_if = args.sta_ctrl_if end 
else
    if (args.ap_radio == nil) then show_config_error ( "ap_radio") end
    if (args.ap_ctrl_if == nil) then show_config_error ( "ap_ctrl_if") end

    if (args.sta_radio == nil) then show_config_error ( "sta_radio") end
    if (args.sta_ctrl_if == nil) then show_config_error ( "sta_ctrl_if") end

    aps[1] = { name = "lede-ap"
             , radio = args.ap_radio
             , ctrl_if = args.ap_ctrl_if
             }
    stations[1] = { name = "lede-sta"
                  , radio = args.sta_radio
                  , ctrl_ip = args.sta_ctrl_ip
                  }
    nodes[1] = aps[1]
    nodes[2] = stations[1]
end

function multicast_measurement ( ap_ref, sta_refs, runs, udp_interval )


    local ap_stats = Measurement:create( ap_ref.rpc )
    ap_stats:enable_rc_stats ( ap_ref.stations )
    local stas_stats = {}

    local tx_rates = ap_ref.rpc.tx_rate_indices( ap_ref.wifis[1], ap_ref.stations[1] )
    local tx_powers = {}
    for i = 1, 25 do
        tx_powers[1] = i
    end
    local size = "100M"

    for run = 1, runs do

        for _, tx_rate in ipairs ( tx_rates ) do
            
            for _, tx_power in ipairs ( tx_powers ) do

                local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) .. "-" .. tostring(run)

                ap_ref.rpc.set_tx_rate ( ap_ref.wifis[1], ap_ref.stations[1], tx_rate )
                ap_ref.rpc.set_tx_power ( ap_ref.wifis[1], ap_ref.stations[1], tx_power )
    
                -- add monitor on AP and STA
                ap_ref.rpc.add_monitor( ap_ref.wifis[1] )

                -- start measurement on AP
                ap_stats:start ( ap_ref.wifis[1], key )

                for i, sta_ref in ipairs ( sta_refs ) do
                    -- restart wifi on STA
                    sta_ref.rpc.restart_wifi()
                    -- fixme: mon0 not created because of too many open files (~650/12505)
                    --   - maybe mon0 already exists
                    sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
                end

                -- wait for stations connect
                for i,sta_ref in ipairs ( sta_refs ) do
                    wait_linked ( sta_ref, sta_ref.wifis[1] )
                end

                for i,sta_ref in ipairs ( sta_refs ) do
                    stas_stats[i] = Measurement:create( sta_ref.rpc )
                    stas_stats[i]:start ( sta_ref.wifis[1], key )
                end

                -- -------------------------------------------------------
                -- Experiment
                -- -------------------------------------------------------
                local wait = true
                for i, sta_ref in ipairs ( sta_refs ) do
                    -- start iperf client on AP
                    local addr = "224.0.67.0"
                    local ttl = 32
                    local iperf_c_proc_str = ap_ref.rpc.run_multicast( sta_ref:get_addr ( sta_ref.wifis[1] ), addr, ttl, size, udp_interval, wait )
                end
                -- -------------------------------------------------------

                for i, sta_ref in ipairs ( sta_refs ) do
                    stas_stats[i]:stop ()
                    stas_stats[i]:fetch ( sta_ref.wifis[1], key )
                end

                -- stop measurement on AP
                ap_stats:stop ()

                -- collect traces
                ap_stats:fetch ( ap_ref.wifis[1], key )
            end
        end
    end

    return ap_stats, stas_stats
end

function tcp_measurement ( ap_ref, sta_ref, runs, tcpdata )
    
    local ap_stats = Measurement:create( ap_ref.rpc )
    ap_stats:enable_rc_stats ( ap_ref.stations )
    local sta_stats = Measurement:create( sta_ref.rpc )
    local stas_stats = {}
    stas_stats[1] = sta_stats 

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
        local iperf_c_proc_str = ap_ref.rpc.run_tcp_iperf( sta_ref:get_addr ( sta_ref.wifis[1] ), tcpdata )

        -- stop measurement on STA and AP
        ap_stats:stop ()
        sta_stats:stop ()

        -- stop iperf server on STA
        sta_ref.rpc.stop_iperf_server( iperf_s_proc['pid'] )
        
        -- collect traces
        ap_stats:fetch ( ap_ref.wifis[1], key )
        sta_stats:fetch ( sta_ref.wifis[1], key )
    end

    return ap_stats, stas_stats
end


function udp_measurement ( ap_ref, sta_ref, runs, packet_sizes, cct_intervals, packet_rates, udp_interval )

    local ap_stats = Measurement:create( ap_ref.rpc )
    ap_stats:enable_rc_stats ( ap_ref.stations )
    local stas_stats = {}
    local sta_stats = Measurement:create( sta_ref.rpc )
    stas_stats[1] = sta_stats

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
                local iperf_c_proc_str = ap_ref.rpc.run_udp_iperf( sta_ref:get_addr ( sta_ref.wifis[1] ), size, rate, udp_interval )

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
    return ap_stats, stas_stats

end

-- ---------------------------------------------------------------

local ctrl = ControlNode:create()

local ap_node = find_node ( "lede-ap", aps )
local sta_node = find_node ( "lede-sta", stations )

local sta_ctrl = NetIF:create ("ctrl", sta_node['ctrl_if'], nil )
local sta_ref = StationRef:create ("lede-sta", sta_ctrl, args.ctrl_port )
local sta2_ctrl = NetIF:create ("ctrl", "eth0", nil )
local sta2_ref = StationRef:create ("lede-ctrl", sta2_ctrl, args.ctrl_port )

local ap_ctrl = NetIF:create ("ctrl", ap_node['ctrl_if'], nil )
local ap_ref = AccessPointRef:create ("lede-ap", ap_ctrl, args.ctrl_port )

ctrl:add_ap_ref ( ap_ref )
ctrl:add_sta_ref ( sta_ref )
ctrl:add_sta_ref ( sta2_ref )

-- print configuration
print ("Configuration:")
print ("==============")
print ()
print ( ctrl:__tostring() )
print ()
print ( "run udp: " .. tostring( args.tcp_only == false and args.tcp_only == false and args.multicast_only == false) )
print ( "run tcp: " .. tostring( args.udp_only == false and args.tcp_only == false and args.multicast_only == false) )
print ( "run multicast: " .. tostring( args.udp_only == false and args.tcp_only == false and args.multicast_only == true) )
print ()

-- check reachability 
if ( args.disable_reachable == false ) then
    local reached = ctrl:reachable()
    for addr, reached in pairs ( reached ) do
        if (reached) then
            print ( addr .. ": ONLINE" )
        else
            print ( addr .. ": OFFLINE" )
            os.exit(1)
        end
    end
end
print ()

-- and auto start nodes
if ( args.disable_autostart == false ) then
    if (ctrl:start ( args.log_ip, args.log_port ) == false) then
        print ("Error: Not all nodes started")
        os.exit(1)
    end
    print ("wait a second for nodes initialisation")
    os.sleep (4)
end

-- and connect to nodes
print ("connect to nodes")
if (ctrl:connect ( args.ctrl_port ) == false) then
    print ("connection failed!")
    os.exit(1)
end

print()

local ap_phys = ap_ref.rpc.wifi_devices()
print (ap_ref.name .. " wifi devices:")
map ( print, ap_phys)
ap_ref:add_wifi ( ap_phys[1] )

local sta_phys = sta_ref.rpc.wifi_devices()
print ("STA wifi devices:")
map ( print, sta_phys)
sta_ref:add_wifi ( sta_phys[1] )

local sta2_phys = sta2_ref.rpc.wifi_devices()
print ("STA2 wifi devices:")
map ( print, sta_phys)
sta2_ref:add_wifi ( sta2_phys[1] )
print ()

ap_ref:add_station ( sta_ref:get_mac ( sta_phys[1] ) )
ap_ref:add_station ( sta2_ref:get_mac ( sta2_phys[1] ) )


ap_ref:set_ssid( ap_ref.rpc.get_ssid( ap_phys[1] ) )
print (ap_ref.name .. " ssid: ".. ap_ref:get_ssid())
print ()

local addr = ap_ref.rpc.has_lease ( sta_ref:get_mac( sta_phys[1] ) )
print ( addr )

-- fixme: "br-lan" on bridged routers, instead
local ap_mac = ap_ref.rpc.get_mac ( ap_phys[1] )
if ( ap_mac ~= nil) then
    print (ap_ref.name .. " mac: " ..  ap_mac)
else
    print (ap_ref.name .. " mac: no ipv4 assigned")
end
local ap_addr = ap_ref.rpc.get_addr ( ap_phys[1] )
if ( ap_addr ~= nil ) then
    print ("AP addr: " ..  ap_addr)
else
    print ("AP addr: no ipv4 assigned")
end
print()

print ( "STATIONS on " .. ap_phys[1])
print ( "==================")
local wifi_stations = ap_ref.rpc.stations( ap_phys[1] )
map ( print, wifi_stations )
print ()

-- check whether station is connected
-- got the right station? query mac from STA
--if ( table_size ( wifi_stations_target ) < 1 ) then
--    print ("no station connected with access point")
--    os.exit(1)
--end

print ( ctrl:__tostring() )

if (args.dry_run) then 
    print ( "dry run is set, quit here" )
    if ( args.disable_autostart == false ) then
        ctrl:stop()
    end
    os.exit(1)
end

for _, node_ref in ipairs ( ctrl:nodes() ) do
    node_ref.rpc.set_ani ( ap_phys[1], not args.disable_ani )
end

local runs = tonumber ( args.runs )

local ap_stats
local stats_stats
if ( args.tcp_only == false and args.udp_only == false and args.multicast_only == true) then
    local sta_refs = {}
    sta_refs[1] = sta_ref
    sta_refs[2] = sta2_ref
    ap_stats, stas_stats 
        = multicast_measurement( ap_ref, sta_refs, runs, args.interval )
end

if ( args.tcp_only == true and args.udp_only == false and args.multicast_only == false) then
    ap_stats, stas_stats 
        = tcp_measurement( ap_ref, sta_ref, runs, args.tcpdata )
end

if ( args.tcp_only == false and args.udp_only == true and args.multicast_only == false) then
    ap_stats, stas_stats 
        = udp_measurement( ap_ref, sta_ref, runs, args.packet_sizes, args.cct_intervals, args.packet_rates, args.interval )
end 

print ()
if ( ap_stats ~= nil ) then
    print ( "AP stats" )
    print ( ap_stats:__tostring() )
    print ()
end

print ( "STAs stats" )
for _, sta_stats in ipairs ( stas_stats ) do
    print ( sta_stats:__tostring() )
    print ()
end

ctrl:diconnect()

-- kill nodes if desired by the user
if ( args.disable_autostart == false ) then
    ctrl:stop()
end
