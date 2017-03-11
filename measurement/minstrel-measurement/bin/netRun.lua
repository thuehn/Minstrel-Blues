-- run a single measurement between access points (APs) and stations (STAs)

-- TODO:
-- - rpc: transfer tcpdump binary lines/packages and stats online to support large experiment with low ram
-- built test client with command line arg which router should run the test
--   -- unit test (rpc in init of the unit tests base class)
-- implement experiments as list of closures
-- cleanup nodes before os.exit
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
--
-- rates 0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 30, 31, 32, 33, 34, 35, 36, 37, 40, 41, 42, 43, 44, 45, 46, 47, 120, 121, 122, 123
-- powers 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25

-- /etc/board.json
-- /etc/diag.sh

--TODO: iw info parser

pprint = require ('pprint')

local argparse = require "argparse"
require ('parsers/argparse_con')

local posix = require ('posix') -- sleep

require ('lfs')
require ('misc')

require ('Config')
require ('NetIF')
require ('ControlNodeRef')
require ('Measurement')
require ('FXsnrAnalyser')
require ('DYNsnrAnalyser')
require ('SNRRenderer')

local parser = argparse("netRun", "Run minstrel blues multi AP / multi STA mesurement")

parser:argument("command", "tcp, udp, mcast")

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
-- TODO: replace "/tmp/minstrelm.log" with output_dir/minstrelm.log
parser:option ("-l --log_file", "Logging to File", "/tmp/measurement.log" )

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
parser:flag ("--disable_autostart", "Don't try to start nodes via ssh", false )

parser:flag ("--run_check", "No rpc connections, no meaurements", false )
parser:flag ("--dry_run", "Don't measure anything", false )

parser:option ("--nameserver", "local nameserver" )

parser:flag ("--no_measurement","Disables measurement and reads data from output directory.",false)
parser:option ("-O --output", "measurement / analyse data directory","/tmp")

parser:flag ("-v --verbose", "", false )

local args = parser:parse()

args.command = string.lower ( args.command )
if ( args.command ~= "tcp" and args.command ~= "udp" and args.command ~= "mcast") then
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
end

if ( args.con ~= nil and args.con ~= {} ) then
   connections = {}
end

for _, con in ipairs ( args.con ) do
    local ap, stas, err = parse_argparse_con ( con )
    if ( err == nil ) then
        connections [ ap ] = stas
    else
        print ( err )
    end
end

if ( args.no_measurement == false and table_size ( connections ) == 0 ) then
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

if ( args.no_measurement == false ) then
    
    local ctrl_pid
    local ctrl_rpc
    local ctrl_ref
    local net

    function cleanup ()
        if ( ctrl_rpc == nil ) then return true end

        print ( " disconnect nodes " )
        ctrl_rpc.disconnect_nodes()

        -- kill nodes if desired by the user
        if ( args.disable_autostart == false ) then
            print ( "stop control" )
            ctrl_rpc.stop()
            if ( ctrl_ref.ctrl.addr ~= nil and ctrl_ref.ctrl.addr ~= net.addr ) then
                ctrl_ref:stop_remote ( ctrl_ref.ctrl.addr, ctrl_pid )
            else
                ctrl_ref:stop ( ctrl_pid )
            end
        end
        ctrl_ref.disconnect ( ctrl_rpc )
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

    ctrl_rpc = ctrl_ref:connect ( args.ctrl_port )
    if ( ctrl_rpc == nil) then
        print ( "Connection to control node faild" )
        os.exit (1)
    end
    print ()

    ctrl_ref:init ( ctrl_rpc )
    print ( "Control board: " .. ( ctrl_ref:get_board () or "unknown" ) )
    print ()

    --synchronize time
    local err
    local time = os.date("*t", os.time() )
    local cur_time, err = ctrl_rpc.set_date ( time.year, time.month, time.day, time.hour, time.min, time.sec )
    if ( err == nil ) then
        print ( "Set date/time to " .. cur_time )
    else
        print ( "Set date/time failed: " .. err )
        print ( "Time is: " .. cur_time )
    end

    for _, ap_config in ipairs ( aps_config ) do
        ctrl_rpc.add_ap ( ap_config.name,  ap_config['ctrl_if'], ap_config['rsa_key'] )
    end

    for _, sta_config in ipairs ( stas_config ) do
        ctrl_rpc.add_sta ( sta_config.name,  sta_config['ctrl_if'], sta_config['rsa_key'] )
    end

    ctrl_pid = ctrl_rpc.get_pid()

    print ( "Control node with IP: " .. ( ctrl_rpc.get_ctrl_addr () or "unset" ) )
    if ( ctrl_ref.ctrl.addr == nil ) then
        ctrl_ref.ctrl.addr = ctrl_rpc.get_ctrl_addr ()
    end
    print ()

    -- -------------------------------------------------------------------

    if ( table_size ( ctrl_rpc.list_nodes() ) == 0 ) then
        error ("no nodes present")
        cleanup ()
        os.exit (1)
    end

    print ( "Reachability:" )
    print ( "=============" )
    print ( )

    if ( nameserver ~= nil or args.nameserver ~= nil ) then
        ctrl_rpc.set_nameserver ( args.nameserver or nameserver )
    end

    -- check reachability 
    if ( args.disable_reachable == false ) then
        local reached = ctrl_rpc.reachable()
        if ( table_size ( reached ) == 0 ) then
            print ( "No hosts reachables" )
            cleanup ()
            os.exit (1)
        end
        for addr, reached in pairs ( reached ) do
            if ( reached ) then
                print ( addr .. ": ONLINE" )
            else
                print ( addr .. ": OFFLINE" )
            end
        end
    end
    print ()

    if ( args.run_check == true ) then
        print ( "all checks done. quit here" )
        cleanup ()
        os.exit (1)
    end

    -- and auto start nodes
    if ( args.disable_autostart == false ) then
        if ( ctrl_rpc.start ( ctrl_ref.ctrl.addr, args.log_port ) == false ) then
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
    if ( ctrl_rpc.connect_nodes ( args.ctrl_port ) == false ) then
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
    ctrl_rpc.set_dates ()

    -- set nameserver on all nodes
    ctrl_rpc.set_nameservers ( args.nameserver or nameserver )

    print ( "Prepare APs" )
    local ap_names = ctrl_rpc.list_aps()
    for _, ap_name in ipairs (ap_names ) do
        local wifis = ctrl_rpc.list_phys ( ap_name )
        ctrl_rpc.set_phy ( ap_name, wifis[1] )
        if ( ctrl_rpc.enable_wifi ( ap_name, true ) == true ) then
            local ssid = ctrl_rpc.get_ssid ( ap_name )
            print ( "SSID: " .. ssid )
        end
    end

    print ()

    print ( "Prepare STAs" )
    for _, sta_name in ipairs ( ctrl_rpc.list_stas() ) do
        local wifis = ctrl_rpc.list_phys ( sta_name )
        ctrl_rpc.set_phy ( sta_name, wifis[1] )
        ctrl_rpc.enable_wifi ( sta_name, true )
    end

    --fixme: connections may contain more stations than args.sta

    print ( "Associate AP with STAs" )
    for ap, stas in pairs ( connections ) do
        for _, sta in ipairs ( stas ) do
            print ( " connect " .. ap .. " with " .. sta )
            ctrl_rpc.add_station ( ap, sta )
        end
    end

    -- check bridges
    local all_bridgeless = ctrl_rpc.check_bridges()
    if ( not all_bridgeless ) then
        print ( "Some nodes have a bridged setup, stop here. See log for details." )
        cleanup ()
        os.exit (1)
    end

    print ( "Connect STAs to APs SSID" )
    -- set mode of AP to 'ap'
    -- set mode of STA to 'sta'
    -- set ssid of AP and STA to ssid
    -- fixme: set interface static address
    -- fixme: setup dhcp server for wlan0
    for ap, stas in pairs ( connections ) do
        local ssid = ctrl_rpc.get_ssid ( ap )
        if ( ssid ~= nil ) then
            print ( "SSID: " .. ssid )
            for _, sta in ipairs ( stas ) do
                ctrl_rpc.link_to_ssid ( sta, ssid ) 
            end
        else
            print ( "error: cannot get ssid from acceesspoint" )
            cleanup ()
            os.exit (1)
        end
    end

    print()

    for _, ap_name in ipairs ( ap_names ) do
        print ( "STATIONS on " .. ap_name )
        print ( "==================")
        local wifi_stations = ctrl_rpc.list_stations ( ap_name )
        map ( print, wifi_stations )
        print ()
    end

    print ( ctrl_rpc.__tostring() )
    print ( )

    if ( args.dry_run ) then 
        print ( "dry run is set, quit here" )
        cleanup ()
        os.exit (1)
    end
    print ( )

    -- -----------------------


    local runs = tonumber ( args.runs )

    for _, node_name in ipairs ( ctrl_rpc.list_nodes() ) do
        ctrl_rpc.set_ani ( node_name, not args.disable_ani )
    end

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
    else
        show_config_error ( parser, "command")
    end

    local status, err = ctrl_rpc.run_experiments ( args.command, data, ap_names, args.enable_fixed )
    if ( status == false ) then
        print ( "err: experiments failed: " .. ( err or "unknown error" ) )
    end

    if (status == true) then

        local all_stats = ctrl_rpc.get_stats()
        for name, stats in pairs ( all_stats ) do

            local measurement = Measurement:create ( name, nil, args.output )
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

            print ( name )
            print ( measurement:__tostring() )
            print ( )
        end
    end

    cleanup ()

else -- args.no_measurement

    print ( "measurement disabled: scan output directory " .. args.output )

    for _, name in ipairs ( ( scandir ( args.output ) ) ) do

        if ( name ~= "." and name ~= ".."  and isDir ( args.output .. "/" .. name ) ) then
                       
            if ( Config.find_node ( name, nodes ) ~= nil ) then

                local measurement = Measurement:create ( name, nil, args.output )
                measurement.tcpdump_pcaps = {}
                measurements [ #measurements + 1 ] = measurement

                for _, fname in ipairs ( ( scandir ( args.output .. "/" .. name ) ) ) do

                    if ( fname ~= "." and fname ~= ".."
                        and not isDir ( args.output .. "/" .. name .. "/" .. fname )
                        and isFile ( args.output .. "/" .. name .. "/" .. fname ) ) then

                        if ( string.sub ( fname, #fname - 4, #fname ) == ".pcap" ) then

                            -- lede-ap-1.pcap
                            local key = string.sub ( fname, #name + 2, #fname - 5 )
                            measurement.tcpdump_pcaps [ key ] = ""

                        elseif ( string.sub ( fname, #fname - 3, #fname ) == ".txt" ) then

                            -- lede-ap-1-regmon_stats.txt
                            if ( string.sub ( fname, #fname - 15, #fname - 4 ) == "regmon_stats" ) then
                                local key = string.sub ( fname, #name + 2, #fname - 17 )
                                measurement.regmon_stats [ key ] = ""
                            -- lede-ap-1-cpusage_stats.txt
                            elseif ( string.sub ( fname, #fname - 16, #fname - 4 ) == "cpusage_stats" ) then
                                local key = string.sub ( fname, #name + 2, #fname - 18 )
                                measurement.cpusage_stats [ key ] = ""
                            -- lede-ap-1-rc_stats-a0:f3:c1:64:81:7b.txt
                            elseif ( string.sub ( fname, #fname - 29, #fname - 22 ) == "rc_stats" ) then
                                local key = string.sub ( fname, #name + 2, #fname - 31 )
                                local station = string.sub ( fname, #name + #key + 12, #fname - 4 )
                                if (measurement.stations == nil ) then
                                    measurement.stations = {}
                                end
                                local exists = false
                                for _, s in ipairs ( measurement.stations ) do
                                    if ( s == station ) then
                                        exists = true
                                        break
                                    end
                                end
                                measurement.rc_stats_enabled = true
                                if ( exists == false ) then
                                    measurement.stations [ #measurement.stations + 1 ] = station
                                end
                                if ( measurement.rc_stats [ station ] == nil ) then
                                    measurement.rc_stats [ station ] = {}
                                end
                                measurement.rc_stats [ station ] [ key ] = ""
                            end

                        end
                        
                    end
                end

                measurement:read ()
                print ( measurement:__tostring () )
            end
        end
    end

end

print ("Analayse and plot SNR")
for _, measurement in ipairs ( measurements ) do

    local analyser
    if ( args.enable_fixed == true ) then
        analyser = FXsnrAnalyser:create ()
    else
        analyser = DYNsnrAnalyser:create ()

    end
    analyser:add_measurement ( measurement )
    local snrs = analyser:snrs ()
    --pprint ( snrs )
    --print ( )

    local renderer = SNRRenderer:create ( snrs )

    local dirname = args.output .. "/" .. measurement.node_name
    renderer:run ( dirname )

end
