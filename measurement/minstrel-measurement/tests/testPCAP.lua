require ('pcap')
local pprint = require ('pprint')
require ('parsers/parsers')
require ('bit') -- lua5.3 supports operator &,|,<<,>> natively
require ('parsers/radiotap')

--fixme: transfer tcpdump as binary data

print (pcap._LIB_VERSION)

--pcap.DLT = { 'DLT_IEEE802_11_RADIO' }

local fname = "tests/test.pcap"
local cap = pcap.open_offline( fname )
if (cap ~= nil) then
	cap:set_filter ("type mgt subtype beacon", nooptimize)
    for capdata, timestamp, wirelen in cap.next, cap do
        -- print ( timestamp, wirelen, #capdata )
        -- pprint ( capdata )
        print ( PCAP.to_bytes_hex ( capdata ) )
        local rest = capdata
        local radiotap_header
        local radiotap_data
        local ethernet_header
        local ip_header
        local tcp_header
        radiotap_header, rest = PCAP.parse_radiotap_header ( rest )
        radiotap_data, rest = PCAP.parse_radiotap_data ( rest )
		local ssid = radiotap_data['ssid']
		print ( "ssid: '" .. ssid .. "'" )
		print ( ssid == "LEDE" )
		if ( true or ssid == "LEDE" ) then
			print ( "tsft: " .. ( radiotap_header ['tsft'] or "not present" ) )
			print ( "flags: " .. ( radiotap_header ['flags'] or "not present" ) )
			print ( "rate: " .. ( radiotap_header ['rate'] or "not present" ) )
			print ( "channel: " .. ( radiotap_header ['channel'] or "not present" ) )
			local channel_flags = "not present"
			if ( radiotap_header ['channel_flags'] ~= nil ) then
				channel_flags = PCAP.bitmask_tostring ( radiotap_header ['channel_flags'], 16)
						.. ", 0x" .. string.format ( "%x", radiotap_header ['channel_flags']) 
			end
			print ( "channel_flags: " .. ( channel_flags or "not present" ) )
			print ( "fhss_hop_set: " .. ( radiotap_header ['fhss_hop_set'] or "not present" ) )
			print ( "fhss_hop_pattern: " .. ( radiotap_header ['fhss_hop_pattern'] or "not present" ) )
			print ( "antenna_signal: " .. ( radiotap_header ['antenna_signal'] or "not present" ) )
			print ( "antenna_noise: " .. ( radiotap_header ['antenna_noise'] or "not present" ) )
			print ( "tx_power: " .. ( radiotap_header ['tx_power'] or "not present" ) )
			print ( "db_antenna_signal: " .. ( radiotap_header ['db_antenna_signal'] or "not present" ) )
			print ( "db_antenna_noise: " .. ( radiotap_header ['db_antenna_noise'] or "not present" ) )
		end
        --ethernet_header, rest = PCAP.parse_ethernet_header ( rest )
        --print ( PCAP.mac_tostring ( ethernet_header['eth_src'] ) )
        --print ( PCAP.mac_tostring ( ethernet_header['eth_dest'] ) )
        --ip_header, rest = PCAP.parse_ip_header ( rest )
        --tcp_header, rest = PCAP.parse_tcp_header ( rest )
        --payload
        --print ( PCAP.ip_tostring ( ip_header['ip_src'] ) )
        --print ( PCAP.ip_tostring ( ip_header['ip_dest'] ) )
        --print ( PCAP.to_bytes ( rest ) )
        --for i = 1, #capdata do
        --    --print ( to_bytes ( string.sub ( capdata, i ) ) )
        --    print ( i .. ": " .. PCAP.ip_tostring ( PCAP.read_int32 ( string.sub ( capdata, i ) ) ) )
        --    if ( i > #capdata - 4 ) then break end
        --end
    end

    cap:close()
else
    print ("pcap open failed: " .. fname)
end


--[[
* wireshark has lua support, but LEDE doesn't have any of these rawshark, dumpcap, TShark, or Wireshark.
    - https://wiki.wireshark.org/Lua
    - https://wiki.wireshark.org/Lua/Examples
* linux kernel doesn't export net/cfg80211.h and include/net/ieee80211_radiotap.h to linux-headers, just nl80211
  which doesn't contain radioheader structs and iterators. It doesn't make any difference using libpcap or pcap-lua,
  since the structs have to collected manually from elsewhere when using both libraries and an update of the measurement
  is needed when ever the headers are updated in the kernel.
* PACKAGE_cshark "Cloudshark capture tool" is available on LEDE
    - "Easily upload your wireshark captures to CloudShark"
* alternative packet filtering for lua https://github.com/Igalia/pflua
    - seems to focus on filtering instead of analyse headers
    - do they have radiotap header support? parsers and lexers attach ethernet headers with some wlan addresses and types
* nl80211 is supported by LEDE with libnl tiny https://wireless.wiki.kernel.org/en/developers/documentation/nl80211
------------------------------------------------------------------------
cat /tmp/node.pcap | rawshark -s -r - -d proto:radiotap

rawshark: The file "-" appears to be damaged or corrupt.
(Bad packet length: 2516582400
)
------------------------------------------------------------------------
tshark -nn -r /tmp/node.pcap -F pcap -T fields -e radiotap.dbm_antsignal
-82,-89,-83,-89
-82,-87,-90,-85
-47,-48,-57,-56
-79,-83,-85,-86
-88,-92,-94,-94
--]]
