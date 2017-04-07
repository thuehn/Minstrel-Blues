require ('bit') -- lua5.3 supports operators &,|,<<,>> natively
local misc = require ('misc')

PCAP = {}

--http://www.radiotap.org/fields/defined

PCAP.radiotap_type = {}
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_TSFT" ] = 1
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_FLAGS" ] = 2
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_RATE" ] = 3
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_CHANNEL" ] = 4
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_FHSS" ] = 5
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_DBM_ANTSIGNAL" ] = 6
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_DBM_ANTNOISE" ] = 7
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_LOCK_QUALITY" ] = 8
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_TX_ATTENUATION" ] = 9
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_DB_TX_ATTENUATION" ] = 10
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_DBM_TX_POWER" ] = 11
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_ANTENNA" ] = 12
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_DB_ANTSIGNAL" ] = 13
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_DB_ANTNOISE" ] = 14
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_RX_FLAGS" ] = 15
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_NS_NEXT" ] = 30
PCAP.radiotap_type [ "IEEE80211_RADIOTAP_EXT" ] = 32

PCAP.radiotap_flags = {}
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_CFP'] = 1
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_SHORTPRE'] = 2
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_WEP'] = 3
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_FRAG'] = 4
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_FCS'] = 5
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_DATAPAD'] = 6
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_BADFCS'] = 7
PCAP.radiotap_flags ['IEEE80211_RADIOTAP_F_SHORTGI'] = 8

PCAP.radiotap_chan_flags = {}
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_TURBO" ] = 5
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_CCK" ] = 6
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_OFDM" ] = 7
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_2GHZ" ] = 8
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_5GHZ" ] = 9
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_PASSIVE" ] = 10
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_DYN" ] = 11
PCAP.radiotap_chan_flags [ "IEEE80211_CHAN_GFSK" ] = 12

PCAP.radiotap_frametype = {}
PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_MGMT" ] = 1
PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_CTRL" ] = 2
PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_DATA" ] = 3

-- type 0: - management frame
PCAP.radiotap_mgmt_frametype = {}
PCAP.radiotap_mgmt_frametype [ "PROBE_REQUEST" ] = 5
PCAP.radiotap_mgmt_frametype [ "PROBE_RESPONSE" ] = 6
PCAP.radiotap_mgmt_frametype [ "BEACON" ] = 9
PCAP.radiotap_mgmt_frametype [ "ACTION" ] = 14

-- type 1: control frame
PCAP.radiotap_ctrl_frametype = {}
PCAP.radiotap_ctrl_frametype [ "80211_BLOCK_ACK" ] = 10
PCAP.radiotap_ctrl_frametype [ "ACKNOWLEDGEMENT" ] = 14

-- type 2: data frame
PCAP.radiotap_data_frametype = {}
PCAP.radiotap_data_frametype [ "DATA" ] = 1
PCAP.radiotap_data_frametype [ "NULL_FUNCTION"] = 5
PCAP.radiotap_data_frametype [ "QOS_DATA" ] = 9

-- converts a number 'mask' with size 'len'
-- into a string in binary representation
-- (in reversed order)
PCAP.bitmask_tostring = function ( mask, len )
    local ret = ""
    for i = 1, len do
        if ( PCAP.hasbit ( mask, PCAP.bit(i) ) )  then
            ret = ret .. "1"
        else
            ret = ret .. "0"
        end
    end
    return ret
end

-- (1 << (p-1))
PCAP.bit = function (p)
    return 2 ^ (p - 1)  -- 1-based indexing
end

-- x & (p-1)
-- x bitmask
-- p bit created by PCAP.bit
PCAP.hasbit = function (x, p)
  return x % (p + p) >= p       
end

-- converts a string 'str' into decimal representation (ascii) 
PCAP.to_bytes = function ( str )
    local bytes = ""
    for i = 1, #str do
        if ( i ~= 1 ) then bytes = bytes .. " " end
        bytes = bytes .. string.byte ( str, i )
    end
    return bytes
end

-- converts a string 'str' into hexadecimal representation (ascii) 
PCAP.to_bytes_hex = function ( str, len )
    local bytes = ""
    local count = #str
    if ( len ~= nil ) then
        count = len
    end
    for i = 1, count do
        if ( i ~= 1 ) then bytes = bytes .. " " end
        bytes = bytes .. string.format("%02x", string.byte ( str, i ) )
    end
    return bytes
end

-- read one byte from head of 'bytes' and truncate it from
-- (unsigned)
PCAP.read_int8 = function ( bytes, pos )
    return string.byte ( bytes, 1 ), string.sub ( bytes, 2 ), pos + 1
end

-- read one byte from head of 'bytes' and truncate it from
-- (signed)
-- 2-complement already known by lua
PCAP.read_int8_signed = function ( bytes, pos )
    local num, rest, pos = PCAP.read_int8 ( bytes, pos )
    if ( num > 127 ) then num = num - 256 end
    return num, rest, pos
end

-- read short number from head of 'bytes' and truncate from
-- (unsigned)
PCAP.read_int16 = function ( bytes, pos )
    return bit.lshift( string.byte ( bytes, 2 ), 8) 
        + string.byte ( bytes, 1 ), string.sub ( bytes, 3 ), pos + 2
end

-- read number (little endian) from head of 'bytes' and truncate from
-- (unsigned)
PCAP.read_int32 = function ( bytes, pos )
    local num = bit.lshift ( string.byte ( bytes, 4 ), 24)
        + bit.lshift ( string.byte ( bytes, 3 ), 16)
        + bit.lshift ( string.byte ( bytes, 2 ), 8)
        + string.byte ( bytes, 1 )
    return num, string.sub ( bytes, 5 ), pos + 4
end

PCAP.read_int32_big = function ( bytes, pos )
    local num = bit.lshift ( string.byte ( bytes, 1 ), 24)
        + bit.lshift ( string.byte ( bytes, 2 ), 16)
        + bit.lshift ( string.byte ( bytes, 3 ), 8)
        + string.byte ( bytes, 4 )
    return num, string.sub ( bytes, 5 ), pos + 4
end

-- read long number from head of 'bytes' and truncate from
PCAP.read_int64 = function ( bytes, pos )
    local rest = bytes
    local high, rest, pos = PCAP.read_int32 ( rest, pos )
    local low, rest, pos = PCAP.read_int32 ( rest, pos )
    local num = bit.lshift ( low, 32 ) + high
    return num, rest, pos
end

-- read 6 bytes from head of 'bytes' and truncate from
PCAP.read_mac = function ( bytes, pos )
    local ret = {}
    for i = 1, 6 do
        ret [ #ret + 1] = string.byte ( bytes, i )
    end
    local rest = string.sub ( bytes, 6 + 1 )
    return ret, rest, pos + 6
end

-- convert 6 bytes array 'mac' into mac address string
-- fixme: duplicate
PCAP.mac_tostring = function ( mac )
    if ( mac == nil ) then return nil end
    if ( #mac ~= 6 ) then return "not a mac addr" end
    local ret = ""
    for i = 1, 6 do
        if ( i ~= 1 ) then ret = ret .. ":" end
        ret = ret .. string.format("%02x", mac [i])
    end
    return ret
end

-- read 'len' bytes from head of 'bytes' and truncate from
-- return red bytes as string
PCAP.read_str = function ( bytes, len, pos )
    local str = ""
    local rest = bytes
    for i = 1, len do
        local c
        c, rest, pos = PCAP.read_int8 ( rest, pos )
        str = str .. string.char ( c )
    end
    return str, rest, pos
end

PCAP.align = function ( bytes, align, pos, start_pos )
    if ( start_pos == nil ) then start_pos = 0 end
    local rest = bytes
    local skip = ( pos - start_pos ) % align
    print ( "skip: "..skip )
    if ( skip == 0 ) then return bytes, pos end
    for i = 1, ( pos - start_pos ) % align do
        _, rest, pos = PCAP.read_int8 ( rest, pos )
    end
    return rest, pos
end

function PCAP.open ( fname )
    local file = io.open ( fname, "rb" )
    local rest = file:read ( "*a" )
    if ( file ~= nil and rest ~= nil and rest ~= "" ) then
        local pos
        rest, pos = PCAP.parse_pcap_header ( rest )
        return file, rest, pos
    end
    return nil, nil, nil
end

function PCAP.parse_pcap_header ( rest )
    local pos = 0

    -- PCAP header
    _, rest, pos = PCAP.read_int32 ( rest, pos ) -- byte order, magic number
    _, rest, pos = PCAP.read_int16 ( rest, pos ) -- major version number
    _, rest, pos = PCAP.read_int16 ( rest, pos ) -- minor version number
    _, rest, pos = PCAP.read_int32 ( rest, pos ) -- signed GMT to local correction
    _, rest, pos = PCAP.read_int32 ( rest, pos ) -- accuracy of timestamps
    _, rest, pos = PCAP.read_int32_big ( rest, pos ) -- snaplen
    _, rest, pos = PCAP.read_int32 ( rest, pos ) -- network, data link type

    return rest, pos
end

function PCAP.parse_packet_header ( rest, pos )
    -- packet header
    _, rest, pos = PCAP.read_int32 ( rest, pos ) -- timestamp seconds
    _, rest, pos = PCAP.read_int32 ( rest, pos ) -- timestamp microseconds

    local incl_len
    incl_len, rest, pos = PCAP.read_int32_big ( rest, pos ) -- number of octets of packet saved in file
    --print ( "incl_len: " .. incl_len )

    local orig_len
    orig_len, rest, pos = PCAP.read_int32_big ( rest, pos ) -- actual length of packet
    --print ( "orig_len: " .. orig_len )

    return incl_len, rest, pos
end

function PCAP.get_packet ( rest, pos )
    local old_pos = pos

    local incl_len
    incl_len, rest, pos = PCAP.parse_packet_header ( rest, pos )

    local packet = string.sub ( rest, 0, incl_len + 16 )

    ----for i = 1, incl_len  do
    ----    byte, rest, pos = PCAP.read_int8 ( rest, pos )
    ----end

    local next_pos = old_pos + incl_len + 16
    rest = string.sub ( rest, ( next_pos - pos ) + 1 )
    --print ( PCAP.to_bytes_hex ( rest ) )

    pos = next_pos
    return packet, incl_len, rest, pos
end

-- parse the radiotap data block
-- (bssid, ssid only)
-- block may be truncated by tcpdump
PCAP.parse_radiotap_data = function ( capdata, length, header_length, pos )

    local start_pos = pos

    local ret = {}
    local rest = capdata

    print ( "header length: " .. header_length )
    print ( "startpos: " .. pos )
    print ( "length: " .. length )
    print ( "capdata: " .. PCAP.to_bytes_hex ( rest, 16 ) )
    --local frame_control_field, rest = PCAP.read_int16 ( rest )

    local mask, rest, pos = PCAP.read_int8 ( rest, pos )
    --         00
    -- bit 1,2 version (0)
    local version = 0
    if ( PCAP.hasbit ( mask, PCAP.bit (1) ) ) then
        version = version + 1
    end
    if ( PCAP.hasbit ( mask, PCAP.bit (2) ) ) then
        version = version + 2
    end

    --       00
    -- type: management frame (0)
    local frame_type = 0
    if ( PCAP.hasbit ( mask, PCAP.bit (3) ) ) then
        frame_type = frame_type + 1
    end
    if ( PCAP.hasbit ( mask, PCAP.bit (4) ) ) then
        frame_type = frame_type + 2
    end
    ret ['type'] = frame_type
    --print ( frame_type )

    --   0001
    -- subtype (8)
    local frame_subtype = 0
    if ( PCAP.hasbit ( mask, PCAP.bit (5) ) ) then
        frame_subtype = frame_subtype + 1
    end
    if ( PCAP.hasbit ( mask, PCAP.bit (6) ) ) then
        frame_subtype = frame_subtype + 2
    end
    if ( PCAP.hasbit ( mask, PCAP.bit (7) ) ) then
        frame_subtype = frame_subtype + 4
    end
    if ( PCAP.hasbit ( mask, PCAP.bit (8) ) ) then
        frame_subtype = frame_subtype + 8
    end
    ret ['subtype'] = frame_subtype
    --print ( frame_subtype )

    -- 8 bit flags
    local flags
    flags, rest, pos = PCAP.read_int8 ( rest, pos )
    --print ( PCAP.bitmask_tostring ( flags, 8 ) )

    local duration
    duration, rest, pos = PCAP.read_int16 ( rest, pos )

    -- receiver / destination address
    local da
    da, rest, pos = PCAP.read_mac ( rest, pos )
    --print ( PCAP.mac_tostring ( da ) )
    ret [ 'da' ] = da

    -- transmitter / source address
    local sa
    sa, rest, pos = PCAP.read_mac ( rest, pos )
    --print ( PCAP.mac_tostring ( sa ) )
    ret [ 'sa' ] = sa

    local bssid
    bssid, rest, pos = PCAP.read_mac ( rest, pos )
    --print ( PCAP.mac_tostring ( bssid ) )
    ret [ 'bssid' ] = bssid

    -- 2 bytes bitmask ( fragment number 0 .. 3, seq num 4 .. 15
    _, rest, pos = PCAP.read_int16 ( rest, pos )

    --if ( frame_type == 0 and frame_subtype == 8 ) then

        print ( "rest: " .. PCAP.to_bytes_hex ( rest, 16 ) )
        -- 12 bytes fixed parameters
        -- - 8 bytes timestamp
        -- - 2 bytes beacon interval in seconds
        -- - 2 bytes capability bitmask
        for i = 1, 12 do
            _, rest, pos = PCAP.read_int8 ( rest, pos )
        end

        -- tagged parameter
        ret [ 'ssid' ] = ""
        print ( "pos: " .. pos )
        while ( pos < ( ( length + start_pos ) - header_length ) ) do
            
            print ( "pos: " .. pos )
            print ( PCAP.to_bytes_hex ( rest, 24 ) )

            local tag_number
            local tag_length

            tag_number, rest, pos = PCAP.read_int8 ( rest, pos )
            tag_length, rest, pos = PCAP.read_int8 ( rest, pos )
            print ( "tag num: " .. tag_number )
            print ( "tag len: " .. tag_length )
            for i=1, tag_length do
                if ( pos + 1 > ( ( length + start_pos ) - header_length ) ) then
                    -- truncated packet
                    break
                end
                local tag
                tag, rest, pos = PCAP.read_int8 ( rest, pos )
                -- 0: ssid
                if ( tag_number == 0 ) then
                    ret ['ssid'] = ret ['ssid' ] .. string.char ( tag )
                end
                -- 1: supported rates
                -- 3: current cannel
                -- 5: traffic indication map
                -- 7: country code
                -- 42: ERP information
                -- 50: extended supported rates
                -- 48: RSN information
                -- 45: HT capabilities
            end
        end

    --end
    
    print ( "rest: " .. PCAP.to_bytes_hex ( rest, 16 ) )

    return ret, rest, pos
end

-- parse radiotap header from head of 'capdata' and truncate the whole
-- header block from 'capdata'
-- (currently the first 16 sub blocks are parsed only)
-- alignment in sub blocks doesn't matter because of the absence of memory mapping
PCAP.parse_radiotap_header = function ( capdata, pos )

    local start_pos = pos
    -- https://www.kernel.org/doc/Documentation/networking/radiotap-headers.txt
    -- 1 byte it_version header version (always 0)
    -- 1 byte .          padding ( to fit alignment )
    -- 2 bytes it_len    total header and sub block length
    -- 4 byte it_present bitmask ( bit 31 is set when theres a 64bit bitmask instead of a 32bit bitmask

    local ret = {}
    local rest = capdata

    --print ( PCAP.to_bytes_hex ( rest ) )
    --print ()

    print ( PCAP.to_bytes_hex ( rest, 8 ) )
    ret ['it_ver'], rest, pos = PCAP.read_int8 ( rest, pos )
    _, rest, pos = PCAP.read_int8 ( rest, pos ) -- 1 byte fixed padding
    ret ['it_len'], rest, pos = PCAP.read_int16 ( rest, pos )
    ret ['it_present'], rest, pos = PCAP.read_int32 ( rest, pos )
    
    print ( PCAP.to_bytes_hex ( rest, tonumber ( ret ['it_len'] ) ) )

    local antennas = {}
    antennas [ 1 ] = true
    local has_ext = PCAP.hasbit( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ "IEEE80211_RADIOTAP_EXT" ] ) )
    --print ( PCAP.to_bytes ( rest ) )
    --print ( )
    if ( has_ext ) then
        ret ['it_present_ex'], rest, pos = PCAP.read_int32 ( rest, pos )
        -- #antennas
        local bitmask = ret ['it_present_ex']
        repeat
            antennas [ #antennas + 1 ] = true
            --print ( "read mask" )
            bitmask, rest, pos = PCAP.read_int32 ( rest, pos )
            local cont = PCAP.hasbit ( bitmask, PCAP.bit ( PCAP.radiotap_type [ "IEEE80211_RADIOTAP_NS_NEXT" ] ) )
            --print ( "next: " .. tostring ( cont ) )
        until ( cont == false )
    end
    print ("after bitmasks: " .. PCAP.to_bytes_hex ( rest, tonumber ( ret ['it_len'] ) ) )

    --print ( PCAP.to_bytes_hex ( rest ) )
    --print ( )
    print ( "pos: " ..pos )
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_TSFT' ] )  ) ) then
        rest, pos = PCAP.align ( rest, 8, pos, start_pos )
        print ( "pos: " ..pos )
        print ("after align: " .. PCAP.to_bytes_hex ( rest, tonumber ( ret ['it_len'] ) ) )
        ret ['tsft'], rest, pos = PCAP.read_int64 ( rest, pos )
        print (ret ['tsft'])
    end
    print ( PCAP.to_bytes_hex ( rest, tonumber ( ret ['it_len'] ) ) )
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_FLAGS' ] )  ) ) then
        ret ['flags'], rest, pos = PCAP.read_int8 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_RATE' ] )  ) ) then
        ret ['rate'], rest, pos = PCAP.read_int8 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_CHANNEL' ] )  ) ) then
        rest, pos = PCAP.align ( rest, 2, pos, start_pos )
        ret ['channel'], rest, pos = PCAP.read_int16 ( rest, pos )
        ret ['channel_flags'], rest, pos = PCAP.read_int16 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_FHSS' ] )  ) ) then
        ret ['fhss_hop_set'], rest, pos = PCAP.read_int8 ( rest, pos )
        ret ['fhss_hop_pattern'], rest, pos = PCAP.read_int8 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DBM_ANTSIGNAL' ] )  ) ) then
        ret ['antenna_signal'], rest, pos = PCAP.read_int8_signed ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DBM_ANTNOISE' ] )  ) ) then
        ret ['antenna_noise'], rest, pos = PCAP.read_int8_signed ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_LOCK_QUALITY' ] )  ) ) then
        rest, pos = PCAP.align ( rest, 2, pos, start_pos )
        ret ['lock_quality'], rest, pos = PCAP.read_int16 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_TX_ATTENUATION' ] )  ) ) then
        rest, pos = PCAP.align ( rest, 2, pos, start_pos )
        ret ['tx_attenuation'], rest, pos = PCAP.read_int16 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DBM_TX_POWER' ] )  ) ) then
        rest, pos = PCAP.align ( rest, 1, pos, start_pos ) -- fixme: always true, ???
        ret ['tx_power'], rest, pos = PCAP.read_int8_signed ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_ANTENNA' ] )  ) ) then
        ret ['db_antenna'], rest, pos = PCAP.read_int8 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DB_ANTSIGNAL' ] )  ) ) then
        ret ['db_antenna_signal'], rest, pos = PCAP.read_int8 ( rest, pos )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DB_ANTNOISE' ] )  ) ) then
        ret ['db_antenna_noise'], rest, pos = PCAP.read_int8 ( rest, pos )
    end
    print ( "rx_flags: " .. PCAP.to_bytes_hex ( rest, 16 ) )
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_RX_FLAGS' ] )  ) ) then
        rest, pos = PCAP.align ( rest, 2, pos, start_pos )
        ret ['rx_flags'], rest, pos = PCAP.read_int16 ( rest, pos )
    end

    print ( "antennas: " .. PCAP.to_bytes_hex ( rest, 16 ) )
    if ( true ) then -- fixme: find condition
        for _, _ in ipairs ( antennas ) do
            antenna_signal, rest, pos = PCAP.read_int8_signed ( rest, pos )
            antenna_index, rest, pos = PCAP.read_int8 ( rest, pos )
            ret ['antenna_signal' .. tostring ( antenna_index ) ] = antenna_signal
        end
    end

    print ( "start_pos: " .. start_pos ) 
    print ( "pos: " .. pos ) 
    print ( "it_len: " .. ret ['it_len'] )
    print ( "head end: " .. PCAP.to_bytes_hex ( rest, 16 ) )
    if ( pos < start_pos + ret ['it_len'] ) then
        for i=pos, start_pos + ret ['it_len'] - 1 do
            _, rest, pos = PCAP.read_int8 (rest, pos)
        end
    end
    print ( "head end (trunc): " .. PCAP.to_bytes_hex ( rest, 16 ) )
    --return ret, string.sub ( capdata, start_pos + ret['it_len'] + 1 ), pos
    return ret, rest, pos
end
