
require ('parsers/iwinfo')
require ('misc')

local iwinfo0 = parse_iw_info ( "" )
assert ( iwinfo0.iface == nil )

local iwinfo1_str = "wlan0     ESSID: \"LEDE\"\n          Access Point: C4:93:00:00:B2:49\n          Mode: Master  Channel: 11 (2.462 GHz)\n          Tx-Power: 21 dBm  Link Quality: 59/70\n          Signal: -51 dBm  Noise: -93 dBm\n          Bit Rate: 6.5 MBit/s\n          Encryption: WPA2 PSK (CCMP)\n          Type: nl80211  HW Mode(s): 802.11bgn\n          Hardware: unknown [Generic MAC80211]\n          TX power offset: unknown\n          Frequency offset: unknown\n          Supports VAPs: yes  PHY name: phy0\n"
local iwinfo1 = parse_iw_info ( iwinfo1_str )

assert ( iwinfo1.iface == "wlan0" )
assert ( iwinfo1.ssid == "LEDE" )
assert ( iwinfo1.mac == "c4:93:00:00:b2:49" )
assert ( iwinfo1.mode == "Master" )
assert ( iwinfo1.channel == 11 )
assert ( iwinfo1.freq == 2462 )
assert ( iwinfo1.txpower == 21 )
--assert ( iwinfo1.phy == 0 )

local iwinfo2_str = "wlan0     ESSID: \"LEDE\"\n          Access Point: C4:93:00:07:6F:09\n          Mode: Client  Channel: 11 (2.462 GHz)\n          Tx-Power: 23 dBm  Link Quality: 47/70\n          Signal: -63 dBm  Noise: -95 dBm\n          Bit Rate: 6.5 MBit/s\n          Encryption: WPA2 PSK (CCMP)\n          Type: nl80211  HW Mode(s): 802.11abgn\n          Hardware: unknown [Generic MAC80211]\n          TX power offset: unknown\n          Frequency offset: unknown\n          Supports VAPs: yes  PHY name: phy0\n"
