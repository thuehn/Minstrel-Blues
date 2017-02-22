require ('parsers/argparse_con')
require ('misc')

local ap
local stas
local err

ap, sta, err = parse_argparse_con ( "lede-ap=lede-sta" )
assert ( ap == "lede-ap" )
assert ( table_size ( sta ) == 1 )
assert ( sta[1] == "lede-sta" )
assert ( err == nil )

ap, sta, err = parse_argparse_con ( "lede-ap=lede-sta,lede-ctrl" )
assert ( ap == "lede-ap" )
assert ( table_size ( sta ) == 2 )
assert ( sta[1] == "lede-sta" )
assert ( sta[2] == "lede-ctrl" )
assert ( err == nil )

ap, sta, err = parse_argparse_con ( "lede-ap=lede-sta,lede-ctrl,lysithea.local" )
assert ( ap == "lede-ap" )
assert ( table_size ( sta ) == 3 )
assert ( sta[1] == "lede-sta" )
assert ( sta[2] == "lede-ctrl" )
assert ( sta[3] == "lysithea.local" )
assert ( err == nil )

ap, sta, err = parse_argparse_con ( "[lede-ap=lede-sta]" )
assert ( ap == nil )
assert ( table_size ( sta ) == 0 )
assert ( err == "Error: --con argument have to start with an hostname: '[lede-ap=lede-sta]'" )

-- should never happen
ap, sta, err = parse_argparse_con ( "lede-ap = lede-sta" )
assert ( ap == nil )
assert ( table_size ( sta ) == 0 )
assert ( err == "Error: --con missing '=' after hostname lede-ap: ' = lede-sta'" )

-- should never happen
ap, sta, err = parse_argparse_con ( "lede-ap= lede-sta,lede-ctrl" )
assert ( ap == nil )
assert ( table_size ( sta ) == 0 )
assert ( err == "Error: --con missing hostname after '=': ' lede-sta,lede-ctrl'" )

ap, sta, err = parse_argparse_con ( "lede-ap=lede-sta," )
assert ( ap == nil )
assert ( table_size ( sta ) == 0 )
assert ( err == "Error: --con missing hostname after ',': ''" )

ap, sta, err = parse_argparse_con ( "lede-ap=lede-sta:lede-ctrl" )
assert ( ap == nil )
assert ( table_size ( sta ) == 0 )
assert ( err == "Error: --con missing ',' between stations: ':lede-ctrl'" )
