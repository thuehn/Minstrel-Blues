-- untested / unused

PCAP = {}

PCAP.read_mac = function ( bytes )
    local ret = {}
    for i = 1, 6 do
        ret [ #ret + 1] = string.byte ( bytes, i )
    end
    local rest = string.sub ( bytes, 6 + 1 )
    return ret, rest
end

-- ethernet headers are always exactly 14 bytes
PCAP.parse_ethernet_header = function ( capdata )
    local ret = {}
    local rest = capdata
    -- read 6 bytes destination host ethernet addr (mac)
    ret ['eth_dest'], rest = PCAP.read_mac ( rest )
    -- read 6 bytes source host ethernet addr (mac)
    ret ['eth_src'], rest = PCAP.read_mac ( rest )
    -- read 2 bytes (short) ether type (IP, ARP, RARP, ... )
    ret ['eth_type'], rest = PCAP.read_int16 ( rest )
    return ret, string.sub ( capdata, 14 + 1 )
end

-- ip header size = ip_header_len * 4
PCAP.ip_header_len = function ( byte )
    return bit.band ( byte, 0x0f )
end

PCAP.ip_header_ver = function ( byte )
    return bit.rshift ( byte, 4 )
end

PCAP.ip_tostring = function ( ip )
    -- fixme: maybe other way around
    return ( bit.band ( ip, 0xff ) .. "."
            .. bit.band ( bit.rshift ( ip, 8 ), 0xff ) .. "." 
            .. bit.band ( bit.rshift ( ip, 16 ), 0xff ) .. "." 
            .. bit.band ( bit.rshift ( ip, 24 ), 0xff ) .. "." 
           )
end

PCAP.parse_ip_header = function ( capdata )
    local ret = {}
    local rest = capdata
	-- read 1 byte ip_vhl version << 4 | header length >> 2
    ret ['ip_vhl'], rest = PCAP.read_int8 ( rest )
	-- read 1 byte ip_tos type of service
    ret ['ip_tos'], rest = PCAP.read_int8 ( rest )
    -- raed 1 byte ip_len total length
    ret ['ip_tos'], rest = PCAP.read_int8 ( rest )
	-- read 2 bytes ip_id identification
    ret ['it_id'], rest = PCAP.read_int16 ( rest )
	-- read 2 bytes ip_off fragment offset field
    ret ['it_off'], rest = PCAP.read_int16 ( rest )
	-- read 1 byte ip_ttl time to live
    ret ['ip_ttl'], rest = PCAP.read_int8 ( rest )
	-- read 1 byte ip_p protocol
    ret ['ip_p'], rest = PCAP.read_int8 ( rest )
	-- read 2 bytes ip_sum checksum
    ret ['it_sum'], rest = PCAP.read_int16 ( rest )
	-- read 4 bytes ip_src source addr
    ret ['ip_src'], rest = PCAP.read_int32 ( rest )
    -- read 4 bytes ip_dst dest address
    ret ['ip_dest'], rest = PCAP.read_int32 ( rest )
    return ret, string.sub ( capdata, 19 + 1 )
    -- return ret, string.sub ( capdata, ip_header_len ( ret['ip_vhl'] ) + 1 )
end

PCAP.tcp_offset = function ( th )
    return bit.rshift ( bit.band ( th['th_offx2'], 0xf0), 4)
end

PCAP.parse_tcp_header = function ( capdata )
    local ret = {}
    local rest = capdata
    -- 2 bytes th_sport source port
    ret ['th_sport'], rest = PCAP.read_int16 ( rest )
	-- 2 bytes th_dport destination port
    ret ['th_dport'], rest = PCAP.read_int16 ( rest )
	-- 4 byte th_seq sequence number
    ret ['th_seq'], rest = PCAP.read_int32 ( rest )
	-- 4 byte th_ack acknowledgement number
    ret ['th_ack'], rest = PCAP.read_int32 ( rest )
	-- 1 byte th_offx2 data offset, rsvd
    ret ['th_offx2'], rest = PCAP.read_int8 ( rest )
    -- 1 byte th_flags
    ret ['th_flags'], rest = PCAP.read_int8 ( rest )
    -- 2 bytes th_win window
    ret ['th_win'], rest = PCAP.read_int16 ( rest )
	-- 2 bytes th_sum checksum
    ret ['th_sum'], rest = PCAP.read_int16 ( rest )
	-- 2 bytes th_urp urgent pointer
    ret ['th_urp'], rest = PCAP.read_int16 ( rest )
    return ret, string.sub ( capdata, PCAP.tcp_offset ( ret ) )
end

