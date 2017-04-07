local pprint = require ('pprint')
require ('parsers/parsers')
require ('bit') -- lua5.3 supports operator &,|,<<,>> natively
require ('parsers/radiotap')

--print (pcap._LIB_VERSION)

--pcap.DLT = { 'DLT_IEEE802_11_RADIO' }

local fname = "tests/test.pcap"
--local fname = "/home/denis/data-30.03.2017-5G-all/tp4300/tp4300-11-9-10-10M-1.pcap"
--local fname = "/home/denis/data-30.03.2017-5G-all/tp4300/tp4300-15-2-10-10M-1.pcap"

local rest
local pos
local file

file, rest, pos = PCAP.open ( fname )

if ( file ~= nil ) then

    while ( string.len ( rest ) > 0 ) do

        local radiotab
        local length
        radiotap, length, rest, pos = PCAP.get_packet ( rest, pos )

        -- fixme: returned pos doesn't match position of returned rest
        local radiotap_header
        local radiotap_data
        local pos2 = 0
        local rest2 = radiotap
        radiotap_header, rest2, pos2 = PCAP.parse_radiotap_header ( rest2, pos2 )
        radiotap_data, _, _ = PCAP.parse_radiotap_data ( rest2, length, radiotap_header [ 'it_len' ], pos2 )

		local ssid = radiotap_data [ 'ssid' ]
		local frame_type = radiotap_data [ 'type' ]
		local frame_subtype = radiotap_data [ 'subtype' ]
		--print ( "ssid: '" .. ssid .. "'" )
		--print ( ssid == "LEDE" )
        local sa = PCAP.mac_tostring ( radiotap_data [ 'sa' ] )
        local da = PCAP.mac_tostring ( radiotap_data [ 'da' ] )
--        if ( ( ( da == "ff::ff:ff:ff:ff:ff" and ( sa == "f4:f2:6d:22:7c:f0" ) )
--                or ( da == "ff:ff:ff:ff:ff:ff" and sa == "a0:f3:c1:64:81:7b" )
--                or ( da == "f4:f2:6d:22:7c:f0" and sa == "a0:f3:c1:64:81:7b" )
--                or ( da == "a0:f3:c1:64:81:7b" and sa == "f4:f2:6d:22:7c:f0" ) )
--            and frame_type + 1 == PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_DATA" ]
--            and ( frame_subtype + 1 == PCAP.radiotap_data_frametype [ "DATA" ]
--                 or  frame_subtype + 1 == PCAP.radiotap_data_frametype [ "QOS_DATA" ] ) ) then
        if ( true ) then
            --print ( "ssid: " .. ( ssid or "unset" ) )
            --print ( "sa: " .. sa )
            --print ( "da: " .. da )
            --print ( "type: " .. frame_type )
            --print ( "subtype: " .. frame_subtype )
            --print ( PCAP.to_bytes_hex ( capdata ) )
			print ( "tsft: " .. ( radiotap_header ['tsft'] or "not present" ) )
			print ( "flags: " .. ( radiotap_header ['flags'] or "not present" ) )
			--print ( "rate: " .. ( radiotap_header ['rate'] or "not present" ) )
			--print ( "channel: " .. ( radiotap_header ['channel'] or "not present" ) )
			--local channel_flags = "not present"
			--if ( radiotap_header ['channel_flags'] ~= nil ) then
			--	channel_flags = PCAP.bitmask_tostring ( radiotap_header ['channel_flags'], 16)
			--			.. ", 0x" .. string.format ( "%x", radiotap_header ['channel_flags']) 
			--end
			--print ( "channel_flags: " .. ( channel_flags or "not present" ) )
			--print ( "fhss_hop_set: " .. ( radiotap_header ['fhss_hop_set'] or "not present" ) )
			--print ( "fhss_hop_pattern: " .. ( radiotap_header ['fhss_hop_pattern'] or "not present" ) )
            if ( radiotap_header ['antenna_signal'] ~= nil ) then
			    print ( "antenna_signal: " .. radiotap_header ['antenna_signal'] )
            end
            for i=0,3 do
            if ( radiotap_header ['antenna_signal' .. tostring (i) ] ~= nil ) then
			    print ( "antenna_signal" ..tostring (i) .. ": " .. radiotap_header ['antenna_signal' .. tostring (i) ] )
            end

            end
			--print ( "antenna_noise: " .. ( radiotap_header ['antenna_noise'] or "not present" ) )
			--print ( "tx_power: " .. ( radiotap_header ['tx_power'] or "not present" ) )
			--print ( "db_antenna_signal: " .. ( radiotap_header ['db_antenna_signal'] or "not present" ) )
			--print ( "db_antenna_noise: " .. ( radiotap_header ['db_antenna_noise'] or "not present" ) )
		end
    end

    file:close ()
else
    print ("pcap open failed: " .. fname)
end

--[[
lede-sta-0-11-1.pcap
 tshark -nn -r lede-sta-0-11-1.pcap -F pcap -T fields -e radiotap.dbm_antsignal -e wlan.bssid
-32,-32,-44
-27,-28,-33
-6,-31,-6
-5,-29,-5
-26,-29,-30
-25,-25,-34
-5,-30,-5
-5,-30,-5
-71,-94,-71
-5,-31,-5
-5,-31,-5
-4,-28,-4
-4,-29,-4
-4,-29,-4
-5,-31,-5
-5,-26,-5
-5,-30,-5
-4,-30,-4
--]]

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
