
require ("spawn_pipe")

require ('parsers/ifconfig')
require ('parsers/dig')

Net = {}

Net.get_addr = function ( iface )
    local ifconfig_proc = spawn_pipe( "ifconfig", iface )
    ifconfig_proc['proc']:wait()
    local lines = ifconfig_proc['out']:read("*a")
    local ifconfig = parse_ifconfig ( lines )
    close_proc_pipes ( ifconfig_proc )
    return ifconfig.addr
end

-- TODO: +search has full qualified hostname output
-- lede-ap answer is lede-ap.lan. instead of lede-ap.
-- should be ok but untested
Net.lookup = function ( name ) 
    local dig = spawn_pipe ( "dig", name, "+search" ) -- '+search' for local hostnames ( without domain )
    if ( dig['err_msg'] ~= nil ) then 
        self:send_error ( "dig: " .. dig['err_msg'] )
        return nil
    end
    local exitcode = dig['proc']:wait()
    local content = dig['out']:read("*a")
    local answer = parse_dig ( content )
    close_proc_pipes ( dig )
    return answer.addr
end

-- tests only
-- net-tools-hostname needs netinet6/ipv6_route.h to compile
-- opkg install kmod-ipv6 radvd ip kmod-ip6tables ip6tables
Net.get_hostname = function ()
    local hostname_proc = spawn_pipe( "hostname", "-s" )
    hostname_proc['proc']:wait()
    local line = hostname_proc['out']:read("*l")
    close_proc_pipes ( hostname_proc )
    return line
end
