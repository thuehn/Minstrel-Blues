
require ('parsers/iw_info')
require ('misc')

local iwinfo0 = parse_iwinfo ( "" )
assert ( iwinfo0.iface == nil )

local iwinfo1_str = "Interface wlan0\n	ifindex 9\n	wdev 0x2\n	addr f4:f2:6d:22:7c:f0\n	ssid LEDE-ctrl\n	type AP\n	wiphy 0\n	channel 11 (2462 MHz), width: 20 MHz, center1: 2462 MHz\n	txpower 25.00 dBm\n"
local iwinfo1 = parse_iwinfo ( iwinfo1_str )

assert ( iwinfo1.iface == "wlan0" )
assert ( iwinfo1.ifindex == 9 )
assert ( iwinfo1.wdev == "0x2" )
assert ( iwinfo1.mac == "f4:f2:6d:22:7c:f0" )
assert ( iwinfo1.ssid == "LEDE-ctrl" )
assert ( iwinfo1.mode == "AP" )
assert ( iwinfo1.phy == 0 )
assert ( iwinfo1.channel == 11 )
assert ( iwinfo1.freq == 2462 )
assert ( iwinfo1.width == 20 )
assert ( iwinfo1.center1 == 2462 )
assert ( iwinfo1.txpower == 25 )

local iwinfo2_str = "Interface wlan0\n	ifindex 2\n	wdev 0x1\n	addr 06:32:de:8e:5c:5f\n	type managed\n	wiphy 0\n"
local iwinfo2 = parse_iwinfo ( iwinfo2_str )

assert ( iwinfo2.iface == "wlan0" )
assert ( iwinfo2.ifindex == 2 )
assert ( iwinfo2.wdev == "0x1" )
assert ( iwinfo2.mac == "06:32:de:8e:5c:5f" )
assert ( iwinfo2.ssid == nil )
assert ( iwinfo2.mode == "managed" )
assert ( iwinfo2.phy == 0 )
assert ( iwinfo2.channel == nil )
assert ( iwinfo2.freq == nil )
assert ( iwinfo2.width == nil )
assert ( iwinfo2.center1 == nil )
assert ( iwinfo2.txpower == nil )

local iwinfo3_str = "Interface wlan1\n	ifindex 8\n	wdev 0x100000001\n	addr a0:f3:c1:64:81:7c\n	type managed\n	wiphy 1\n	txpower 20.00 dBm\n"
local iwinfo3 = parse_iwinfo ( iwinfo3_str )

assert ( iwinfo3.iface == "wlan1" )
assert ( iwinfo3.ifindex == 8 )
assert ( iwinfo3.wdev == "0x100000001" )
assert ( iwinfo3.mac == "a0:f3:c1:64:81:7c" )
assert ( iwinfo3.ssid == nil )
assert ( iwinfo3.mode == "managed" )
assert ( iwinfo3.phy == 1 )
assert ( iwinfo3.channel == nil )
assert ( iwinfo3.freq == nil )
assert ( iwinfo3.width == nil )
assert ( iwinfo3.center1 == nil )
assert ( iwinfo3.txpower == 20 )

local iwinfo4_str = "Interface wlan0\n	ifindex 373\n	wdev 0x16d\n	addr a0:f3:c1:64:81:7b\n	type managed\n	wiphy 0\n	channel 11 (2462 MHz), width: 20 MHz, center1: 2462 MHz\n	txpower 20.00 dBm\n"
local iwinfo4 = parse_iwinfo ( iwinfo4_str )

assert ( iwinfo4.iface == "wlan0" )
assert ( iwinfo4.ifindex == 373 )
assert ( iwinfo4.wdev == "0x16d" )
assert ( iwinfo4.mac == "a0:f3:c1:64:81:7b" )
assert ( iwinfo4.ssid == nil )
assert ( iwinfo4.mode == "managed" )
assert ( iwinfo4.phy == 0 )
assert ( iwinfo4.channel == 11 )
assert ( iwinfo4.freq == 2462 )
assert ( iwinfo4.width == 20 )
assert ( iwinfo4.center1 == 2462 )
assert ( iwinfo4.txpower == 20 )
