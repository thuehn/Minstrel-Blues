require ('misc')

local tshark_bin = "/usr/bin/tshark"
--local fname = "/home/denis/data-udp-07.04.2017-HT40-40-far-all.bak/tp4300/tp4300-14-4-10-10M-1.pcap"
--local fname = "/home/denis/data-udp-27.04.2017-C13-HT20-noani-ldpc/tp3600/tp3600-7-10-d10-10M-1.pcap"
local fname = "/home/denis/data-udp-27.04.2017-C13-HT20-ani-noldpc/tp3600/tp3600-7-10-d10-10M-1.pcap"
local mac = "64:70:02:aa:b8:df"
local macs = {}
macs [1] = "f4:f2:6d:22:7c:f0"

local filter = ""
--filter = filter .. "wlan.fc.type==2"
if ( macs ~= nil and macs ~= {} ) then
--    filter = filter .. " and ( ( ( "
    filter = filter .. " ( ( ( "
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
filter = filter .. ""

print ( tshark_bin .. " -r " .. fname .. " -Y " .. filter .. " -T " .. "fields"
        .. " -e " .. "radiotap.dbm_antsignal" )
print ()

local content, exit_code = Misc.execute_nonblock ( nil, nil, tshark_bin, "-r", fname, "-Y", filter, "-T", "fields"
                                        , "-e", "radiotap.dbm_antsignal", "-e", "wlan.fc.type", "-e", "wlan.fc.type_subtype" )
print ( exit_code )
print ( "content: " .. ( content or "none" ) )
