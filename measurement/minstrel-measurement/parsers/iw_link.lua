require ('parsers/parsers')


--[[
sinope ~ # iw dev wlan0 link
Connected to 6c:fa:a7:1f:3c:f0 (on wlan0)
	SSID: Sagmegar
	freq: 2457
	signal: -58 dBm
	tx bitrate: 65.0 MBit/s
--]]

--[[
root@lede-sta:~# iw dev wlan0 link
Connected to f4:f2:6d:22:7c:f0 (on wlan0)
	SSID: LEDE
	freq: 2462
	RX: 603705 bytes (6264 packets)
	TX: 7906 bytes (68 packets)
	signal: 36 dBm
	tx bitrate: 86.7 MBit/s MCS 12 short GI

	bss flags:	short-preamble short-slot-time
	dtim period:	2
	beacon int:	100
--]]

--[[
root@lede-ap:~# lua test_iwlink.lua 
Not connected.

--]]

IwLink = { ssid = nil
         , iface = nil
         , mac = nil
         , freq = nil
         , signal = nil
         , rate_idx = nil
         , rate = nil
         }

function IwLink:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function IwLink:create ()
    local o = IwLink:new()
    return o
end

function IwLink:__tostring() 
    return "IwLink ssid: " .. ( self.ssid or "unset" )
            .. " mac: " .. ( self.mac or "unset" )
            .. " iface: " .. ( self.iface or "unset" )
            .. " signal (dBm): " .. ( self.signal or "unset" )
            .. " rate " .. ( self.rate or "unset" )
            .. " rate_idx: " .. ( self.rate_idx or "unset" )
end

function parse_iwlink ( iwlink )

    local out = IwLink:create()

    if ( iwlink == nil ) then return out end
    if ( string.len ( iwlink ) == 0 ) then return out end

    local rest = iwlink
    local state = true
    local mac = nil
    local iface = nil
    local ssid = nil
    local freq = nil
    local rx_bytes = nil
    local rx_packets = nil
    local tx_bytes = nil
    local tx_packets = nil
    local signal = nil
    local rate = nil
    local unit = nil
    local rate_idx_part1 = nil
    local rate_idx_part2 = nil
    local rate_idx = nil

    --stderr
    state, rest = parse_str ( rest, "Not connected." )
    if (state == true) then return out end

    --stdout
    state, rest = parse_str ( rest, "Connected to " )
    mac, rest = parse_mac ( rest )
    rest = skip_layout( rest )
    state, rest = parse_str ( rest, "(on" )
    rest = skip_layout( rest )
    iface, rest = parse_ide ( rest )
    state, rest = parse_str ( rest, ")" )
    rest = skip_layout( rest )

    -- special characters are allowed in SSIDs
    -- colon, underscore, dot, spaces, period, ...
    -- but avoid pipe
    state, rest = parse_str ( rest, "SSID: " )
    local add_chars = {}
    add_chars[1] = '-'; add_chars[2] = '_'
    add_chars[3] = "."; add_chars[4] = ':'
    ssid, rest = parse_ide ( rest, add_chars )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "freq: " )
    freq, rest = parse_num ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "RX: " )
    rx_bytes, rest = parse_num ( rest )
    state, rest = parse_str ( rest, " bytes (" )
    rx_packets, rest = parse_num ( rest )
    state, rest = parse_str ( rest, " packets)" )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "TX: " )
    tx_bytes, rest = parse_num ( rest )
    state, rest = parse_str ( rest, " bytes (" )
    tx_packets, rest = parse_num ( rest )
    state, rest = parse_str ( rest, " packets)" )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "signal: " )
    signal, rest = parse_num ( rest )
    state, rest = parse_str ( rest, " dBm" )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "tx bitrate: " )
    rate, rest = parse_real ( rest )
    rest = skip_layout( rest )
    local add_chars = {}
    add_chars[1] = '/'
    unit, rest = parse_ide ( rest, add_chars )

    local c = shead ( rest )
    if ( c ~= '\n' ) then
        rest = skip_layout( rest )

        rate_idx_part1, rest = parse_ide ( rest )
        rest = skip_layout( rest )
        rate_idx_part2, rest = parse_num ( rest )
        rate_idx = rate_idx_part1 .. " " .. rate_idx_part2
    end
    rest = skip_layout( rest )
    -- ...
    
    out.ssid = ssid
    out.mac = mac
    out.iface = iface
    out.signal = tonumber ( signal )
    out.rate = rate .. " " .. unit
    out.rate_idx = rate_idx
    return out
end
