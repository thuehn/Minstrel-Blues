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
require ('ControlNode')
require ('Config')
require ('net')

function start_control ( ctrl_net, log_net, ctrl_port, log_port )
    local ctrl = spawn_pipe ( "lua", "bin/runControl.lua"
                            , "--port", ctrl_port
                            , "--ctrl_if", ctrl_net.iface
                            , "--log_if", log_net.iface
                            , "--log_ip", log_net.addr
                            , "--log_port", log_port 
                            )
    if ( ctrl ['err_msg'] ~= nil ) then
        self:send_warning("Control not started" .. ctrl ['err_msg'] )
    end
    close_proc_pipes ( ctrl )
    local str = ctrl['proc']:__tostring()
    local proc = parse_process ( str ) 
    print ( "Control: " .. str )
    return proc
end

function start_control_remote ( ctrl_net, log_net, ctrl_port, log_port )
     local remote_cmd = "lua bin/runControl.lua"
                 .. " --port " .. ctrl_port 
                 .. " --ctrl_if " .. ctrl_net.iface
     if ( log_net.iface ~= nil ) then
        remote_cmd = remote_cmd .. " --log_if " .. log_net.iface
     end

     if ( log_net.addr ~= nil and log_port ~= nil ) then
        remote_cmd = remote_cmd .. " --log_ip " .. log_net.addr 
                 .. " --log_port " .. log_port 
     end
     print ( remote_cmd )
     local ssh = spawn_pipe("ssh", "root@" .. ctrl_net.addr, remote_cmd)
     close_proc_pipes ( ssh )
end

function connect_control ( ctrl_ip, ctrl_port )
    function connect ()
        local l, e = rpc.connect ( ctrl_ip, ctrl_port )
        return l, e
    end
    return pcall ( connect )
end

function stop_control ( pid )
    kill = spawn_pipe("kill", pid)
    close_proc_pipes ( kill )
end

function stop_control_remote ( addr, pid )
    print ( addr )
    local ssh = spawn_pipe("ssh", "root@" .. addr, "kill " .. pid )
    local exit_code = ssh['proc']:wait()
    close_proc_pipes ( ssh )
end

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

parser:option ("--ctrl", "Control node host name" )
parser:option ("--ctrl_ip", "IP of Control node" )
parser:option ("--ctrl_if", "RPC Interface of Control node" )
parser:option ("-C --ctrl_port", "Port for control RPC", "12346" )
parser:flag ("--ctrl_only", "Just connect with control node", false )

parser:option ("--log", "Logger host name")
parser:option ("--log_ip", "IP of Logging node" )
parser:option ("--log_if", "RPC Interface of Logging node" )
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

local has_config = load_config ( args.config ) 

local ap_setup
local sta_setup

-- load config from a file
if ( has_config ) then

    if ( ctrl == nil ) then
        print ( "Error: config file '" .. get_config_fname ( args.config ) 
                    .. "' have to contain at least one station node description in var 'stations'.")
        os.exit(1)
    end

    if ( args.ctrl_only == false ) then
        if (table_size ( nodes ) < 2) then
            print ( "Error: config file '" .. get_config_fname ( args.config ) 
                        .. "' have to contain at least two node descriptions in var 'nodes'.")
            os.exit(1)
        end

        if (table_size ( connections ) < 1) then
            print ( "Error: config file '" .. get_config_fname ( args.config )
                        .. "' have to contain at least one connection declaration in var 'connections'.")
            os.exit(1)
        end
    end

    -- overwrite config file setting with command line settings
    set_config_from_arg ( ctrl, 'ctrl_if', args.ctrl_if )
    set_config_from_arg ( log, 'ctrl_if', args.log_if )

    ap_setups = accesspoints ( nodes, connections )
    set_configs_from_arg ( ap_setups, 'radio', args.ap_radio )
    set_configs_from_arg ( ap_setups, 'ctrl_if', args.ap_ctrl_if )

    sta_setups = stations ( nodes, connections )
    set_configs_from_arg ( sta_setups, 'radio', args.sta_radio )
    set_configs_from_arg ( sta_setups, 'ctrl_if', args.sta_ctrl_if )

else

    if ( args.ctrl ~= nil ) then
        ctrl = create_config ( args.ctrl, args.ctrl_if ) 
    else
        show_config_error ( parser, "ctrl", true)
    end

    if ( args.ctrl_only == false ) then
        if (args.ap == nil or table_size ( args.ap ) == 0 ) then
            show_config_error ( parser, "ap", true)
        end

        if (args.sta == nil or table_size ( args.sta ) == 0 ) then
            show_config_error ( parser, "sta", true)
        end
    end

    ap_setups = create_configs ( arg.ap, args.ap_radio, args.ap_ctrl_if )
    sta_setups = create_configs ( args.sta, args.sta_radio, args.sta_ctrl_if )
    copy_config_nodes ( ap_setups, nodes )
    copy_config_nodes ( sta_setups, nodes )
    -- fixme: build connection list
    -- i.e. --ap=A --sta=B --sta=C --ap=D --sta=E (use lua args to detect order [ap,sta,sta,ap,sta])
    -- or --ap=A --ap=D --sta=B --sta=C --sta=E --connect=A:B,C --connect=D:E
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

local aps_config = select_configs ( ap_setups, args.ap ) 
if ( aps_config == {} ) then os.exit(1) end

local stas_config = select_configs ( sta_setups, args.sta )
if ( stas_config == {} ) then os.exit(1) end

local ctrl_config = select_config ( nodes, args.ctrl )
if ( ctrl_config == nil ) then os.exit(1) end

print ( "Configuration:" )
print ( "==============" )
print ( )
print ( "Command: " .. args.command )
print ( )
print ( "Control: " .. cnode_to_string ( ctrl_config ) )
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

local ctrl_pid

-- ctrl iface
local net = NetIF:create ( "ctrl", "eth0" )
if ( net:get_addr() == nil ) then
    net = NetIF:create ( "ctrl", "br-lan" )
    net:get_addr()
end

-- ctrl node iface, ctrl node (name) lookup
local ctrl_net = NetIF:create ( "ctrl", ctrl_config['ctrl_if'] )
ctrl_net.addr = args.ctrl_ip
if ( ctrl_net.addr == nil) then
    local ip_addr = lookup ( ctrl_config['name'] )
    if ( ip_addr ~= nil ) then
        ctrl_net.addr = ip_addr
    end 
end

if ( args.disable_autostart == false ) then
    if ( ctrl_net.addr ~= nil and ctrl_net.addr ~= net.addr ) then
        start_control_remote ( ctrl_net, ctrl_net, args.ctrl_port, args.log_port )
    else
        local ctrl_proc = start_control ( ctrl_net, ctrl_net, args.ctrl_port, args.log_port )
        ctrl_pid = ctrl_proc['pid']
    end
end

-- ---------------------------------------------------------------

if ( args.disable_autostart == false ) then
    print ( "Wait for 5 seconds for control node to come up")
    os.sleep ( 5 )
end

-- connect to control

if rpc.mode ~= "tcpip" then
    print ( "Err: rpc mode tcp/ip is supported only" )
    os.exit(1)
end

local ctrl_status, ctrl_rpc, err = connect_control ( ctrl_net.addr, args.ctrl_port )
if ( ctrl_status == false ) then
    print ( "Err: Connection to control node failed" )
    print ( "Err: no node at address: " .. ctrl_net.addr .. " on port: " .. args.ctrl_port )
    os.exit(1)
end
for _, ap_config in ipairs ( aps_config ) do
    ctrl_rpc.add_ap ( ap_config.name,  ap_config['ctrl_if'], args.ctrl_port )
end

for _, sta_config in ipairs ( stas_config ) do
    ctrl_rpc.add_sta ( sta_config.name,  sta_config['ctrl_if'], args.ctrl_port )
end

ctrl_pid = ctrl_rpc.get_pid()

print ( "Control node with IP: " .. ( ctrl_rpc.get_ctrl_addr () or "unset" ) )
if ( ctrl_net.addr == nil ) then
    ctrl_net.addr = ctrl_rpc.get_ctrl_addr ()
end
print ()

-- -------------------------------------------------------------------

if ( table_size ( ctrl_rpc.list_nodes() ) == 0 ) then
    error ("no nodes present")
    os.exit(1)
end

print ( "Reachability:" )
print ( "=============" )
print ( )

-- check reachability 
if ( args.disable_reachable == false ) then
    local reached = ctrl_rpc.reachable()
    if ( table_size ( reached ) == 0 ) then
        print ( "No hosts reachables" )
        os.exit (1)
    end
    for addr, reached in pairs ( reached ) do
        if (reached) then
            print ( addr .. ": ONLINE" )
        else
            print ( addr .. ": OFFLINE" )
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
    if ( ctrl_rpc.start ( ctrl_net.addr, args.log_port ) == false ) then
        print ("Error: Not all nodes started")
        os.exit(1)
    end
    print ("wait 5 seconds for nodes initialisation")
    os.sleep (5)
end

-- ----------------------------------------------------------

-- and connect to nodes
print ("connect to nodes at port " .. args.ctrl_port )
if ( ctrl_rpc.connect_nodes ( args.ctrl_port ) == false ) then
    print ("connection failed!")
    os.exit(1)
else
    print ("All nodes connected")
end

print ( "Prepare APs" )
local ap_names = ctrl_rpc.list_aps()
for _, ap_name in ipairs (ap_names ) do
    local wifis = ctrl_rpc.list_wifis ( ap_name )
    ctrl_rpc.set_wifi ( ap_name, wifis[1] )
    local ssid = ctrl_rpc.get_ssid ( ap_name )
    ctrl_rpc.set_ssid ( ap_name, ssid )
end

print ()

print ( "Prepare STAs" )
for _, sta_name in ipairs ( ctrl_rpc.list_stas() ) do
    local wifis = ctrl_rpc.list_wifis ( sta_name )
    ctrl_rpc.set_wifi ( sta_name, wifis[1] )
end

print ( "Associate AP with STAs" )
for ap, stas in pairs ( connections ) do
    for _, sta in ipairs ( stas ) do
        print ( " connect " .. ap .. " with " .. sta )
        ctrl_rpc.add_station ( ap, sta )
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

-- check whether station is connected
-- got the right station? query mac from STA
--if ( table_size ( wifi_stations_target ) < 1 ) then
--    print ("no station connected with access point")
--    os.exit(1)
--end

print ( ctrl_rpc.__tostring() )
print ( )

if (args.dry_run) then 
    print ( "dry run is set, quit here" )
    if ( args.disable_autostart == false ) then
        print ("stop control")
        ctrl_rpc.stop()
    end
    os.exit(1)
end
print ( )

-- -----------------------

local runs = tonumber ( args.runs )

for _, node_name in ipairs ( ctrl_rpc.list_nodes() ) do
    ctrl_rpc.set_ani ( node_name, not args.disable_ani )
end

local data
if (args.command == "tcp") then
    data = { runs, args.tcpdata }
elseif (args.command == "mcast") then
    data = { runs, args.interval }
elseif (args.command == "udp") then
    data = { runs, args.packet_sizes, args.cct_intervals, args.packet_rates, args.interval }
else
    show_config_error ( parser, "command")
end
local status = ctrl_rpc.run_experiments ( args.command, data, ap_names )

if (status == true) then
    print ( )
    for name, stats in pairs ( ctrl_rpc.get_stats() ) do
        local measurement = Measurement:create ()
        measurement.regmon_stats = stats [ 'regmon_stats' ]
        measurement.tcpdump_pcaps = stats [ 'tcpdump_pcaps' ]
        measurement.cpuage_stats = stats [ 'cpusage_stats' ]
        measurement.rc_stats = stats [ 'rc_stats' ]
        print ( name )
        print ( measurement:__tostring() )
        print ( )
    end
end

-- -----------------------

ctrl_rpc.disconnect_nodes()

-- kill nodes if desired by the user
-- fixme: logger not destroyed
if ( args.disable_autostart == false ) then
    print ("stop control")
    ctrl_rpc.stop()
    if ( ctrl_net.addr ~= nil and ctrl_net.addr ~= net.addr ) then
        stop_control_remote ( ctrl_net.addr, ctrl_pid )
    else
        stop_control ( ctrl_pid )
    end
end
