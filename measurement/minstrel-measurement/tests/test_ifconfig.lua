require ('parsers/ifconfig')
require ('spawn_pipe')

local num
local rest
local ide

ide, rest = parse_ide ( "abc0 bcd" )
assert ( ide == "abc0" )
assert ( rest == " bcd" )

num, rest = parse_num ( "123" )
assert ( num == "123" )
assert ( rest == "" )

num, rest = parse_ipv4 ( "127.0.0.1 abc" )
assert ( num == "127.0.0.1" )
assert ( rest == " abc" )

rest = skip_layout ( "    b" )
assert ( rest == "b" )

local add_chars = {}
add_chars[1] = '-'
ide, rest = parse_ide ( "br-lan mf", add_chars)
assert ( ide == "br-lan" )
assert ( rest == " mf" )

local ifconfig_proc = spawn_pipe( "ifconfig", "wlan0" )
ifconfig_proc['proc']:wait()
local ifconfig = parse_ifconfig ( ifconfig_proc['out']:read("*a") )
print ( tostring ( ifconfig ) )

local ifconfig_proc = spawn_pipe( "ifconfig", "eth0" )
ifconfig_proc['proc']:wait()
local ifconfig = parse_ifconfig ( ifconfig_proc['out']:read("*a") )
print ( tostring ( ifconfig ) )

local ifconfig_proc = spawn_pipe( "ifconfig", "br-lan" )
ifconfig_proc['proc']:wait()
local ifconfig = parse_ifconfig ( ifconfig_proc['out']:read("*a") )
print ( tostring ( ifconfig ) )
