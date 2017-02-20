
require ('rpc')
require ('misc')

require ('NetIF')
require ('Node')

local wifi = NetIF.create("wlan0", "192.168.1.1", nil)
local ctrl = NetIF.create("eth0" , "192.168.2.218", nil)
local ap_node = Node:create('Node', wifi, ctrl )

print ( wifi )

if rpc.mode == "tcpip" then
    local ip_addr = "192.168.1.1"
    -- local ip_addr = "192.168.2.218"
    slave, err = rpc.connect ( ip_addr, 12346 );
--    if ( err ~= nil ) then
        print ( "STATIONS:")
        local nodes 
            = split ( slave.stations( wifi.iface ), ",")
        for i, node in ipairs ( nodes ) do
            print ( node )
        end
--    end
else
    print ( "Err: rpc mode tcp/ip is supported only" )
end

