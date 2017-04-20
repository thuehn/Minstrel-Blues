require ('misc')
require ('parsers/iperf')

local line = "[  3]  0.0-10.1 sec  9.13 MBytes  7.60 Mbits/sec   3.869 ms 1913/ 8423 (23%)"
local iperf = parse_iperf_client ( line )
assert ( iperf.id == 3 )
assert ( iperf.interval_start == 0 )
assert ( iperf.interval_end == 10.1 )
assert ( iperf.transfer == 9.13 )
assert ( iperf.bandwidth == 7.6 )
assert ( iperf.jitter == 3.869 )
assert ( iperf.lost_datagrams == 1913 )
assert ( iperf.total_datagrams == 8423 )
assert ( iperf.percent == 23 )

local out = "[  3] local 192.168.1.240 port 12000 connected with 192.168.1.10 port 45407\n[ ID] Interval       Transfer     Bandwidth        Jitter   Lost/Total Datagrams\n[  3]  0.0-10.1 sec  9.13 MBytes  7.60 Mbits/sec   3.869 ms 1913/ 8423 (23%)"
for i, line in ipairs ( split ( out, "\n" ) ) do
    local iperf = parse_iperf_client ( line )
    if ( i == 1 ) then assert ( iperf.id == nil )
    elseif ( i == 2 ) then assert ( iperf.id == nil )
    else
        assert ( iperf.id == 3 )
        assert ( iperf.interval_start == 0 )
        assert ( iperf.interval_end == 10.1 )
        assert ( iperf.transfer == 9.13 )
        assert ( iperf.bandwidth == 7.6 )
        assert ( iperf.jitter == 3.869 )
        assert ( iperf.lost_datagrams == 1913 )
        assert ( iperf.total_datagrams == 8423 )
        assert ( iperf.percent == 23 )
    end
end
