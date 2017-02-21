require ('spawn_pipe')

-- dig cannot handle resolv.conf files other than /etc/resolv.conf
--
-- fixme: /tmp/resolv.conf contains 127.0.0.1 and no other
--        nameserver ( i.e. from dhcp lease)
--
-- add static nameserver from config file if any
--
-- uci get dhcp.@dnsmasq[0].resolvfile
-- uci set dhcp.@dnsmasq[0].resolvfile=/etc/resolv.conf
-- fixme: allow name without domain (+search)
-- dhcp.@dnsmasq[0].domainneeded='1'
-- fixme: use dns forwarding from uci
--    dhcp.@dnsmasq[0].server='192.168.1.1'
function set_resolvconf ( nameserver )
    local uci_bin = "/sbin/uci" 
    local fname = "/etc/resolv.conf"
    if ( isFile ( uci_bin ) ) then
        local var = "dhcp.@dnsmasq[0].resolvfile"
        local proc = spawn_pipe( uci_bin, "get", var )
        proc['proc']:wait()
        local line = proc['out']:read("*l")
        close_proc_pipes ( proc )
        if ( line ~= fname ) then
            local proc = spawn_pipe( "uci", "set", var .. "=" .. fname )
            proc['proc']:wait()
            close_proc_pipes ( proc )
        end
    end
    -- overwrite resolv.conf
    if ( nameserver ~= nil ) then
        local file = io.open ( fname, "w" )
        file:write ( "nameserver " .. nameserver )
        file:flush()
        file:close()
    end
end
