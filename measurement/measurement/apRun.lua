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


function find_node( name, nodes ) 
    for _,node in ipairs(nodes) do 
        if node.name == name then return node end 
    end
    return nil
end

function cnode_to_string ( config )
    return config.name .. "\t" .. config.radio .. "\t" .. config.ctrl_if
end


local parser = argparse("apRun", "Run minstrel blues single AP/ multi STA mesurement")

function show_config_error( arg, option )
    local str
    if ( option == true) then
        str = "option '--" .. arg .. "' missing or no config file specified"
    else
        str = "<".. arg .. "> missing"
    end
    print ( parser:get_usage() )
    print ( )
    print ( "Error: " .. str )
    os.exit()
end


-- ---------------------------------------------------------------


parser:argument("command", "tcp, udp, mcast")

-- TODO: use networks instead of hosts, each ap

parser:option ("-c --config", "config file name", nil)

parser:option("--sta","Station host name"):count("*")
parser:option("--ap","Access Point host name")
parser:option ("--sta_radio", "STA Wifi Interface name", "radio0")
parser:option ("--sta_ctrl_if", "STA Control Interface", "eth0")


parser:option ("--ap_radio", "AP Wifi Interface name", "radio0")
parser:option ("--ap_ctrl_if", "AP Control Monitor Interface")

parser:option ("--ctrl_port", "Port for control RPC", "12346" )

parser:option ("--log_ip", "IP of Logging node" )
parser:option ("-L --log_port", "Logging RPC port", "12347" )
parser:option ("-l --log_file", "Logging to File", "/tmp/measurement.log" )

parser:flag ("--disable_ani", "Runs experiment with ani disabled", false )

parser:option ("--runs", "Number of iterations", "1" )
parser:option ("-T --tcpdata", "Amount of TCP data", "5MB" )
parser:option ("-S --packet_sizes", "Amount of UDP data", "1500" )
parser:option ("-R --packet_rates", "Rates of UDP data", "50,200,600,1200" )
parser:option ("-I --cct_intervals", "send iperf traffic intervals in milliseconds", "20000,50,100,1000" )
parser:option ("-i --interval", "Intervals of TCP or UDP data", "1" )

parser:flag ("--disable_reachable", "Don't try to test the reachability of nodes", false )
parser:flag ("--disable_autostart", "Don't try to start nodes via ssh", false )

parser:flag ("--run_check", "No rpc connections, no meaurements", false )
parser:flag ("--dry_run", "Don't measure anything", false )
parser:flag ("--udp_only", "Measure tcp", false )
parser:flag ("--tcp_only", "Measure udp", false )
parser:flag ("--multicast_only", "Measure multicast", false )

parser:flag ("-v --verbose", "", false )

local args = parser:parse()


args.command = string.lower ( args.command )
if ( args.command ~= "tcp" and args.command ~= "upd" and args.command ~= "mcast") then
    show_config_error ( "command", false )
end


stations = {} -- table in config file
aps = {} -- table in config file

local ap_config

-- load config from a file
if (args.config ~= nil) then

    -- (loadfile, dofile, loadstring)  
    require(string.sub(args.config,1,#args.config-4))

    if (table_size ( stations ) < 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain at least one station node description in var 'stations'. " .. count)
        os.exit()
    end

    if (table_size ( aps ) < 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain one access point node description in var 'aps'. " .. count)
        os.exit()
    end

    -- overwrite config file setting with command line settings

    if ( args.ap ~= nil ) then
        ap_config = find_node( args.ap, aps )
    else
        ap_config = aps [1]
    end

    if (args.ap_radio ~= nil) then ap_config.radio = args.ap_radio end 
    if (args.ap_ctrl_if ~= nil) then ap_config.ctrl_if = args.ap_ctrl_if end 

    for i, sta in ipairs ( stations ) do
        if (args.sta_radio ~= nil) then sta.radio = args.sta_radio end 
        if (args.sta_ctrl_if ~= nil) then sta.ctrl_if = args.sta_ctrl_if end 
    end

else

    aps[1] = { name = args.ap
             , radio = args.ap_radio
             , ctrl_if = args.ap_ctrl_if
             }
    nodes[1] = aps[1]
    ap_config = find_node( args.ap, aps )

    for i,sta_name in ipairs ( args.sta ) do
         stations[1] = { name = sta_name
                      , radio = args.sta_radio
                      , ctrl_ip = args.sta_ctrl_ip
                      }
         nodes[ i + 2 ] = stations[i]
    end

end

if ( args.verbose == true) then
    local name = args.ap
    if ( name == nil ) then
        name = ap_config.name
    end
    print ( )
    print ( "Command: " .. args.command)
    print ( )
    print ( )
    print ( "Access Point: " .. name )
    print ( )
    print ( "Stations:")
    print ( )
    map ( print , args.sta )
    print ( )
end

nodes = {}
for _,v in ipairs(stations) do nodes [ #nodes + 1 ] = v end
for _,v in ipairs(aps) do nodes [ #nodes + 1 ] = v end

local stas_config = {}
for _, sta in ipairs ( args.sta ) do
    stas_config [ #stas_config + 1 ] = find_node ( sta, stations )
end


print ( "Configuration:" )
print ( "==============" )
print ( )
print ( "Command: " .. args.command )
print ( )
print ( "Access Point:" )
print ( "-------------")
print ( )
print ( cnode_to_string ( ap_config )  )
print ( )
print ( "Stations:")
print ( "---------")
print ( )
for _, sta in ipairs ( stas_config ) do
    print ( cnode_to_string (sta ) )
end
print ( )

-- ---------------------------------------------------------------

local ctrl = ControlNode:create()

local ap_ref
local sta_refs = {}

local ap_ctrl = NetIF:create ("ctrl", ap_config['ctrl_if'] )
local ap_ref = AccessPointRef:create (ap_config.name, ap_ctrl, args.ctrl_port )
ctrl:add_ap_ref ( ap_ref )

for _, sta in ipairs ( stas_config ) do
    local sta_ctrl = NetIF:create ("ctrl", sta['ctrl_if'] )
    local ref = StationRef:create ( sta.name, sta_ctrl, args.ctrl_port )
    sta_refs [ #sta_refs + 1] = ref
    ctrl:add_sta_ref ( ref )
end

if ( args.run_check == true ) then
    args.log_ip = nil
    args.log_port = nil
    args.Log_file = nil
end

-- -------------------------------------------------------------------

print ( "Reachability:" )
print ( "=============" )
print ( )

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

if ( args.run_check == true ) then
    print ( "all checks dome. quit here" )
    os.exit (1)
end

-- and auto start nodes
if ( args.disable_autostart == false ) then
    if (ctrl:start ( args.log_ip, args.log_port, args.log_file ) == false) then
        print ("Error: Not all nodes started")
        os.exit(1)
    end
    print ("wait 5 seconds for nodes initialisation")
    os.sleep (5)
end

-- ----------------------------------------------------------

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

ap_ref:set_ssid( ap_ref.rpc.get_ssid( ap_phys[1] ) )
print (ap_ref.name .. " ssid: ".. ap_ref:get_ssid())

-- fixme: "br-lan" on bridged routers, instead of eth0
local ap_mac = ap_ref.rpc.get_mac ( ap_phys[1] )
if ( ap_mac ~= nil) then
    print (ap_ref.name .. " mac: " ..  ap_mac)
else
    print (ap_ref.name .. " mac: no ipv4 assigned")
end

local ap_addr = ap_ref.rpc.get_addr ( ap_phys[1] )
if ( ap_addr ~= nil or ap_addr == "6..." ) then
    print ("AP addr: " ..  ap_addr)
else
    print ("AP addr: no ipv4 assigned")
end

print ()

for _, sta_ref in ipairs ( sta_refs ) do
    local sta_phys = sta_ref.rpc.wifi_devices()
    print ("STA wifi devices:")
    map ( print, sta_phys)
    print ( )
    sta_ref:add_wifi ( sta_phys[1] )
    local mac = sta_ref:get_mac ( sta_phys[1] )
    print (mac)
    ap_ref:add_station ( mac )
    -- local addr = ap_ref.rpc.has_lease ( mac )
    -- print ( "Address of " .. sta_ref.name .. ": " .. addr )
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
print ( )

if (args.dry_run) then 
    print ( "dry run is set, quit here" )
    if ( args.disable_autostart == false ) then
        ctrl:stop()
    end
    os.exit(1)
end
print ( )

-- -----------------------

local runs = tonumber ( args.runs )

for _, node_ref in ipairs ( ctrl:nodes() ) do
    node_ref.rpc.set_ani ( ap_phys[1], not args.disable_ani )
end

local experiment
if (args.command == "tcp") then
    experiment = create_tcp_measurement ( runs, args.tcpdata )
elseif (args.command == "mcast") then
    local multicast_exp = create_multicast_measurement ( runs, args.interval )
elseif (args.command == "udp") then
    local udp_exp = create_tcp_measurement ( runs, args.packet_sizes, args.cct_intervals, args.packet_rates, args.interval )
else
    show_config_error ( "command")
end

local status = ctrl:run_experiment ( experiment, ap_ref, sta_refs )

if (status == true) then
    print ( )
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
