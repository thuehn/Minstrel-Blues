
require ('parsers/wpa_supplicant')
local pprint = require ('pprint')
local misc = require ('misc')

local conf1 = "#\n###### Global Configuration ######\n\nnetwork={\nssid=\"test\"\nmode=0\n}\n\n"
--print ( "len: " .. string.len ( conf1 ) )
local wpa1 = parse_wpa_supplicant_conf ( conf1 )
print ( table_tostring ( wpa1 ) )

local conf2 = "# EAP-PSK\nnetwork={\n	ssid=\"eap-psk-test\"\n	key_mgmt=WPA-EAP\n	eap=PSK\n	anonymous_identity=\"eap_psk_user\"\n	password=06b4be19da289f475aa46a33cb793029\n	identity=\"eap_psk_user@example.com\"\n}\n\n"
--print ( "len: " .. string.len ( conf2 ) )
local wpa2 = parse_wpa_supplicant_conf ( conf2 )
print ( table_tostring ( wpa2 ) )

local conf3 = "network={\nssid=\"test\"\nmode=0\n}\n"
--print ( "len: " .. string.len ( conf3 ) )
local wpa3 = parse_wpa_supplicant_conf ( conf3 )
print ( table_tostring ( wpa3 ) )
