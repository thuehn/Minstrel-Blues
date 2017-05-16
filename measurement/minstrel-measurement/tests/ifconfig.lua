require ('parsers/ifconfig')
local misc = require 'misc'

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

local ifconfig_str, exit_code = misc.execute ( "ifconfig", "wlan0" )
if ( exit_code ~= 0 ) then
    local ifconfig = parse_ifconfig ( ifconfig_str )
    print ( tostring ( ifconfig ) )
else
    print ( ifconfig_str )
end

local ifconfig_str, exit_code = misc.execute ( "ifconfig", "eth0" )
if ( exit_code ~= 0 ) then
    local ifconfig = parse_ifconfig ( ifconfig_str )
    print ( tostring ( ifconfig ) )
else
    print ( ifconfig_str )
end

local ifconfig_str, exit_code = misc.execute ( "ifconfig", "br-lan" )
if ( exit_code ~= 0 ) then
    local ifconfig = parse_ifconfig ( ifconfig_str )
    print ( tostring ( ifconfig ) )
else
    print ( ifconfig_str )
end
