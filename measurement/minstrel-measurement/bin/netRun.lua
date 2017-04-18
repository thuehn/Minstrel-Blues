-- run a single measurement between access points (APs) and stations (STAs)
-- note: to run measurements simultaniuosly use different ports for logging (-L) and control (-C)
--       as well as different output directories (--output)
-- since the radios are not yet locked in any kind you have to ensure not them twice

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
-- derive MeshRef from AccesspointRef
-- check authorized keys manually ( no ssh-copy-id)
-- add UDP iperf for x MB instead of x seconds with y Mbit/s data creation rate
-- plot ath and non-ath networks
-- regmon: luci config allows non-existant debugfs entries
-- reachability of stations for all access points
--   - allow empty command line arg --sta ( just --ap needed )
-- cooperative channel selection
-- deamon working dir should be / and stdout,in,err /dev/null
-- filter by used UDP port
-- experiment direction (AP->STA, STA->AP)
-- analyse throughput

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
    keys = Measurement.resume ( output_dir )
    if ( keys == nil ) then
        for _, fname in ipairs ( ( scandir ( output_dir ) ) ) do
            if ( fname ~= "." and fname ~= ".." ) then
                local time = os.time ()
                print ("--output " .. output_dir
                        .. " already exists and is not empty. Save measurement into subdirectory " .. time)
                output_dir = output_dir .. "/" .. time
                local status, err = lfs.mkdir ( output_dir )
                break
            end
        end
    else
        print ( "resume keys: " .. table_to_string ( keys ) )
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
    print ( table_tostring ( args.ap ) )
    print ( )
    print ( "Stations:" )
    print ( )
    print ( table_tostring ( args.sta ) )
    print ( )
end

-- local ctrl iface
local net = NetIF:create ( args.net_if )
net:get_addr()

if ( net.addr == nil ) then
    print ( "Cannot get IP address of local interface" )
    os.exit (1)
end

-- remote control node interface
local ctrl_ref = ControlNodeRef:create ( args.ctrl_port
                                       , output_dir
                                       , args.log_file
                                       , args.log_port
                                       , args.distance
                                       , net
                                       , nameserver or args.nameserver
                                       , args.ctrl, args.ap, args.sta
                                       , connections
                                       , ap_setups, sta_setups
                                       , args.command
                                       )

if ( ctrl_ref == nil ) then
    print ( "Error: Cannot reach nameserver" )
    os.exit (1)
end

if ( ctrl_ref.ctrl_net_ref.addr == nil ) then
    print ( "Error: Cannot get IP address of control node reference" )
    os.exit (1)
end

local ctrl_pid = ctrl_ref:init ( args.disable_autostart
                               , args.disable_synchronize
                               )

if ( ctrl_pid == nil ) then
    print ( "Error: Connection to control node faild" )
    os.exit (1)
end
print ()

local succ, err = ctrl_ref:init_nodes ( args.disable_autostart
                                      , args.disable_reachable
                                      , args.disable_synchronize
                                      )
if ( succ == false ) then
    print ( "Error: " .. err )
    ctrl_ref:cleanup ( args.disable_autostart )
    os.exit (1)
else
    print ( "All nodes connected" )
end

-- ----------------------------------------------------------

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
    print ( table_tostring ( wifi_stations ) )
    print ()
end

print ( ctrl_ref:__tostring() )
print ( )

if ( args.dry_run ) then 
    print ( "dry run is set, quit here" )
    ctrl_ref:cleanup ( args.disable_autostart )
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

ctrl_ref:cleanup ( args.disable_autostart )
os.exit ( 0 )
