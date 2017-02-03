
require ('functional')
require ('Node')
local argparse = require "argparse"
-- parse command line arguments
local parser = argparse("runNode", "Run measurement node")

parser:option ("-n --name", "Node Name" )

-- TODO: try to get ip address from interface with lua socket

parser:option ("--wifi_ip", "Wifi IP-Address", "192.168.1.1" ) -- "127.0.0.1"
parser:option ("--wifi_if", "Wifi Interface", "wlan0" ) -- lo0
parser:option ("--wifi_mon", "Wifi Monitor Interface", "mon0" )

parser:option ("--ctrl_ip", "Control IP-Address", "192.168.2.218" ) -- "127.0.0.1"
parser:option ("--ctrl_if", "Control Monitor Interface", "eth0" ) -- lo0

parser:option ("--log_ip", "IP of Logging node", "192.168.1.141" ) -- "192.168.2.211"

parser:option ("-P --port", "Control RPC port", "12346" )
parser:option ("-L --log_port", "Logging RPC port", "12347" )
parser:option ("-I --iperf_port", "Port for iperf", "12000" )

local args = parser:parse()

local wifi = NetIF:create("wifi", args.wifi_if, args.wifi_ip, args.wifi_mon)
local ctrl = NetIF:create("ctrl", args.ctrl_if , args.ctrl_ip, nil)
local node = Node:create(args.name, wifi, ctrl, args.iperf_port, args.log_ip, args.log_port )

function wifi_devices(...) return node:wifi_devices(...) end

function restart_wifi(...) return node:restart_wifi(...) end

function get_ssid (...) return node:get_ssid(...) end

-- move to netif, to emerge node.wifi:stations and node.wifi2:stations for multi chip systems
function stations(...) return node:stations(...) end

function set_ani (...) return node:set_ani(...) end

function get_linked_ssid(...) return node:get_linked_ssid(...) end
function get_linked_iface(...) return node:get_linked_iface(...) end
function get_linked_mac(...) return node:get_linked_mac(...) end

function get_mac(...) return node:get_mac(...) end
function get_addr(...) return node:get_addr(...) end
function has_lease(...) return node:has_lease(...) end

-- cpuage
function start_cpusage(...) return node:start_cpusage(...) end
function get_cpusage(...) return node:get_cpusage(...) end
function stop_cpusage(...) return node:stop_cpusage(...) end

-- move to netif, to emerge node.wifi:stations and node.wifi2:stations for multi chip systems
function add_monitor(...) return node:add_monitor(...) end

-- rc_stats
function start_rc_stats(...) return node:start_rc_stats(...) end
function get_rc_stats(...) return node:get_rc_stats(...) end
function stop_rc_stats(...) return node:stop_rc_stats(...) end

-- regmon
function start_regmon_stats(...) return node:start_regmon_stats(...) end
function get_regmon_stats(...) return node:get_regmon_stats(...) end
function stop_regmon_stats(...) return node:stop_regmon_stats(...) end

-- tcpdump
function start_tcpdump(...) return node:start_tcpdump(...) end
function get_tcpdump_online(...) return node:get_tcpdump_online(...) end
function get_tcpdump_offline(...) return node:get_tcpdump_offline(...) end
function stop_tcpdump(...) return node:stop_tcpdump(...) end

-- tcp iperf
function start_tcp_iperf_server (...) return node:start_tcp_iperf_server(...) end
function run_tcp_iperf(...) return node:run_tcp_iperf(...) end

-- udp iperf
function start_udp_iperf_s(...) return node:start_udp_iperf_s(...) end
function run_udp_iperf(...) return node:run_udp_iperf(...) end

-- udp / tcp iperf
function stop_iperf_server(...) return node:stop_iperf_server(...) end

function get_pid(...) return node:get_pid(...) end

print(node)
node:run( args.port )
