config = require ('Config')
require ('misc')

pprint = require ('pprint')

assert ( Config.load_config ( "tests/config_file.lua" ) )

assert ( ctrl == "A" )
assert ( table_size ( connections ) == 2 )
assert ( table_size ( nodes ) == 6 )

local a = Config.find_node ( "A", nodes )
local b = Config.find_node ( "B", nodes )
local c = Config.find_node ( "C", nodes )
local d = Config.find_node ( "D", nodes )
local e = Config.find_node ( "E", nodes )
local f = Config.find_node ( "F", nodes )

assert ( a.name == "A" )
assert ( a.ctrl_if == "eth0" )
assert ( a.radio == "radio0" )

assert ( b.name == "B" )
assert ( Config.cnode_to_string ( b ) == "B\tradio1\teth1" )

assert ( c.name == "C" )
local c2 = Config.create_config ( "C2", "eth1", "radio1" )
assert ( c2.name == "C2" )
assert ( c2.ctrl_if == "eth1" )
assert ( c2.radio == "radio1" )

assert ( d.name == "D" )

assert ( e.name == "E" )

assert ( f.name == "F" )

local fname
local rc = os.getenv("HOME") .. "/.minstrelmrc"
if ( isFile ( rc ) ) then
    fname = rc
end
assert ( Config.get_config_fname ( nil ) == fname )
assert ( Config.get_config_fname ( "config_file.lua" ) == "config_file.lua" )

Config.set_config_from_arg ( d, 'ctrl_if', "wlp1s0" )
assert ( d.ctrl_if == "wlp1s0" )

local x = Config.select_config ( nodes, "A" )
assert ( x ~= nil )
assert ( x.name == "A" )

local nodes_selected = Config.select_configs ( nodes, {"A", "D"} )
assert ( table_size ( nodes_selected ) == 2 )
assert ( nodes_selected[1].name == "A" )
assert ( nodes_selected[2].name == "D" )

local con_names = Config.list_connections ( connections )
assert ( table_size ( con_names ) == 2 )
assert ( con_names[1] == "A" )
assert ( con_names[2] == "D" )

local con1 = Config.get_connections ( connections, "A" )
assert ( con1[1] == "B" )
assert ( con1[2] == "C" )

local con2 = Config.get_connections ( connections, "D" )
assert ( con2[1] == "E" )

local aps = Config.accesspoints ( nodes, connections )
assert ( table_size ( aps ) == 2 )
assert ( aps[1].name == "A" )
assert ( aps[2].name == "D" )

local stations = ( Config.stations ( nodes, connections ) )
assert ( stations[1].name == "B" )
assert ( stations[2].name == "C" )
assert ( stations[3].name == "E" )
