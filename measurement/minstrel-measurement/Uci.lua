require ('spawn_pipe')
require ('misc')

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

-- network.lan.type='bridge'
-- vs.
-- network.wwan._orig_bridge='false'
-- network.lan._orig_bridge='false'
-- wireless.default_radio0.network='lan'
function uci_check_bridge ( phy )
    local uci_bin = "/sbin/uci" 
    if ( isFile ( uci_bin ) ) then
--        local phy_idx = tonumber ( string.sub ( phy, 4, 5 ) ) + 1
--        local var = "wireless.default_radio" .. phy_idx .. ".network"
--        local proc = spawn_pipe( uci_bin, "get", var )
--        local exit_code = proc['proc']:wait()
--        if ( exit_code == 0 ) then
--            local network = proc['out']:read("*l")
--            close_proc_pipes ( proc )
--            var = "network." .. network .. "._orig_bridge"
--            local proc = spawn_pipe( uci_bin, "get", var )
--            local exit_code = proc['proc']:wait()
--            if ( exit_code > 0 ) then
--                local bridge = proc['out']:read("*l")
--                close_proc_pipes ( proc )
--                return bridge ~= "false"
--            else
--                close_proc_pipes ( proc )
--            end
--        else
--            close_proc_pipes ( proc )
--        end
        local var = "network.lan.type"
        local proc = spawn_pipe( uci_bin, "get", var )
        local exit_code = proc['proc']:wait()
        if ( exit_code > 0 ) then
            -- uci has no such entry ( no bridge )
            close_proc_pipes ( proc )
            return false
        else
            local lan_type = proc['out']:read("*l")
            close_proc_pipes ( proc )
            return lan_bridge ~= "bridge"
        end
    end
    return nil
end

--  uci set wireless.@wifi-iface[1].ssid='LEDE'
function uci_link_to_ssid ( ssid, phy )
    local uci_bin = "/sbin/uci" 
    if ( isFile ( uci_bin ) ) then
        local phy_idx = tonumber ( string.sub ( phy, 4, 5 ) ) + 1
        local var = "wireless.@wifi-iface[" .. phy_idx .. "].ssid"
        local proc = spawn_pipe( uci_bin, "set", var .. "=" .. ssid )
        local exit_code = proc['proc']:wait()
        close_proc_pipes ( proc )
        if ( exit_code > 0 ) then
            -- device id does not exists
            return false
        end
        return true
    end
end

-- uci set wireless.@wifi-iface[1].mode='sta'
-- mode: 'sta', 'ap'
function uci_set_wifi_mode ( mode, phy )
    local uci_bin = "/sbin/uci" 
    if ( isFile ( uci_bin ) ) then
        local phy_idx = tonumber ( string.sub ( phy, 4, 5 ) ) + 1
        local var = "wireless.@wifi-iface[" .. phy_idx .. "].mode"
        local proc = spawn_pipe( uci_bin, "set", var .. "=" .. mode )
        local exit_code = proc['proc']:wait()
        close_proc_pipes ( proc )
        if ( exit_code > 0 ) then
            -- device id does not exists
            return false
        end
        return true
    end
end
