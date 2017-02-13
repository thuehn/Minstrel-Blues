-- run a single measurement between access points (APs) and stations (STAs)

-- TODO:
-- - openwrt package: fetch sources for argparse, luarpc and lua-ex with git
-- - rpc: transfer tcpdump binary lines/packages
-- - luci: store public ssh keys of all control devices on each ap/sta node
-- - analyse pcap
-- sample rate from luci-regmon

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
require ('mcastExperiment')
require ('Config')


local parser = argparse("netRun", "Run minstrel blues multi AP / multi STA mesurement")


parser:argument("command", "tcp, udp, mcast")

-- TODO: use networks instead of hosts, each ap

parser:option ("-c --config", "config file name", nil)

parser:option("--sta", "Station host name"):count("*")
parser:option("--ap", "Access Point host name"):count("*")
parser:option ("--sta_radio", "STA Wifi Interface name", "radio0")
parser:option ("--sta_ctrl_if", "STA Control Interface", "eth0")


parser:option ("--ap_radio", "AP Wifi Interface name", "radio0")
parser:option ("--ap_ctrl_if", "AP Control Monitor Interface", "eth0")

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

parser:flag ("-v --verbose", "", false )

local args = parser:parse()

args.command = string.lower ( args.command )
if ( args.command ~= "tcp" and args.command ~= "udp" and args.command ~= "mcast") then
    show_config_error ( parser, "command", false )
end

stations = {} -- table in config file
aps = {} -- table in config file
nodes = {}

-- load config from a file
if (args.config ~= nil) then

    if ( not isFile ( args.config ) ) then
        print ( args.config .. " does not exists.")
        os.exit (1)
    end

    -- (loadfile, dofile, loadstring)  
    require(string.sub(args.config,1,#args.config-4))

    if (table_size ( stations ) < 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain at least one station node description in var 'stations'.")
        os.exit(1)
    end

    if (table_size ( aps ) < 1) then
        print ( "Error: config file '" .. args.config .. "' have to contain at least one access point node description in var 'aps'.")
        os.exit(1)
    end

    -- overwrite config file setting with command line settings

    for i, ap_config in ipairs ( aps ) do
        if (args.ap_radio ~= nil) then ap_config.radio = args.ap_radio end 
        if (args.ap_ctrl_if ~= nil) then ap_config.ctrl_if = args.ap_ctrl_if end 
    end

    for i, sta_config in ipairs ( stations ) do
        if (args.sta_radio ~= nil) then sta_config.radio = args.sta_radio end 
        if (args.sta_ctrl_if ~= nil) then sta_config.ctrl_if = args.sta_ctrl_if end 
    end

else

    if (args.ap == nil or table_size ( args.ap ) == 0 ) then
        show_config_error ( parser, "ap", true)
    end

    if (args.sta == nil or table_size ( args.sta ) == 0 ) then
        show_config_error ( parser, "sta", true)
    end

    for i,ap_name in ipairs ( args.ap ) do
        aps[i] = { name = ap_name
                 , radio = args.ap_radio
                 , ctrl_if = args.ap_ctrl_if
                 }
        nodes[ i + 1 ] = aps[i]
    end

    for j, sta_name in ipairs ( args.sta ) do
        local k = i + j
        stations[k] = { name = sta_name
                      , radio = args.sta_radio
                      , ctrl_ip = args.sta_ctrl_ip
                     }
        nodes[ k + 1 ] = stations[k]
    end

end

if ( args.verbose == true) then
    print ( )
    print ( "Command: " .. args.command)
    print ( )
    print ( )
    print ( "Access Points:" )
    map ( print, args.ap )
    print ( )
    print ( "Stations:" )
    print ( )
    map ( print , args.sta )
    print ( )
end

for _,v in ipairs(stations) do nodes [ #nodes + 1 ] = v end
for _,v in ipairs(aps) do nodes [ #nodes + 1 ] = v end

local aps_config = {}
if ( table_size ( args.ap ) > 0 ) then
    for _, ap_name in ipairs ( args.ap ) do
        local node = find_node ( ap_name, aps )
        if ( node == nil ) then
            print ( "Error: no access point with name '" ..ap_name .. "' found")
            os.exit(1)
        end
        aps_config [ #aps_config + 1 ] = node 
    end
else
    print ("No access points selected. Using all access points from setup")
    print ()
    for _, node in ipairs ( aps ) do
        aps_config [ #aps_config + 1 ] = node 
    end
end

local stas_config = {}
if ( table_size ( args.sta ) > 0 ) then
    for _, sta_name in ipairs ( args.sta ) do
        local node = find_node ( sta_name, stations )
        if ( node == nil ) then
            print ( "Error: no station with name '" .. sta_name .. "' found")
            os.exit(1)
        end
        stas_config [ #stas_config + 1 ] = node 
    end
else
    print ("No stations selected. Using all stations from setup")
    print ()
    for _, node in ipairs ( stations ) do
        stas_config [ #stas_config + 1 ] = node 
    end
end


print ( "Configuration:" )
print ( "==============" )
print ( )
print ( "Command: " .. args.command )
print ( )
print ( "Access Points:" )
print ( "--------------")
for _, ap in ipairs ( aps_config ) do
    print ( cnode_to_string ( ap ) )
end
print ( )
print ( "Stations:")
print ( "---------")
for _, sta_config in ipairs ( stas_config ) do
    print ( cnode_to_string ( sta_config ) )
end
print ( )

-- ---------------------------------------------------------------

local ctrl = ControlNode:create()
local ap_refs = {}
local sta_refs = {}

for _, ap_config in ipairs ( aps_config ) do
    local ap_ctrl = NetIF:create ("ctrl", ap_config['ctrl_if'] )
    local ap_ref = AccessPointRef:create (ap_config.name, ap_ctrl, args.ctrl_port )
    ctrl:add_ap_ref ( ap_ref )
    ap_refs [ #ap_refs + 1 ] = ap_ref
end

for _, sta_config in ipairs ( stas_config ) do
    local sta_ctrl = NetIF:create ("ctrl", sta_config['ctrl_if'] )
    local sta_ref = StationRef:create ( sta_config.name, sta_ctrl, args.ctrl_port )
    ctrl:add_sta_ref ( sta_ref )
    sta_refs [ #sta_refs + 1 ] = sta_ref
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
    print ( "all checks done. quit here" )
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

local ap_ref_tmp
local ap_phys_tmp

for _, ap_ref in ipairs ( ap_refs ) do
    ap_ref_tmp = ap_ref -- fixme: configure aps and stations
    local ap_phys = ap_ref.rpc.wifi_devices()
    ap_phys_tmp = ap_phys
    print (ap_ref.name .. " wifi devices:")
    map ( print, ap_phys)
    ap_ref:add_wifi ( ap_phys[1] )
    ap_ref:set_wifi ( ap_phys[1] )

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
    if ( ap_addr ~= nil and ap_addr ~= "6..." ) then
        print ("AP addr: " ..  ap_addr)
    else
        print ("AP addr: no ipv4 assigned")
    end
end
ap_ref_tmp = ap_refs[1]

print ()

for _, sta_ref in ipairs ( sta_refs ) do
    local sta_phys = sta_ref.rpc.wifi_devices()
    print (sta_ref.name .. " wifi devices:")
    map ( print, sta_phys)
    sta_ref:add_wifi ( sta_phys[1] )
    sta_ref:set_wifi ( sta_phys[1] )
    local mac = sta_ref:get_mac ( sta_phys[1] )
    print ( sta_ref.name .. " mac: " .. mac)
    ap_ref_tmp:add_station ( mac, sta_ref )
    -- local addr = ap_ref.rpc.has_lease ( mac )
    -- print ( "Address of " .. sta_ref.name .. ": " .. addr )
end

print()

print ( "STATIONS on " .. ap_phys_tmp[1])
print ( "==================")
local wifi_stations = ap_ref_tmp.rpc.stations( ap_phys_tmp[1] )
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
    node_ref.rpc.set_ani ( ap_phys_tmp[1], not args.disable_ani ) --fixme: phy
end

local experiment
if (args.command == "tcp") then
    experiment = TcpExperiment:create ( runs, args.tcpdata )
elseif (args.command == "mcast") then
    experiment = McastExperiment:create ( runs, args.interval )
elseif (args.command == "udp") then
    experiment = UdpExperiment:create ( runs, args.packet_sizes, args.cct_intervals, args.packet_rates, args.interval )
else
    show_config_error ( parser, "command")
end

local status = ctrl:run_experiments ( experiment, ap_refs )

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
