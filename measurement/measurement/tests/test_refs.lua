require ('StationRef')
require ('AccessPointRef')

local nRef = AccessPointRef:create("AP", nil)
nRef:add_wifi ( "phy0" )
nRef:add_station ( "00:00:00:11:11:11" )
print ( nRef:__tostring() )

local s1 = StationRef:create("STA1", nil)
assert ( s1.name == "STA1" )

local s2 = StationRef:create("STA2", nil)
assert ( s2.name == "STA2" )

local a1 = AccessPointRef:create("AP1", nil)
assert ( a1.name == "AP1" )

local a2 = AccessPointRef:create("AP2", nil)
assert ( a2.name == "AP2" )

print (s1:__tostring())
print (s2:__tostring())
print (a1:__tostring())
print (a2:__tostring())
