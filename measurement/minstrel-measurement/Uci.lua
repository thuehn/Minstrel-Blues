require ('spawn_pipe')

-- dig cannot handle resolv.conf files other than /etc/resolv.conf
--
-- fixme: /tmp/resolv.conf contains 127.0.0.1 and no other
--        nameserver ( i.e. from dhcp lease)
--
-- add static nameserver from config file if any
--
-- uci set dhcp.@dnsmasq[0].resolvfile
-- uci set dhcp.@dnsmasq[0].resolvfile=/etc/resolv.conf
function set_resolvconf ( nameserver )
    local uci_bin = "/sbin/uci" 
    if ( isFile ( uci_bin ) ) then
        local var = "dhcp.@dnsmasq[0].resolvfile"
        local fname = "/etc/resolv.conf"
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
    -- fixme: use dns forwarding
    if ( nameserver ~= nil ) then
        local file = io.open ( fname, "w" )
        file:write ( "nameserver " .. nameserver )
    end
end
