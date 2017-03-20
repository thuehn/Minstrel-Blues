require ('bit') -- lua5.3 supports operators &,|,<<,>> natively

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

PCAP.radiotab_frametype = {}
PCAP.radiotab_frametype [ "IEEE80211_FRAMETYPE_MGMT" ] = 1
PCAP.radiotab_frametype [ "IEEE80211_FRAMETYPE_CTRL" ] = 2
PCAP.radiotab_frametype [ "IEEE80211_FRAMETYPE_DATA" ] = 3

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
PCAP.to_bytes_hex = function ( str )
    local bytes = ""
    for i = 1, #str do
        if ( i ~= 1 ) then bytes = bytes .. " " end
        bytes = bytes .. string.format("%x", string.byte ( str, i ) )
    end
    return bytes
end

-- read one byte from head of 'bytes' and truncate it from
-- (unsigned)
PCAP.read_int8 = function ( bytes )
    return string.byte ( bytes, 1 ), string.sub ( bytes, 2 )
end

-- read one byte from head of 'bytes' and truncate it from
-- (signed)
-- 2-complement already known by lua
PCAP.read_int8_signed = function ( bytes )
    local num, rest = PCAP.read_int8 ( bytes )
    if ( num > 127 ) then num = num - 256 end
    return num, rest
end

-- read short number from head of 'bytes' and truncate from
-- (unsigned)
PCAP.read_int16 = function ( bytes )
    return bit.lshift( string.byte ( bytes, 2 ), 8) 
        + string.byte ( bytes, 1 ), string.sub ( bytes, 3 )
end

-- read number (little endian) from head of 'bytes' and truncate from
-- (unsigned)
PCAP.read_int32 = function ( bytes )
    local num = bit.lshift ( string.byte ( bytes, 4 ), 24)
        + bit.lshift ( string.byte ( bytes, 3 ), 16)
        + bit.lshift ( string.byte ( bytes, 2 ), 8)
        + string.byte ( bytes, 1 )
    return num, string.sub ( bytes, 5 )
end

-- read long number from head of 'bytes' and truncate from
PCAP.read_int64 = function ( bytes )
    local rest = bytes
    local high, rest = PCAP.read_int32 ( rest )
    local low, rest = PCAP.read_int32 ( rest )
    local num = bit.lshift ( low, 32 ) + high
    return num, rest
end

-- read 6 bytes from head of 'bytes' and truncate from
PCAP.read_mac = function ( bytes )
    local ret = {}
    for i = 1, 6 do
        ret [ #ret + 1] = string.byte ( bytes, i )
    end
    local rest = string.sub ( bytes, 6 + 1 )
    return ret, rest
end

-- convert 6 bytes array 'mac' into mac address string
-- fixme: duplicate
PCAP.mac_tostring = function ( mac )
    if ( #mac ~= 6 ) then return "not a mac addr" end
    local ret = ""
    for i = 1, 6 do
        if ( i ~= 1 ) then ret = ret .. ":" end
        ret = ret .. string.format("%x", mac [i])
    end
    return ret
end

-- read 'len' bytes from head of 'bytes' and truncate from
-- return red bytes as string
PCAP.read_str = function ( bytes, len )
    local str = ""
    local rest = bytes
    for i = 1, len do
        c, rest = PCAP.read_int8 ( rest )
        str = str .. string.char ( c )
    end
    return str, rest
end

-- parse the radiotap data block
-- (bssid, ssid only)
-- block may be truncated by tcpdump
PCAP.parse_radiotap_data = function ( capdata )

    local ret = {}
    local rest = capdata

    --local frame_control_field, rest = PCAP.read_int16 ( rest )

    local mask, rest = PCAP.read_int8 ( rest )
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

    -- 8 bit flags
    local flags, rest = PCAP.read_int8 ( rest )

    local duration, rest = PCAP.read_int16 ( rest )

    -- skip first 10 bytes
    --for i = 1, 6 do
    --    _, rest = PCAP.read_int8 ( rest )
    --end

    -- receiver / destination address
    local da, rest = PCAP.read_mac ( rest )
    --print ( PCAP.mac_tostring ( da ) )
    ret [ 'da' ] = da

    -- transmitter / source address
    local sa, rest = PCAP.read_mac ( rest )
    --print ( PCAP.mac_tostring ( sa ) )
    ret [ 'sa' ] = sa

    local bssid, rest = PCAP.read_mac ( rest )
    --print ( PCAP.mac_tostring ( bssid ) )
    ret [ 'bssid' ] = bssid

    --print ( PCAP.to_bytes_hex ( rest ) )

    if ( frame_type == 0 and frame_subtype == 8 ) then

        -- skip next 15 bytes
        for i = 1, 15 do
            _, rest = PCAP.read_int8 ( rest )
        end

        -- ssid (not \0 terminated )
        local ssid_len
        ssid_len, rest = PCAP.read_int8 ( rest )
        ssid_len = tonumber ( ssid_len )

        local ssid
        ssid, rest = PCAP.read_str ( rest, ssid_len )
        ret [ 'ssid' ] = ssid
    end
    -- ...

    -- FCS
    return ret, rest
end

-- parse radiotap header from head of 'capdata' and truncate the whole
-- header block from 'capdata'
-- (currently the first 16 sub blocks are parsed only)
-- alignment in sub blocks doesn't matter because of the absence of memory mapping
PCAP.parse_radiotap_header = function ( capdata )

    -- https://www.kernel.org/doc/Documentation/networking/radiotap-headers.txt
    -- 1 byte it_version header version (always 0)
    -- 1 byte .          padding ( to fit alignment )
    -- 2 bytes it_len    total header and sub block length
    -- 4 byte it_present bitmask ( bit 31 is set when theres a 64bit bitmask instead of a 32bit bitmask

    local ret = {}
    local rest = capdata

    --print ( PCAP.to_bytes_hex ( rest ) )
    --print ()

    ret ['it_ver'], rest = PCAP.read_int8 ( rest )
    _, rest = PCAP.read_int8 ( rest ) -- 1 byte padding
    ret ['it_len'], rest = PCAP.read_int16 ( rest )
    ret ['it_present'], rest = PCAP.read_int32 ( rest )
    
    local has_ext = PCAP.hasbit( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ "IEEE80211_RADIOTAP_EXT" ] ) )
    --print ( PCAP.to_bytes ( rest ) )
    --print ( )
    if ( has_ext ) then
        ret ['it_present_ex'], rest = PCAP.read_int32 ( rest )
        -- #antennas
        local bitmask = ret ['it_present_ex']
        repeat
            --print ( "read mask" )
            bitmask, rest = PCAP.read_int32 ( rest )
            local cont = PCAP.hasbit ( bitmask, PCAP.bit ( PCAP.radiotap_type [ "IEEE80211_RADIOTAP_NS_NEXT" ] ) )
            --print ( "next: " .. tostring ( cont ) )
        until ( cont == false )
    end

    --print ( PCAP.to_bytes_hex ( rest ) )
    --print ( )
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_TSFT' ] )  ) ) then
        --align 8
        ret['tsft'], rest = PCAP.read_int64 ( rest )
        -- print ( ret['tsft'] )
    end
    --tests/test.pcap
    _, rest = PCAP.read_int32 ( rest )
    --print ( PCAP.to_bytes_hex ( rest ) )
    --print ( )
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_FLAGS' ] )  ) ) then
        ret['flags'], rest = PCAP.read_int8 ( rest )
        -- fixme: one byte extra ( maybe padding )
        --_, rest = PCAP.read_int8 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_RATE' ] )  ) ) then
        ret['rate'], rest = PCAP.read_int8 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_CHANNEL' ] )  ) ) then
        --align 2
        ret['channel'], rest = PCAP.read_int16 ( rest )
        ret['channel_flags'], rest = PCAP.read_int16 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_FHSS' ] )  ) ) then
        ret['fhss_hop_set'], rest = PCAP.read_int8 ( rest )
        ret['fhss_hop_pattern'], rest = PCAP.read_int8 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DBM_ANTSIGNAL' ] )  ) ) then
        --print ( PCAP.to_bytes_hex ( rest ) )
        --print ()
        ret['antenna_signal'], rest = PCAP.read_int8_signed ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DBM_ANTNOISE' ] )  ) ) then
        ret['antenna_noise'], rest = PCAP.read_int8_signed ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_LOCK_QUALITY' ] )  ) ) then
        --align 2
        ret['lock_quality'], rest = PCAP.read_int16 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_TX_ATTENUATION' ] )  ) ) then
        --align 2
        ret['antenna_noise'], rest = PCAP.read_int16 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DBM_TX_POWER' ] )  ) ) then
        -- align 1
        ret['tx_power'], rest = PCAP.read_int8_signed ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_ANTENNA' ] )  ) ) then
        ret['db_antenna_signal'], rest = PCAP.read_int8 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DB_ANTSIGNAL' ] )  ) ) then
        ret['db_antenna_signal'], rest = PCAP.read_int8 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_DB_ANTNOISE' ] )  ) ) then
        ret['db_antenna_noise'], rest = PCAP.read_int8 ( rest )
    end
    if ( PCAP.hasbit ( ret['it_present'], PCAP.bit ( PCAP.radiotap_type [ 'IEEE80211_RADIOTAP_RX_FLAGS' ] )  ) ) then
        --align 2
        ret['db_antenna_noise'], rest = PCAP.read_int16 ( rest )
    end

    return ret, string.sub ( capdata, ret['it_len'] + 1 )
end
