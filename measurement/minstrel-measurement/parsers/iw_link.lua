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

IwLink = { ssid = nil, iface = nil, mac = nil }

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
    local ssid = "nil"
    if (self.ssid ~= nil) then ssid = self.ssid end
    local mac = "nil"
    if (self.mac ~= nil) then mac = self.mac end
    local iface = "nil"
    if (self.iface ~= nil) then iface = self.iface end
    return "IwLink ssid: " .. ssid
            .. " mac: " .. mac
            .. " iface: " .. iface
end

function parse_iwlink ( iwlink )

    local rest = iwlink
    local state = true
    local mac = nil
    local iface = nil
    local ssid = nil

    state, rest = parse_str ( rest, "Not connected." )
    if (state == true) then return nil end

    state, rest = parse_str ( rest, "Connected to " )
    mac, rest = parse_mac ( rest )
    rest = skip_layout( rest )
    state, rest = parse_str ( rest, "(on" )
    rest = skip_layout( rest )
    iface, rest = parse_ide ( rest )
    state, rest = parse_str ( rest, ")" )
    rest = skip_layout( rest )
    state, rest = parse_str ( rest, "SSID: " )
    ssid, rest = parse_ide ( rest )
    -- ...
    
    local out = IwLink:create()
    out.ssid = ssid
    out.mac = mac
    out.iface = iface
    return out
end
