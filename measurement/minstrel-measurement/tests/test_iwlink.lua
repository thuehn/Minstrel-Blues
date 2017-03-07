require ('parsers/iw_link')
require ('spawn_pipe')


local test = parse_iwlink ( "Connected to f4:f2:6d:22:7c:f0 (on wlan0)\n\tSSID: LEDE\n\tfreq: 2462\n\tRX: 7007190 bytes (72847 packets)\n\tTX: 20015 bytes (226 packets)\n\tsignal: -39 dBm\n\ttx bitrate: 13.0 MBit/s MCS 1\n" )
--print ( "'" .. test:__tostring() .. "'" )

assert ( test.ssid == "LEDE" )
assert ( test.mac == "f4:f2:6d:22:7c:f0" )
assert ( test.iface == "wlan0" )
assert ( test.signal == -39 )
assert ( test.rate_idx == "MCS 1" )
assert ( test.rate == "13 MBit/s" )

local iwlink_proc = spawn_pipe( "iw", "dev", "wlan0", "link" )
local exit_code = iwlink_proc['proc']:wait()
if ( exit_code > 0 ) then
    print ( "'iw dev wlan0 link' not started with exit code: " .. exit_code .. ". reason: " .. ( iwlink_proc['err_msg'] or "unknown error" ) )
end

local output = iwlink_proc['out']:read("*a")
if ( output ~= "") then
    local iwlink = parse_iwlink ( output )
    print ( tostring ( iwlink ) )
end
