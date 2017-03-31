
require ('parsers/brctl')

local brctl_out = "bridge name	bridge id		STP enabled	interfaces\nbr-lan		7fff.647002aab8de	no		eth0.1\n							wlan1\n							wlan0"

local brctl = parse_brctl ( brctl_out )
print ( brctl:__tostring() )
