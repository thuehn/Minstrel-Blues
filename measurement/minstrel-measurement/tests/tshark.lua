require ('misc')

local tshark_bin = "/usr/bin/tshark"
local fname = "/home/denis/data-udp-07.04.2017-HT40-40-far-all.bak/tp4300/tp4300-14-4-10-10M-1.pcap"
local mac = "64:70:02:aa:b8:e0"
local macs = {}
macs [1] = "a0:f3:c1:64:81:7c"

local filter = ""--"\""
filter = filter .. "wlan.fc.type==2"
if ( macs ~= nil and macs ~= {} ) then
    filter = filter .. " and ( ( ( "
end
for i, mac in ipairs ( macs ) do
    if ( i ~= 1 ) then filter = filter .. " or " end
    filter = filter .. "wlan.ra==" .. mac
end
if ( macs ~= nil and macs ~= {} ) then
    filter = filter .. " ) "
end
filter = filter .. "and wlan.ta==" .. mac
filter = filter .. " ) or ( "
filter = filter .. "wlan.ra==" .. mac
if ( macs ~= nil and macs ~= {} ) then
    filter = filter .. " and ( "
end
for i, mac in ipairs ( macs ) do
    if ( i ~= 1 ) then filter = filter .. " or " end
    filter = filter .. "wlan.ta==" .. mac
end
if ( macs ~= nil and macs ~= {} ) then
    filter = filter .. " ) ) )"
end
--filter = filter .. "and radiotap.length==62"
filter = filter .. ""--"\""

print ( tshark_bin .. " -r " .. fname .. " -Y " .. filter .. " -T " .. "fields"
        .. " -e " .. "radiotap.dbm_antsignal" )
print ()

local content, exit_code = Misc.execute_nonblock ( nil, nil, tshark_bin, "-r", fname, "-Y", filter, "-T", "fields"
                                        , "-e", "radiotap.dbm_antsignal" )
print ( exit_code )
print ( "content: " .. ( content or "none" ) )
