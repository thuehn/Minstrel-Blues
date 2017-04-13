-- run a single measurement between access points (APs) and stations (STAs)

-- TODO:
-- - rpc: transfer tcpdump binary lines/packages and stats online to support large experiment with low ram
-- implement experiments as list of closures
-- erease debug table in production ( debug = nil )
-- sample rate rc_stats, regmon-stats, cpusage (how many updates / second) from luci regmon
-- init scripts for nodes
-- io.tmpfile () for writing pcaps?
-- convert signal / rssi : http://www.speedguide.net/faq/how-does-rssi-dbm-relate-to-signal-quality-percent-439
--  rssi is an estimated value and is detemined periodically (temperature changes ambient/background noise in the chip)
-- MCS has is own ordering: modulation & coding x channel Mhz x short/long gard interval (SGI/GI)
-- plugin support with loadfile
-- derive MeshRef from AcceesspointRef
-- abort experiment when not connected ( and no rates are available )
-- run multiple experiments simultaniuosly ( by using more nodes with different ports )
-- check authorized keys
-- initialize NetIF for disabled phys ( no netdev:wlan0/1 in debugfs )
-- abort when AP or STA not in config
-- add UDP iperf for x MB instead of x seconds with y Mbit/s data creation rate
-- plot ath and non-ath networks
-- regmon: luci config allows non-existant debugfs entries
-- reachability of stations for all access points
--   - allow empty command line arg --sta ( just --ap needed )
-- cooperative channel selection
-- deamon working dir should be / and stdout,in,err /dev/null
-- filter by used UDP port
-- station wifi addr is not resolvable when not connected (detect and abort)
-- experiment direction (AP->STA, STA->AP)
-- move config part to control node
-- analyse throughput
-- allow logging for ControlNodeRef, NodeRef
-- start logger as local instance
-- ControlNodeRef should fetch traces from nodes directly ( copy once )

local pprint = require ('pprint')

local argparse = require ('argparse')

local posix = require ('posix') -- sleep

require ('lfs')
require ('misc')

require ('Config')
require ('NetIF')
require ('ControlNodeRef')

local parser = argparse( "netRun", "Run minstrel blues multi AP / multi STA mesurement" )

parser:argument("command", "tcp, udp, mcast, noop")

parser:option ("-c --config", "config file name", nil)

parser:option("--sta", "Station host name or ip address and optional radio, ctrl_if, rsa_key and mac separated by comma"):count("*")
parser:option("--ap", "Access Point host name or ip address and optional radio, ctrl_if, rsa_key and mac separated by comma"):count("*")
parser:option("--con", "Connection between APs and STAs, format: ap_name=sta_name1,sta_name2"):count("*")

parser:option ("--ctrl", "Control node host name or ip address" )
parser:option ("--ctrl_if", "RPC Interface of Control node" )
parser:option ("-C --ctrl_port", "Port for control RPC", "12346" )
parser:flag ("--ctrl_only", "Just connect with control node", false )

parser:option ("--net_if", "Used network interface", "eth0" )

parser:option ("-L --log_port", "Logging RPC port", "12347" )
parser:option ("-l --log_file", "Logging to File", "measurement.log" )

-- Specify the distance between routers and station for the measurement log file. You can use keywords
-- like near and far or numbers with and without units like 1m or 10m
parser:option ("-d --distance", "approximate distance between nodes" )

parser:flag ("--disable_ani", "Runs experiment with ani disabled", false )

parser:option ("--runs", "Number of iterations", "1" )
parser:option ("-T --tcpdata", "Amount of TCP data", "5MB" )
parser:option ("-R --packet_rates", "Rates of UDP data", "10M,100M" )
parser:option ("-t --udp_durations", "how long iperf sends UDP traffic", "10,20,30" )
parser:option ("-i --interval", "Intervals of TCP or UDP data", "1" ) --fixme: ???

parser:flag ("--enable_fixed", "enable fixed setting of parameters", false)
parser:option ("--tx_rates", "TX rate indices")
parser:option ("--tx_powers", "TX power indices")

parser:flag ("--disable_reachable", "Don't try to test the reachability of nodes", false )
parser:flag ("--disable_synchronize", "Don't synchronize time in network", false )
parser:flag ("--disable_autostart", "Don't try to start nodes via ssh", false )

parser:flag ("--dry_run", "Don't measure anything", false )

parser:option ("--nameserver", "local nameserver" )

parser:option ("-O --output", "measurement / analyse data directory", "/tmp")

parser:flag ("-v --verbose", "", false )

local args = parser:parse()

args.command = string.lower ( args.command )
if ( args.command ~= "tcp" and args.command ~= "udp" and args.command ~= "mcast" and args.command ~= "noop" ) then
    Config.show_config_error ( parser, "command", false )
end

if ( args.enable_fixed == false 
    and ( args.tx_rates ~= nil or args.tx_powers ~= nil ) ) then
    Config.show_config_error ( parser, "enable_fixed", true )
    print ("")
end

if ( args.distance == nil ) then
    Config.show_config_error ( parser, "distance", true )
    print ("")
end

local has_config = Config.load_config ( args.config ) 

local ap_setups
local sta_setups

local keys = nil
local output_dir = args.output
if ( isDir ( output_dir ) == false ) then
    local status, err = lfs.mkdir ( output_dir )
else
    for _, name in ipairs ( ( scandir ( output_dir ) ) ) do
        if ( name ~= "." and name ~= ".."  and isDir ( args.output .. "/" .. name )
             and Config.find_node ( name, nodes ) ~= nil ) then
            local measurement = Measurement.parse ( name, args.output )
            print ( measurement:__tostring () )
            for key, pcap in pairs ( measurement.tcpdump_pcaps ) do
                if ( pcap == nil or pcap == "" ) then
                    if ( keys == nil ) then
                        keys = {}
                        keys [1] = {}
                    end
                    print ( "resume key: " .. key )
                    if ( Misc.index_of ( key, keys [1] ) == nil ) then
                        keys [1] [ #keys [1] + 1 ] = key
                    end
                end
            end
        end
    end
    pprint ( keys )

    if ( keys == nil ) then
        for _, fname in ipairs ( ( scandir ( output_dir ) ) ) do
            if ( fname ~= "." and fname ~= ".." ) then
                local time = os.time ()
                print ("--output " .. output_dir
                        .. " already exists and is not empty. Measurement saved into subdirectory " .. time)
                output_dir = output_dir .. "/" .. time
                local status, err = lfs.mkdir ( output_dir )
                break
            end
        end
    end
end

-- load config from a file
if ( has_config ) then

    if ( ctrl == nil ) then
        print ( "Error: config file '" .. Config.get_config_fname ( args.config ) 
                    .. "' have to contain at least one station node description in var 'stations'.")
        os.exit (1)
    end

    if ( args.ctrl_only == false ) then
        if (table_size ( nodes ) < 2) then
            print ( "Error: config file '" .. Config.get_config_fname ( args.config ) 
                        .. "' have to contain at least two node descriptions in var 'nodes'.")
            os.exit (1)
        end

        if (table_size ( connections ) < 1) then
            print ( "Error: config file '" .. Config.get_config_fname ( args.config )
                        .. "' have to contain at least one connection declaration in var 'connections'.")
            os.exit (1)
        end
    end

    -- overwrite config file setting with command line settings

    Config.read_connections ( args.con )

    Config.set_config_from_arg ( ctrl, 'ctrl_if', args.ctrl_if )
    
    ap_setups = Config.accesspoints ( nodes, connections )
    Config.set_configs_from_args ( ap_setups, args.ap )

    sta_setups = Config.stations ( nodes, connections )
    Config.set_configs_from_args ( sta_setups, args.sta )

else

    if ( args.ctrl ~= nil ) then
        ctrl = Config.create_config ( args.ctrl, args.ctrl_if ) 
    else
        Config.show_config_error ( parser, "ctrl", true)
    end

    if ( args.ctrl_only == false ) then
        if (args.ap == nil or table_size ( args.ap ) == 0 ) then
            Config.show_config_error ( parser, "ap", true)
        end

        if (args.sta == nil or table_size ( args.sta ) == 0 ) then
            Config.show_config_error ( parser, "sta", true)
        end
    end
    nodes [1] = ctrl

    ap_setups = Config.create_configs ( args.ap )
    sta_setups = Config.create_configs ( args.sta )
    Config.copy_config_nodes ( ap_setups, nodes )
    Config.copy_config_nodes ( sta_setups, nodes )

    Config.read_connections ( args.con )
end

if ( table_size ( connections ) == 0 ) then
    print ( "Error: no connections specified" )
    os.exit (1)
end

if ( args.verbose == true) then
    print ( )
    print ( "Command: " .. args.command)
    print ( )
    print ( )
    print ( "Access Points:" )
    for _, ap in ipairs ( args.ap ) do print ( ap ) end
    print ( )
    print ( "Stations:" )
    print ( )
    for _, sta in ipairs ( args.sta ) do print ( sta ) end
    print ( )
end

local ap_names = {}
for _, ap in ipairs ( args.ap ) do
    local parts = split ( ap, "," )
    ap_names [ #ap_names + 1 ] = parts [ 1 ]
end

local aps_config = Config.select_configs ( ap_setups, ap_names )
if ( aps_config == {} ) then os.exit (1) end

local sta_names = {}
for _, sta in ipairs ( args.sta ) do
    local parts = split ( sta, "," )
    sta_names [ #sta_names + 1 ] = parts [ 1 ]
end

local stas_config = Config.select_configs ( sta_setups, sta_names )
if ( stas_config == {} ) then os.exit (1) end

local ctrl_config = Config.select_config ( nodes, args.ctrl )
if ( ctrl_config == nil ) then os.exit (1) end

print ( "Configuration:" )
print ( "==============" )
print ( )
print ( "Command: " .. args.command )
print ( )
print ( "Control: " .. Config.cnode_to_string ( ctrl_config ) )
print ( )
print ( "Access Points:" )
print ( "--------------" )

for _, ap in ipairs ( aps_config ) do
    print ( Config.cnode_to_string ( ap ) )
end

print ( )
print ( "Stations:" )
print ( "---------" )

for _, sta_config in ipairs ( stas_config ) do
    print ( Config.cnode_to_string ( sta_config ) )
end
print ( )

Config.save ( output_dir, ctrl_config, aps_config, stas_config )

local ctrl_pid
local ctrl_ref
local net

function cleanup ()
    if ( ctrl_ref.rpc == nil ) then return true end

    print ( " disconnect nodes " )
    ctrl_ref:disconnect_nodes ()

    -- kill nodes if desired by the user
    if ( args.disable_autostart == false ) then
        print ( "stop control" )
        ctrl_ref:stop_control ()
        if ( ctrl_ref.ctrl_net_ref.addr ~= nil and ctrl_ref.ctrl_net_ref.addr ~= net.addr ) then
            ctrl_ref:stop_remote ( ctrl_ref.ctrl_net_ref.addr, ctrl_pid )
        else
            ctrl_ref:stop ( ctrl_pid )
        end
    end
    ctrl_ref:disconnect ()
end

-- local ctrl iface
net = NetIF:create ( args.net_if )
net:get_addr()

-- remote control node interface
ctrl_ref = ControlNodeRef:create ( ctrl_config ['name']
                                 , ctrl_config ['ctrl_if']
                                 , output_dir
                                 , args.log_file
                                 , args.log_port
                                 , args.distance
                                 , net
                                 )

-- stop when nameserver is not reachable / not working
if ( nameserver ~= nil or args.nameserver ~= nil ) then
    local addr, _ = parse_ipv4 ( nameserver or args.nameserver )
    local ping_ns, exit_code = Misc.execute ( "ping", "-c1", nameserver or args.nameserver )
    if ( exit_code ~= 0 ) then
        print ( "Cannot reach nameserver" )
        os.exit (1)
    end
end

if ( net.addr == nil ) then
    print ( "Cannot get IP address of local interface" )
    os.exit (1)
end
if ( ctrl_ref.ctrl_net_ref.addr == nil ) then
    print ( "Cannot get IP address of control node reference" )
    os.exit (1)
end

if ( args.disable_autostart == false ) then
    if ( ctrl_ref.ctrl_net_ref.addr ~= nil and ctrl_ref.ctrl_net_ref.addr ~= net.addr ) then
        ctrl_pid = ctrl_ref:start_remote ( args.ctrl_port )
    else
        ctrl_pid = ctrl_ref:start ( args.ctrl_port )
    end
end

-- ---------------------------------------------------------------

-- connect to control

ctrl_ref:connect ( args.ctrl_port )
if ( ctrl_ref.rpc == nil) then
    print ( "Connection to control node faild" )
    os.exit (1)
end
print ()
ctrl_pid = ctrl_ref:get_pid ()

print ( "Control board: " .. ( ctrl_ref:get_board () or "unknown" ) )
print ( "Control os-release: " .. ( ctrl_ref:get_os_release () or "unknown" ) )
print ()

--synchronize time
if ( args.disable_synchronize == false ) then
    local err
    local time = os.date("*t", os.time() )
    local cur_time, err = ctrl_ref:set_date ( time.year, time.month, time.day, time.hour, time.min, time.sec )
    if ( err == nil ) then
        print ( "Set date/time to " .. cur_time )
    else
        print ( "Set date/time failed: " .. err )
        print ( "Time is: " .. ( cur_time or "unset" ) )
    end
end

-- add station and accesspoint references to control
ctrl_ref:add_aps ( aps_config )
ctrl_ref:add_stas ( stas_config )

-- -------------------------------------------------------------------

if ( table_size ( ctrl_ref:list_nodes() ) == 0 ) then
    error ("no nodes present")
    cleanup ()
    os.exit (1)
end

print ( "Reachability:" )
print ( "=============" )
print ( )

if ( nameserver ~= nil or args.nameserver ~= nil ) then
    ctrl_ref:set_nameserver ( args.nameserver or nameserver )
end

-- check reachability 
if ( args.disable_reachable == false ) then
    if ( ctrl_ref:reachable () == false ) then
        cleanup ()
        os.exit (1)
    end
end
print ()

-- and auto start nodes
if ( args.disable_autostart == false ) then
    -- check known_hosts at control
    if ( ctrl_ref:hosts_known () == false ) then
        print ( "Not all hosts are known on control node. Check know_hosts file." )
        os.exit (1)
    end

    print ("start nodes")
    if ( ctrl_ref:start_nodes ( ctrl_ref.ctrl_net_ref.addr, args.log_port ) == false ) then
        cleanup ()
        print ( "Error: Not all nodes started")
        os.exit (1)
    end
end

-- ----------------------------------------------------------

print ( "Wait 3 seconds for nodes initialisation" )
posix.sleep (3)

-- and connect to nodes
print ( "connect to nodes at port " .. args.ctrl_port )
if ( ctrl_ref:connect_nodes ( args.ctrl_port ) == false ) then
    print ( "connections to nodes failed!" )
    cleanup ()
    os.exit (1)
else
    print ("All nodes connected")
end
print ()

for node_name, board in pairs ( ctrl_ref:get_boards () ) do
    print ( node_name .. " board: " .. board )
end

for node_name, os_release in pairs ( ctrl_ref:get_os_releases () ) do
    print ( node_name .. " os_release: " .. os_release )
end

-- synchonize time
if ( args.disable_synchronize == false ) then
    ctrl_ref:set_dates ()
end

-- set nameserver on all nodes
ctrl_ref:set_nameservers ( args.nameserver or nameserver )

print ( "Prepare APs" )
if ( ctrl_ref:prepare_aps ( aps_config ) == false ) then
    print ( "preparation of access points failed!" )
    cleanup ()
    os.exit (1)
end
print ()

print ( "Prepare STAs" )
if ( ctrl_ref:prepare_stas ( stas_config ) == false ) then
    print ( "preparation of stations failed!" )
    cleanup ()
    os.exit (1)
end

print ( "Associate AP with STAs" )
ctrl_ref:associate_stas ( connections )

print ( "Connect STAs to APs SSID" )
local all_linked = ctrl_ref:link_stas ( connections )
if ( all_linked == false ) then
    print ( "error: cannot get ssid from acceesspoint" )
    cleanup ()
    os.exit (1)
end

-- check bridges
local all_bridgeless = ctrl_ref:check_bridges()
if ( not all_bridgeless ) then
    print ( "Some nodes have a bridged setup. See log for details." )
end

print()

for _, ap_name in ipairs ( ctrl_ref:list_aps() ) do
    print ( "STATIONS on " .. ap_name )
    print ( "==================")
    local wifi_stations = ctrl_ref:list_stations ( ap_name )
    for _, wifi_station in ipairs ( wifi_stations ) do print ( wifi_station ) end
    print ()
end

print ( ctrl_ref:__tostring() )
print ( )

if ( args.dry_run ) then 
    print ( "dry run is set, quit here" )
    cleanup ()
    os.exit (1)
end
print ( )

-- -----------------------

local runs = tonumber ( args.runs )

ctrl_ref:set_ani ( not args.disable_ani )

local data
if ( args.command == "tcp" ) then
    data = { runs, args.tx_powers, args.tx_rates
           , args.tcpdata
           }
elseif ( args.command == "mcast" ) then
    data = { runs, args.tx_powers, args.tx_rates
           , args.interval
           }
elseif ( args.command == "udp" ) then
    data = { runs, args.tx_powers, args.tx_rates
           , args.packet_rates, args.udp_durations
           }
elseif ( args.command == "noop" ) then
    data = { runs, args.tx_powers, args.tx_rates
           }
else
    show_config_error ( parser, "command")
end

ctrl_ref:init_experiments ( args.command, data, ctrl_ref:list_aps(), args.enable_fixed )

--ctrl_ref:restart_wifi_debug ()
--posix.sleep (20)

local status, err = ctrl_ref:run_experiments ( args.command
                                             , data
                                             , ctrl_ref:list_aps()
                                             , args.enable_fixed
                                             , keys
                                             )

if ( status == false ) then
    print ( "err: experiments failed: " .. ( err or "unknown error" ) )
else
    print ()
    for name, stats in pairs ( ctrl_ref.stats ) do
        print ( stats:__tostring() )
        print ( )
    end
end

cleanup ()
os.exit ( 0 )
