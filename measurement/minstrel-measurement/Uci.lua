local misc = require ('misc')

local Uci = {}
Uci.uci_bin = "/sbin/uci" 

Uci.set_var = function ( var, value )
    if ( isFile ( Uci.uci_bin ) and var ~= nil and value ~= nil ) then
        if ( type ( value ) == "string" ) then
            value = "'" .. value .. "'"
        else
            value = tostring ( value )
        end
        local _, exit_code = misc.execute ( Uci.uci_bin, "set", var .. "=" .. value )
        if ( exit_code == 0 ) then
            return true
        end
    end
    return false
end

Uci.get_var = function ( var )
    if ( isFile ( Uci.uci_bin ) and var ~= nil ) then
        local line, exit_code = misc.execute ( Uci.uci_bin, "get", var )
        if ( exit_code == 0 ) then
            if ( string.sub ( line, 1, 1 ) == "'" ) then
                local value = string.sub ( line, 2, string.len ( line ) - 1 )
            else
                return line
            end
        end
    end
    return nil
end


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
-- /tmp/resolv.conf.auto
function set_resolvconf ( nameserver )
    local uci_bin = "/sbin/uci" 
    local fname = "/etc/resolv.conf"
    if ( isFile ( uci_bin ) and nameserver ~= nil ) then
        local var = "dhcp.@dnsmasq[0].resolvfile"
        local line, exit_code = misc.execute ( uci_bin, "get", var )
        if ( line ~= fname ) then
            local line, exit_code = misc.execute ( uci_bin, "set", var .. "=" .. fname )
        end
    end
    -- overwrite resolv.conf
    if ( nameserver ~= nil ) then
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            file:write ( "nameserver " .. nameserver )
            file:flush()
            file:close()
        end
    end
end

--  uci set wireless.@wifi-iface[1].ssid='LEDE'
function uci_link_to_ssid ( ssid, phy )
    local uci_bin = "/sbin/uci" 
    if ( isFile ( uci_bin ) and ssid ~= nil and phy ~= nil ) then
        local phy_idx = tonumber ( string.sub ( phy, 4, 5 ) ) + 1
        local var = "wireless.@wifi-iface[" .. phy_idx .. "].ssid"
        local line, exit_code = misc.execute ( uci_bin, "set", var .. "=" .. ssid )
        if ( exit_code > 0 ) then
            -- device id does not exists
            return false
        end
        return true
    end
    return false
end

-- uci set wireless.@wifi-iface[1].mode='sta'
-- mode: 'sta', 'ap'
-- TODO: start/stop dhcp-server
-- TODO: set static address/dhcp
function uci_set_wifi_mode ( mode, phy )
    local uci_bin = "/sbin/uci" 
    if ( isFile ( uci_bin ) and mode ~= nil and phy ~= nil) then
        local phy_idx = tonumber ( string.sub ( phy, 4, 5 ) ) + 1
        local var = "wireless.@wifi-iface[" .. phy_idx .. "].mode"
        local line, exit_code = misc.execute ( uci_bin, "set", var .. "=" .. mode )
        if ( exit_code > 0 ) then
            -- device id does not exists
            return false
        end
        return true
    end
    return false
end

return Uci
