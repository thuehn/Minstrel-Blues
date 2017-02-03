require ('parsers/ifconfig')
require ('spawn_pipe')

local num
local rest
local ide

ide, rest = parse_ide ( "abc0 bcd", "abc0" )
print ( assert ( ide == "abc0" ) )
print ( assert ( rest == " bcd" ) )

num, rest = parse_num ( "123" )
print ( assert ( num == "123" ) )
print ( assert ( rest == "" ) )

num, rest = parse_ipv4 ( "127.0.0.1 abc" )
print ( assert ( num == "127.0.0.1" ) )
print ( assert ( rest == " abc" ) )

rest = skip_layout ( "    b" )
print ( assert ( rest == "b" ) )

ide, rest = parse_ide ( "br-lan mf", '-')
print ( assert ( ide == "br-lan" ) )
print ( assert ( rest == " mf" ) )

local ifconfig_proc = spawn_pipe( "ifconfig", "wlan0" )
ifconfig_proc['proc']:wait()
local ifconfig = parse_ifconfig ( ifconfig_proc['out']:read("*a") )
print ( tostring ( ifconfig ) )
