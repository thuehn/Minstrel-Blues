require ('parsers/parsers')

IwInfo = { iface = nil
         , ifindex = nil
         , wdev = nil
         , mac = nil
         , ssid = nil -- when connected
         , mode = nil
         , phy = nil
         , channel = nil -- when connected
         , freq = nil -- when connected
         , width = nil -- when connected
         , center1 = nil -- when connected
         , txpower = nil
         }

function IwInfo:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function IwInfo:create ()
    local o = IwInfo:new()
    return o
end

function IwInfo:__tostring() 
    return "IwInfo iface: " .. ( self.iface or "unset" )
            .. " ifindex: " .. ( self.ifindex or "unset" )
            .. " wdev: " .. ( self.wdev or "unset" )
            .. " mac: " .. ( self.mac or "unset" )
            .. " ssid: " .. ( self.ssid or "unset" )
            .. " mode: " .. ( self.mode or "unset" )
            .. " phy: " .. ( self.phy or "unset" )
            .. " channel: " .. ( self.channel or "unset" )
            .. " freq: " .. ( self.freq or "unset" )
            .. " width: " .. ( self.width or "unset" )
            .. " center1: " .. ( self.center1 or "unset" )
            .. " txpower: " .. ( self.txpower or "unset" )
end

function parse_iwinfo ( iwinfo )

    local out = IwInfo:create()

    if ( iwinfo == nil ) then return out end
    if ( string.len ( iwinfo ) == 0 ) then return out end

    local rest = iwinfo
    local state = true

    local iface = nil
    local ifindex = nil
    local wdev = nil
    local mac = nil
    local ssid = nil
    local mode = nil
    local phy = nil
    local channel = nil
    local freq = nil
    local width = nil
    local center1 = nil
    local txpower = nil

    --stderr
    state, rest = parse_str ( rest, "Usage:" )
    if (state == true) then return nil end

    --stdout
    state, rest = parse_str ( rest, "Interface " )
    iface, rest = parse_ide ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "ifindex " )
    ifindex, rest = parse_num ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "wdev 0x" )
    wdev, rest = parse_hex_num ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "addr " )
    mac, rest = parse_mac ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "ssid " )
    if ( state == true ) then
        local add_chars = {}
        add_chars[1] = '-'
        ssid, rest = parse_ide ( rest, add_chars )
        rest = skip_layout( rest )
    end

    state, rest = parse_str ( rest, "type " )
    mode, rest = parse_ide ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "wiphy " )
    phy, rest = parse_num ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "channel " )
    if ( state == true ) then
        channel, rest = parse_num ( rest )
        
        state, rest = parse_str ( rest, " (" )
        freq, rest = parse_num ( rest )
        state, rest = parse_str ( rest, " MHz), width: " )

        width, rest = parse_num ( rest )
        state, rest = parse_str ( rest, " MHz, center1: " )
        center1, rest = parse_num ( rest )
        state, rest = parse_str ( rest, " MHz" )
        rest = skip_layout( rest )
    end

    state, rest = parse_str ( rest, "txpower " )
    if ( state == true ) then
        txpower, rest = parse_real ( rest )
        state, rest = parse_str ( rest, " dBm" )
        rest = skip_layout( rest )
    end
    
    out.iface = iface
    out.ifindex = tonumber ( ifindex )
    out.wdev = "0x" .. wdev
    out.mac = mac
    out.ssid = ssid
    out.mode = mode
    out.phy = tonumber ( phy )
    if ( channel ~= nil ) then
        out.channel = tonumber ( channel )
    end
    if ( freq ~= nil ) then
        out.freq = tonumber ( freq )
    end
    if ( width ~= nil ) then
        out.width = tonumber ( width )
    end
    if ( center1 ~= nil ) then
        out.center1 = tonumber ( center1 )
    end
    if ( txpower ~= nil ) then
        out.txpower = tonumber ( txpower )
    else
        out.txpower = nil
    end

    return out
end
