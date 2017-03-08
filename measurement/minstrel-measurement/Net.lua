
require ('parsers/ifconfig')
require ('parsers/dig')

Net = {}

Net.get_addr = function ( iface )
    local lines, exit_code = os.execute ( "ifconfig " .. iface )
    print ( lines )
    print ( exit_code )
    if ( exit_code == 0 ) then
        local ifconfig = parse_ifconfig ( lines )
        return ifconfig.addr, nil
    else
        return nil, lines
    end
end

Net.lookup = function ( name ) 
    local content, exit_code = os.execute ( "dig " .. name .. " +search" ) -- '+search' for local hostnames ( without domain )
    if ( exit_code == 0 ) then
        local answer = parse_dig ( content )
        if ( answer ~= nil ) then
            return answer.addr, nil
        else
            -- never happens
            return nil, "Net.lookup: parse error: unknown"
        end
    else
        return nil, content
    end
end

-- tests only
-- net-tools-hostname needs netinet6/ipv6_route.h to compile
-- opkg install kmod-ipv6 radvd ip kmod-ip6tables ip6tables
Net.get_hostname = function ()
    local line, exit_code = os.execute ( "hostname -s" )
    if ( exit_code == 0 ) then
        return line, nil
    else
        return nil, line
    end
end

print ( Net.get_addr ( "eth0" ) )
print ( Net.get_addr ( "wlan0" ) )
