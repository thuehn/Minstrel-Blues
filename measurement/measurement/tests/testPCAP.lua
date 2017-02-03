require ('pcap')

print (pcap._LIB_VERSION)
local fname = "/tmp/node.pcap"
local cap = pcap.open_offline( fname )
if (cap ~= nil) then
    -- cap:set_filter(filter, nooptimize)

    for capdata, timestamp, wirelen in cap.next, cap do
      print(timestamp, wirelen, #capdata)
    end

    cap:close()
else
    print ("pcap open failed: " .. fname)
end
