
-- The script starts a measurement control node 

require ('ControlNode')
local argparse = require ('argparse')

local parser = argparse ( "runControl", "Run mintrel measurement control node." )
 
parser:option ("--ctrl_if", "Control Interface name", "eth0" )
parser:option ("-C --port", "RPC port", "12346" )

parser:option ("--log_file", "Logging file name", "minstrelm.log" )
parser:option ("-L --log_port", "Logging port", "12347" )
parser:flag ("--enable_fixed", "enable fixed setting of parameters", false)

parser:option ("-O --output", "measurement / analyse data directory","/tmp")

local args = parser:parse ()

local net = NetIF:create ( args.ctrl_if )
print ( net:__tostring () )
local node = ControlNode:create ( "Control", net, args.port, args.log_port, args.log_file
                                , args.output, args.enable_fixed )

function __tostring ( ... ) return node:__tostring ( ... ) end

function restart_wifi_debug ( ... ) return node:restart_wifi_debug() end

function get_board ( ... ) return node:get_board ( ... ) end
function get_boards ( ... ) return node:get_boards ( ... ) end

function add_ap ( ... ) return node:add_ap ( ... ) end
function add_sta ( ... ) return node:add_sta ( ... ) end
function reachable ( ... ) return node:reachable ( ... ) end
function start_nodes ( ... ) return node:start_nodes ( ... ) end
function connect_nodes ( ... ) return node:connect_nodes ( ... ) end
function disconnect_nodes ( ... ) return node:disconnect_nodes ( ... ) end
function init_experiment ( ... ) return node:init_experiment ( ... ) end
function get_keys ( ... ) return node:get_keys ( ... ) end
function get_stats ( ... ) return node:get_stats ( ... ) end
function run_experiment ( ... ) return node:run_experiment ( ... ) end
function stop ( ... ) return node:stop ( ... ) end
function set_date ( ... ) return node:set_date ( ... ) end
function set_dates ( ... ) return node:set_dates ( ... ) end
function get_pid ( ... ) return node:get_pid ( ... ) end
function kill ( ... ) return node:kill ( ... ) end

function get_txpowers ( ... ) return node:get_txpowers ( ... ) end
function get_txrates ( ... ) return node:get_txrates ( ... ) end

function list_nodes ( ... ) return node:list_nodes ( ... ) end
function get_mac ( ... ) return node:get_mac ( ... ) end
function list_aps ( ... ) return node:list_aps ( ... ) end
function list_stas ( ... ) return node:list_stas ( ... ) end
function list_phys ( ... ) return node:list_phys ( ... ) end
function set_phy ( ... ) return node:set_phy ( ... ) end
function get_phy ( ... ) return node:get_phy ( ... ) end
function enable_wifi ( ... ) return node:enable_wifi ( ... ) end
function link_to_ssid ( ... ) return node:link_to_ssid ( ... ) end
function get_ssid ( ... ) return node:get_ssid ( ... ) end
function add_station ( ... ) return node:add_station ( ... ) end
function list_stations ( ... ) return node:list_stations ( ... ) end
function set_ani ( ... ) return node:set_ani ( ... ) end
function set_nameserver (...) return node:set_nameserver (...) end
function set_nameservers (...) return node:set_nameservers (...) end
function check_bridges (...) return node:check_bridges (...) end

-- make all functions available via RPC
print ( node:__tostring() )
node:run ()
