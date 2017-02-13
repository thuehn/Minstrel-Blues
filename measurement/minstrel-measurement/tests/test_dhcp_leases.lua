require ('parsers/dhcp_lease')

local line1 = "1486165501 a0:f3:c1:64:81:7b 192.168.1.240 * *"
local line2 = "1486168597 6c:62:6d:17:5b:a4 192.168.2.37 apfel ff:6d:17:5b:a4:00:01:00:01:1e:08:51:12:6c:62:6d:17:5b:a4"
local line3 = "1486177259 02:cf:03:82:be:37 192.168.2.11 birne 01:02:cf:03:82:be:37"

local lease

lease = parse_dhcp_lease ( line1 )
-- print ( lease )
print ( assert ( lease.timestamp == 1486165501 ) )
print ( assert ( lease.mac == "a0:f3:c1:64:81:7b" ) )
print ( assert ( lease.addr == "192.168.1.240" ) )
print ( assert ( lease.hostname == "*" ) )

lease = parse_dhcp_lease ( line2 )
-- print ( lease )
print ( assert ( lease.timestamp == 1486168597 ) )
print ( assert ( lease.mac == "6c:62:6d:17:5b:a4" ) )
print ( assert ( lease.addr == "192.168.2.37" ) )
print ( assert ( lease.hostname == "apfel" ) )

lease = parse_dhcp_lease ( line3 )
-- print ( lease )
print ( assert ( lease.timestamp == 1486177259 ) )
print ( assert ( lease.mac == "02:cf:03:82:be:37" ) )
print ( assert ( lease.addr == "192.168.2.11" ) )
print ( assert ( lease.hostname == "birne" ) )
