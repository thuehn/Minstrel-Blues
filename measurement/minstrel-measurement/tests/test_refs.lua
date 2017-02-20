require ('StationRef')
require ('AccessPointRef')

-- see tests/NodeRef.lua
local nRef = AccessPointRef:create("AP", nil)
nRef:set_wifi ( "phy0" )
nRef:add_station ( "00:00:00:11:11:11", nil )
print ( nRef:__tostring() )

local s1 = StationRef:create("STA1", nil)
assert ( s1.name == "STA1" )

local s2 = StationRef:create("STA2", nil)
assert ( s2.name == "STA2" )

local a1 = AccessPointRef:create("AP1", nil)
assert ( a1.name == "AP1" )

local a2 = AccessPointRef:create("AP2", nil)
assert ( a2.name == "AP2" )
a2:add_station ( "00:11:22:33:44:55", s1 )
a2:add_station ( "00:11:22:33:44:66", s2 )


print (s1:__tostring())
print (s2:__tostring())
print (a1:__tostring())
print (a2:__tostring())
