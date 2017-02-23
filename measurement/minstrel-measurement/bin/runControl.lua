
-- The script starts a measurement control node 

require ('ControlNode')
require ('rpc')
local argparse = require ('argparse')

local parser = argparse("runControl", "Run mintrel measurement control node.")
 
parser:option ("--ctrl_if", "Control Interface name", "eth0" )
parser:option ("-C --port", "RPC port", "12346" )

parser:option ("--log_file", "Logging file name", "/tmp/minstrelm.log" )
parser:option ("--log_if", "Logging Interface name", "eth0" )
parser:option ("-L --log_port", "Logging port", "12347" )
parser:option ("--log_ip", "Logging ip address" )


local args = parser:parse ()

if ( args.log_ip == nil ) then
    print ( parser:get_usage() )
end

local net = NetIF:create ( args.ctrl_if )
local log = NetIF:create ( args.log_if, args.log_ip )
local node = ControlNode:create ( "Control", net, args.port, log, args.log_port, args.log_file )

function get_ctrl_addr ( ... ) return node:get_ctrl_addr ( ... ) end
function add_ap ( ... ) return node:add_ap ( ... ) end
function add_sta ( ... ) return node:add_sta ( ... ) end
function reachable ( ... ) return node:reachable ( ... ) end
function start ( ... ) return node:start ( ... ) end
function connect_nodes ( ... ) return node:connect_nodes ( ... ) end
function disconnect_nodes ( ... ) return node:disconnect_nodes ( ... ) end
function run_experiment ( ... ) return node:run_experiment ( ... ) end
function run_experiments ( ... ) return node:run_experiments ( ... ) end
function stop ( ... ) return node:stop ( ... ) end
function __tostring ( ... ) return node:__tostring ( ... ) end
function set_date ( ... ) return node:set_date ( ... ) end
function set_dates ( ... ) return node:set_dates ( ... ) end
function get_pid ( ... ) return node:get_pid ( ... ) end
function kill ( ... ) return node:kill ( ... ) end
function get_logger_addr ( ...  ) return node:get_logger_addr ( ... ) end

function list_nodes ( ... ) return node:list_nodes ( ... ) end
function list_aps ( ... ) return node:list_aps ( ... ) end
function list_stas ( ... ) return node:list_stas ( ... ) end
function list_phys ( ... ) return node:list_phys ( ... ) end
function set_phy ( ... ) return node:set_phy ( ... ) end
function get_phy ( ... ) return node:get_phy ( ... ) end
function link_to_ssid ( ... ) return node:link_to_ssid ( ... ) end
function set_ssid ( ... ) return node:set_ssid ( ... ) end
function get_ssid ( ... ) return node:get_ssid ( ... ) end
function add_station ( ... ) return node:add_station ( ... ) end
function list_stations ( ... ) return node:list_stations ( ... ) end
function set_ani ( ... ) return node:set_ani ( ... ) end
function set_nameserver (...) return node:set_nameserver (...) end
function set_nameservers (...) return node:set_nameservers (...) end
function check_bridges (...) return node:check_bridges (...) end

function get_stats ( ... ) return node:get_stats ( ... ) end

-- make all functions available via RPC
node:run ( args.port )
