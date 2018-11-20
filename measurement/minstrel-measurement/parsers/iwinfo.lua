require ('parsers/parsers')

Iw_Info = { iface = nil
         , ssid = nil -- when connected
         , mac = nil
         , mode = nil
         , channel = nil -- when connected
         , freq = nil -- when connected
         , txpower = nil
         , phy = nil
         }

function Iw_Info:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Iw_Info:create ()
    local o = Iw_Info:new()
    return o
end

function Iw_Info:__tostring() 
    return "Iw_Info iface: " .. ( self.iface or "unset" )
            .. " ssid: " .. ( self.ssid or "unset" )
            .. " mac: " .. ( self.mac or "unset" )
            .. " mode: " .. ( self.mode or "unset" )
            .. " channel: " .. ( self.channel or "unset" )
            .. " freq: " .. ( self.freq or "unset" )
            .. " txpower: " .. ( self.txpower or "unset" )
            .. " phy: " .. ( self.phy or "unset" )
end

function parse_iw_info ( iwinfo )

    local out = Iw_Info:create()

    if ( iwinfo == nil ) then return out end
    if ( string.len ( iwinfo ) == 0 ) then return out end

    local rest = iwinfo
    local state = true

    local iface = nil
    local ssid = nil
    local mac = nil
    local mode = nil
    local channel = nil
    local freq = nil
    local txpower = nil
    local phy = nil

    --stderr
    state, rest = parse_str ( rest, "Usage:" )
    if (state == true) then return nil end

    --stdout
    iface, rest = parse_ide ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "ESSID: " )
    if ( state == true ) then
        -- special characters are allowed in SSIDs
        -- colon, underscore, dot, spaces, period, ...
        -- but avoid pipe
        local add_chars = {}
        add_chars[1] = '-'; add_chars[2] = '_'
        add_chars[3] = "."; add_chars[4] = ':'
        add_chars[5] = "\""
        ssid, rest = parse_ide ( rest, add_chars )
        if ( ssid ~= nil ) then
            ssid = ssid:sub ( 2, -2 )
        end
        rest = skip_layout( rest )
    end

    state, rest = parse_str ( rest, "Access Point: " )
    mac, rest = parse_mac ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "Mode: " )
    mode, rest = parse_ide ( rest )
    rest = skip_layout( rest )

    state, rest = parse_str ( rest, "Channel: " )
    if ( state == true ) then
        channel, rest = parse_num ( rest )
        
        state, rest = parse_str ( rest, " (" )
        freq, rest = parse_real ( rest )
        freq = freq * 1000 
        state, rest = parse_str ( rest, " GHz)" )
        rest = skip_layout( rest )
    end

    state, rest = parse_str ( rest, "Tx-Power: " )
    if ( state == true ) then
        txpower, rest = parse_real ( rest )
        rest = skip_layout( rest )
        state, rest = parse_str ( rest, " dBm" )
        rest = skip_layout( rest )
    end

    --state, rest = parse_str ( rest, "PHY name:" )
    --phy_str, rest = parse_ide ( rest )
    --rest = skip_layout( rest )

    out.iface = iface
    out.ssid = ssid
    out.mac = mac
    out.mode = mode
    if ( channel ~= nil ) then
        out.channel = tonumber ( channel )
    end
    if ( freq ~= nil ) then
        out.freq = tonumber ( freq )
    end
    if ( txpower ~= nil ) then
        out.txpower = tonumber ( txpower )
    else
        out.txpower = nil
    end
    --out.phy = tonumber ( phy )

    return out
end

