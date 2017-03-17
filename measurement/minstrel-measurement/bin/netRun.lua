-- run a single measurement between access points (APs) and stations (STAs)

-- TODO:
-- - rpc: transfer tcpdump binary lines/packages and stats online to support large experiment with low ram
-- implement experiments as list of closures
-- erease debug table in production ( debug = nil )
-- sample rate rc_stats, regmon-stats, cpusage (how many updates / second) from luci regmon
-- init scripts for nodes
-- io.tmpfile () for writing pcaps?
-- filter pcap by AP and STA mac (bssid)
-- convert signal / rssi : http://www.speedguide.net/faq/how-does-rssi-dbm-relate-to-signal-quality-percent-439
--  rssi is an estimate value and is detemined periodically (temperature changes ambient/background nois in the chip)
-- Rserve / lua Rclient
-- plot (line) signal by powers with fixed rate in one diagram
--  - rate, adjusted txpower, signal
--  -column rate for legend
-- MCS has is own ordering: modulation & coding x channel Mhz x short/long gard interval (SGI/GI)
-- rc_stats: mode guard # -> idx
-- plugin support with loadfile
-- collectd iw info (STA, AP) and iw link (STA) trace
-- derive MeshRef from AcceesspointRef

require ('functional')
pprint = require ('pprint')

local argparse = require "argparse"

local posix = require ('posix') -- sleep

require ('lfs')
require ('misc')

require ('Config')
require ('NetIF')
require ('ControlNodeRef')
require ('Measurement')

local parser = argparse("netRun", "Run minstrel blues multi AP / multi STA mesurement")

parser:argument("command", "tcp, udp, mcast, noop")

-- TODO: use networks instead of hosts, each ap

parser:option ("-c --config", "config file name", nil)

parser:option("--sta", "Station host name"):count("*")
parser:option("--ap", "Access Point host name"):count("*")
parser:option("--con", "Connection between APs and STAs, format: ap_name=sta_name1,sta_name2"):count("*")

parser:option ("--sta_radio", "STA Wifi Interface name")
parser:option ("--sta_ctrl_if", "STA Control Interface")

parser:option ("--ap_radio", "AP Wifi Interface name")
parser:option ("--ap_ctrl_if", "AP Control Monitor Interface")

parser:option ("--ctrl", "Control node host name" )
parser:option ("--ctrl_ip", "IP of Control node" )
parser:option ("--ctrl_if", "RPC Interface of Control node" )
parser:option ("-C --ctrl_port", "Port for control RPC", "12346" )
parser:flag ("--ctrl_only", "Just connect with control node", false )

parser:option ("--log", "Logger host name")
parser:option ("--log_ip", "IP of Logging node" )
parser:option ("--log_if", "RPC Interface of Logging node" )
parser:option ("-L --log_port", "Logging RPC port", "12347" )
parser:option ("-l --log_file", "Logging to File", "measurement.log" )

parser:flag ("--disable_ani", "Runs experiment with ani disabled", false )

parser:option ("--runs", "Number of iterations", "1" )
parser:option ("-T --tcpdata", "Amount of TCP data", "5MB" )
parser:option ("-S --packet_sizes", "Amount of UDP data", "1500" )
parser:option ("-R --packet_rates", "Rates of UDP data", "50,200,600,1200" )
parser:option ("-I --cct_intervals", "send iperf traffic intervals in milliseconds", "20000,50,100,1000" )
parser:option ("-i --interval", "Intervals of TCP or UDP data", "1" )

parser:flag ("--enable_fixed", "enable fixed setting of parameters", false)
parser:option ("--tx_rates", "TX rate indices")
parser:option ("--tx_powers", "TX power indices")

parser:flag ("--disable_reachable", "Don't try to test the reachability of nodes", false )
parser:flag ("--disable_synchronize", "Don't synchronize time in network", false )
parser:flag ("--disable_autostart", "Don't try to start nodes via ssh", false )

parser:flag ("--dry_run", "Don't measure anything", false )

parser:option ("--nameserver", "local nameserver" )

parser:option ("-O --output", "measurement / analyse data directory","/tmp")

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

local has_config = Config.load_config ( args.config ) 

local ap_setups
local sta_setups

if ( isDir ( args.output ) == false ) then
    print ("--output " .. args.output .. " doesn't exists or is not a directory")
    os.exit (1)
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
    Config.set_config_from_arg ( log, 'ctrl_if', args.log_if )
    
    ap_setups = Config.accesspoints ( nodes, connections )
    Config.set_configs_from_arg ( ap_setups, 'radio', args.ap_radio )
    Config.set_configs_from_arg ( ap_setups, 'ctrl_if', args.ap_ctrl_if )

    sta_setups = Config.stations ( nodes, connections )
    Config.set_configs_from_arg ( sta_setups, 'radio', args.sta_radio )
    Config.set_configs_from_arg ( sta_setups, 'ctrl_if', args.sta_ctrl_if )

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

    ap_setups = Config.create_configs ( args.ap, args.ap_radio, args.ap_ctrl_if )
    sta_setups = Config.create_configs ( args.sta, args.sta_radio, args.sta_ctrl_if )
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
    map ( print, args.ap )
    print ( )
    print ( "Stations:" )
    print ( )
    map ( print , args.sta )
    print ( )
end

local aps_config = Config.select_configs ( ap_setups, args.ap ) 
if ( aps_config == {} ) then os.exit (1) end

local stas_config = Config.select_configs ( sta_setups, args.sta )
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

local measurements = {}

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
        local log = ctrl_ref:stop_control ()
        if ( log ~= nil ) then
            local fname = args.output .. "/" .. args.log_file
            local file = io.open ( fname, "w" )
            if ( file ~= nil ) then
               file:write ( log ) 
            end
            file:close()
        end
        if ( ctrl_ref.ctrl.addr ~= nil and ctrl_ref.ctrl.addr ~= net.addr ) then
            ctrl_ref:stop_remote ( ctrl_ref.ctrl.addr, ctrl_pid )
        else
            ctrl_ref:stop ( ctrl_pid )
        end
    end
    ctrl_ref:disconnect ()
end

-- local ctrl iface
net = NetIF:create ( "eth0" )
net:get_addr()
ctrl_ref = ControlNodeRef:create ( ctrl_config['name']
                                 , ctrl_config['ctrl_if'], args.ctrl_ip
                                 , args.output
                                 )

if ( args.disable_autostart == false ) then
    if ( ctrl_ref.ctrl.addr ~= nil and ctrl_ref.ctrl.addr ~= net.addr ) then
        ctrl_pid = ctrl_ref:start_remote ( args.ctrl_port, args.log_file, args.log_port )
    else
        ctrl_pid = ctrl_ref:start ( args.ctrl_port, args.log_file, args.log_port )
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
    if ( ctrl_ref:start_nodes ( ctrl_ref.ctrl.addr, args.log_port ) == false ) then
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

-- synchonize time
if ( args.disable_synchronize == false ) then
    ctrl_ref:set_dates ()
end

-- set nameserver on all nodes
ctrl_ref:set_nameservers ( args.nameserver or nameserver )

print ( "Prepare APs" )
ctrl_ref:prepare_aps ()
print ()

print ( "Prepare STAs" )
ctrl_ref:prepare_stas ()

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
    print ( "Some nodes have a bridged setup, stop here. See log for details." )
    cleanup ()
    os.exit (1)
end

print()

for _, ap_name in ipairs ( ctrl_ref:list_aps() ) do
    print ( "STATIONS on " .. ap_name )
    print ( "==================")
    local wifi_stations = ctrl_ref:list_stations ( ap_name )
    map ( print, wifi_stations )
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
           , args.packet_sizes, args.cct_intervals
           , args.packet_rates, args.interval
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

local status, err = ctrl_ref:run_experiments ( args.command, data, ctrl_ref:list_aps(), args.enable_fixed )
if ( status == false ) then
    print ( "err: experiments failed: " .. ( err or "unknown error" ) )
end

if (status == true) then

    print ()
    local all_stats = ctrl_ref.stats
    for name, stats in pairs ( all_stats ) do

        -- fixme: move to ControlNodeRef
        local mac = ctrl_ref:get_mac( name )
        local measurement = Measurement:create ( name, mac, nil, args.output )
        measurements [ #measurements + 1 ] = measurement
        measurement.regmon_stats = copy_map ( stats.regmon_stats )
        measurement.tcpdump_pcaps = copy_map ( stats.tcpdump_pcaps )
        measurement.cpusage_stats = copy_map ( stats.cpusage_stats )

        local stations = {}
        for station, _ in pairs ( stats.rc_stats ) do
            stations [ #stations + 1 ] = station
        end
        measurement:enable_rc_stats ( stations ) -- resets rc_stats
        measurement.rc_stats = copy_map ( stats.rc_stats )
        measurement.output_dir = args.output

        local status, err = measurement:write ()
        if ( status == false ) then
            print ( "err: can't access directory '" ..  ( args.output or "unset" )
                            .. "': " .. ( err or "unknown error" ) )
        end

        print ( measurement:__tostring() )
        print ( )
    end
end

cleanup ()
