require ('parsers/parsers')

local ide
local num
local pos
local str
local rest
local state

assert ( shead ( "" ) == nil )
assert ( shead ( "a" ) == "a" )
assert ( shead ( "abc" ) == "a" )
assert ( stail ( "abc" ) == "bc" )

state, rest, pos = skip_line_comment ( "; comment\ncode" , ";", 0 )
assert ( state == true )
assert ( rest == "code")
assert ( pos == 10 )

state, rest, pos = skip_line_comment ( ";; comment\ncode" , ";;" )
assert ( state == true )
assert ( rest == "code")
assert ( pos == nil )

state, rest, pos = parse_str ( "abc", "ab", 0 )
assert ( state == true )
assert ( rest == "c" )
assert ( pos == 2 )

state, rest, pos = parse_str ( "aebc", "ab" )
assert ( pos == nil )
assert ( state == false )
assert ( rest == "aebc" )
assert ( pos == nil )

ide, rest, pos = parse_ide ( "G,M", nil, 0 )
assert ( ide == "G" )
assert ( rest == ",M" )
assert ( pos == 1 )

ide, rest, pos = parse_ide ( "G-C,M", { '-' } )
assert ( ide == "G-C" )
assert ( rest == ",M" )
assert ( pos == nil )

-- fixme: return number
num, rest, pos = parse_num ( "6", 0 )
assert ( tonumber ( num ) == 6 )
assert ( rest == "" )
assert ( pos == 1 )

num, rest, pos = parse_num ( "6" )
assert ( tonumber ( num ) == 6 )
assert ( rest == "" )
assert ( pos == nil )

num, rest, pos = parse_num ( "56" )
assert ( tonumber ( num ) == 56 )
assert ( rest == "" )
assert ( pos == nil )

num, rest, pos = parse_num ( "a6" )
assert ( num == nil )
assert ( rest == "a6" )
assert ( pos == nil )

num, rest, pos = parse_hex_num ( "6", 0 )
assert ( tonumber ( num ) == 6 )
assert ( rest == "" )
assert ( pos == 1 )

num, rest, pos = parse_hex_num ( "6" )
assert ( tonumber ( num ) == 6 )
assert ( rest == "" )
assert ( pos == nil )

num, rest, pos = parse_hex_num ( "A6" )
assert ( num == "A6" )
assert ( rest == "" )
assert ( pos == nil )

-- fixme: return nil
num, rest, pos = parse_hex_num ( "x6" )
assert ( num == "" )
assert ( rest == "x6" )
assert ( pos == nil )

num, rest, pos = parse_real ( "0", 0 )
assert ( num == 0 )
assert ( rest == "" )
assert ( pos == 1 )

num, rest, pos = parse_real ( "0.7" )
assert ( num == 0.7 )
assert ( rest == "" )
assert ( pos == nil )

num, rest, pos = parse_real ( "0.7", 0 )
assert ( num == 0.7 )
assert ( rest == "" )
assert ( pos == 3 )

rest, pos = skip_layout ( "   x", 0 )
assert ( rest == "x" )
assert ( pos == 3 )

rest, pos = skip_layout ( "x  " )
assert ( rest == "x  " )
assert ( pos == nil )

rest, pos = skip_until ( "   x", "x", 0 )
assert ( rest == "x" )
assert ( pos == 3 )

rest, pos = skip_until ( "x  ", "x" )
assert ( rest == "x  " )
assert ( pos == nil )

str, rest, pos = parse_until ( "   x", "x", 0 )
assert ( str == "   " )
assert ( rest == "x" )
assert ( pos == 3 )

str, rest, pos = parse_until ( "x  ", "x" )
assert ( str == "" )
assert ( rest == "x  " )
assert ( pos == nil )

num, rest, pos = parse_hexbyte ( "E6", 0 )
assert ( num == "E6" )
assert ( rest == "" )
assert ( pos == 2 )

num, rest, pos = parse_hexbyte ( "x6" )
assert ( num == nil )
assert ( rest == "x6" )
assert ( pos == nil )

str, rest, pos = parse_mac ( "a5:5f:22:00:aa:bb", 0 )
assert ( str == "a5:5f:22:00:aa:bb" )
assert ( rest == "" )
assert ( pos == 17 )

str, rest, pos = parse_mac ( "x6" )
assert ( str == nil )
assert ( rest == "x6" )
assert ( pos == nil )

str, rest, pos = parse_ipv4 ( "10.10.10.10", 0 )
assert ( str == "10.10.10.10" )
assert ( rest == "" )
assert ( pos == 11 )

str, rest, pos = parse_ipv4 ( "a10" )
assert ( str == nil )
assert ( rest == "a10" )
assert ( pos == nil )

str, rest, pos = parse_ipv6 ( "aa76", 0 )
assert ( str == "aa76" )
assert ( rest == "" )
assert ( pos == 4 )

-- fixme: return nil
str, rest, pos = parse_ipv6 ( "xa76" )
assert ( str == "" )
assert ( rest == "xa76" )
assert ( pos == nil )
