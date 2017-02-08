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
require ('tcpExperiment')
require ('udpExperiment')
require ('multicastExperiment')


local parser = argparse("apRun", "Run minstrel blues single AP/ multi STA mesurement")

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
parser:option ("-t --tcpdata", "Amount of TCP data", "5MB" )
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

-- ---------------------------------------------------------------

local ctrl = ControlNode:create()

local ap_config = find_node ( "lede-ap", aps )
local sta_config = find_node ( "lede-sta", stations )
local sta2_config = find_node ( "lede-ctrl", stations )

local sta_ctrl = NetIF:create ("ctrl", sta_config['ctrl_if'], nil )
local sta_ref = StationRef:create (sta_config.name, sta_ctrl, args.ctrl_port )

local sta2_ctrl = NetIF:create ("ctrl", sta2_config['ctrl_if'], nil )
local sta2_ref = StationRef:create (sta2_config.name, sta2_ctrl, args.ctrl_port )

local ap_ctrl = NetIF:create ("ctrl", ap_config['ctrl_if'], nil )
local ap_ref = AccessPointRef:create (ap_config.name, ap_ctrl, args.ctrl_port )

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
    if (ctrl:start ( args.log_ip, args.log_port, args.log_file ) == false) then
        print ("Error: Not all nodes started")
        os.exit(1)
    end
    print ("wait 5 seconds for nodes initialisation")
    os.sleep (5)
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

-- -----------------------

local sta_refs = {}
sta_refs[1] = sta_ref
sta_refs[2] = sta2_ref

local tcp_exp = create_tcp_measurement ( runs, args.tcpdata )
local multicast_exp = create_multicast_measurement ( runs, args.interval )
local udp_exp = create_tcp_measurement ( runs, args.packet_sizes, args.cct_intervals, args.packet_rates, args.interval )

local status

if ( args.tcp_only == false and args.udp_only == false and args.multicast_only == true) then
    status = ctrl:run_experiment ( multicast_exp, ap_ref, sta_refs ) 
end

if (status == true) then
    for name, stats in pairs ( ctrl.stats ) do
        print ( name )
        print ( stats:__tostring() )
        print ( )
    end
end

if ( args.tcp_only == true and args.udp_only == false and args.multicast_only == false) then
    status = ctrl:run_experiment ( tcp_exp, ap_ref, sta_refs ) 
end

if (status == true) then
    for name, stats in pairs ( ctrl.stats ) do
        print ( name )
        print ( stats:__tostring() )
        print ( )
    end
end

if ( args.tcp_only == false and args.udp_only == true and args.multicast_only == false) then
    status = ctrl:run_experiment ( udp_exp, ap_ref, sta_refs ) 
end

if (status == true) then
    for name, stats in pairs ( ctrl.stats ) do
        print ( name )
        print ( stats:__tostring() )
        print ( )
    end
end

-- -----------------------

ctrl:disconnect()

-- kill nodes if desired by the user
if ( args.disable_autostart == false ) then
    ctrl:stop()
end
