require ('Config')
require ('misc')
require ('ex')
require ('functional')

assert ( load_config ( "tests/config.lua" ) )

assert ( ctrl == "A" )
assert ( table_size ( connections ) == 2 )
assert ( table_size ( nodes ) == 6 )

local a = find_node ( "A", nodes )
local b = find_node ( "B", nodes )
local c = find_node ( "C", nodes )
local d = find_node ( "D", nodes )
local e = find_node ( "E", nodes )
local f = find_node ( "F", nodes )

assert ( a.name == "A" )
assert ( a.ctrl_if == "eth0" )
assert ( a.radio == "radio0" )

assert ( b.name == "B" )
assert ( cnode_to_string ( b ) == "B\tradio1\teth1" )

assert ( c.name == "C" )
local c2 = create_config ( "C2", "eth1", "radio1" )
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
assert ( get_config_fname ( nil ) == fname )
assert ( get_config_fname ( "config.lua" ) == "config.lua" )

set_config_from_arg ( d, 'ctrl_if', "wlp1s0" )
assert ( d.ctrl_if == "wlp1s0" )

local x = select_config ( a, "A" )
assert ( x.name == "A" )

local nodes_selected = select_configs ( nodes, {"A", "D"} )
assert ( table_size ( nodes_selected ) == 2 )
assert ( nodes_selected[1].name == "A" )
assert ( nodes_selected[2].name == "D" )

local con_names = list_connections ( connections )
assert ( table_size ( con_names ) == 2 )
assert ( con_names[1] == "A" )
assert ( con_names[2] == "D" )

local con1 = get_connections ( connections, "A" )
assert ( con1[1] == "B" )
assert ( con1[2] == "C" )

local con2 = get_connections ( connections, "D" )
assert ( con2[1] == "E" )

local aps = accesspoints ( nodes, connections )
assert ( table_size ( aps ) == 2 )
assert ( aps[1].name == "A" )
assert ( aps[2].name == "D" )

local stations = ( stations ( nodes, connections ) )
assert ( stations[1].name == "B" )
assert ( stations[2].name == "C" )
assert ( stations[3].name == "E" )
