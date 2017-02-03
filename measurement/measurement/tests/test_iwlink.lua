require ('parsers/iw_link')
require ('spawn_pipe')

local iwlink_proc = spawn_pipe( "iw", "dev", "wlan0", "link" )
iwlink_proc['proc']:wait()
local iwlink = parse_iwlink ( iwlink_proc['out']:read("*a") )
print ( tostring ( iwlink ) )
