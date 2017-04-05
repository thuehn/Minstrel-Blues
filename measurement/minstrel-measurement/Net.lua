
local posix = require ('posix') -- sleep
require ('parsers/ifconfig')
require ('parsers/dig')
require ('parsers/brctl')
require ('lfs')
local misc = require ('misc')

Net = {}

Net.debugfs = "/sys/kernel/debug/ieee80211"

Net.get_addr = function ( iface )
    if ( iface == nil ) then
        return nil, "iface is unset"
    end
    local content = misc.execute ( "brctl", "show" )

    if ( content ~= nil ) then
        local brctl = parse_brctl ( content )
        for _, interface in ipairs ( brctl.interfaces ) do
            if ( iface == interface ) then
                iface = brctl.name
                break
            end
        end
    end
    local content = misc.execute ( "ifconfig", iface )
    if ( content ~= nil ) then
        local ifconfig = parse_ifconfig ( content )
        return ifconfig.addr, nil
    else
        return nil, nil
    end
end

Net.lookup = function ( name ) 
    --local content = misc.execute ( "dig", name, "+search" ) -- '+search' for local hostnames ( without domain )
    local content = misc.execute ( "dig", name )
    if ( content ~= nil ) then
        local answer = parse_dig ( content )
        if ( answer ~= nil ) then
            return answer, nil
        end
    else
        return nil, nil
    end
end

-- tests only
-- net-tools-hostname needs netinet6/ipv6_route.h to compile
-- opkg install kmod-ipv6 radvd ip kmod-ip6tables ip6tables
Net.get_hostname = function ()
    local content = misc.execute ( "hostname", "-s" )
    if ( content ~= nil ) then
        return content, nil
    else
        return nil, nil
    end
end

Net.list_phys = function ()
    local phys = {}
    if ( lfs.attributes ( Net.debugfs ) == nil ) then
        return nil, "Permission denied to access debugfs"
    end
    for file in lfs.dir ( Net.debugfs ) do
        if (file ~= "." and file ~= "..") then
            phys [ #phys + 1 ] = file
        end
    end
    table.sort ( phys )
    return phys
end

Net.get_interface_name = function ( phy )
    local dname = Net.debugfs .. "/" .. phy
    if ( lfs.attributes ( dname ) == nil ) then
        return nil, "Permission denied to access debugfs"
    end
    for file in lfs.dir( dname ) do
        if ( string.sub ( file, 1, 7 ) == "netdev:" and string.sub ( file, 8, 10 ) ~= "mon" ) then
            return string.sub( file, 8 )
        end
    end
    return nil, "No debugfs entry for " .. phy .. " found"
end

function Net.run ( port, name, log_f )
    if rpc.mode ~= "tcpip" then
        log_f ( "Err: tcp/ip supported only" )
        return nil
    end
    if ( port == nil ) then
        log_f ( "Err: port number not set" )
        return nil
    end
    log_f ( " Start service " .. ( name or "unset" ) .. " with PRC port " .. tostring ( port ) )
    rpc.server ( port )
end

Net.connect = function ( addr, port, runs, name, log_f )

    if rpc.mode ~= "tcpip" then
        print ( "Err: rpc mode tcp/ip is supported only" )
        return nil
    end

    function connect_rpc ()
        local slave, err = rpc.connect ( addr, port )
        return slave, err
    end

    local status
    local slave
    local err
    local retrys = runs

    repeat
        status, slave, err = pcall ( connect_rpc )
        retrys = retrys - 1
        if ( status == false ) then posix.sleep (1) end
    until status == true or retrys == 0

    if ( status == false ) then
        log_f ( "Err: Connection to " .. name .. " failed" )
        log_f ( "Err: no rpc node at address: " .. ( addr or "none" )
                                                .. " on port: " .. ( port or "none" ) )
        return nil
    end

    return slave
end

Net.disconnect = function ( slave )
    if ( slave ~= nil ) then
        rpc.close ( slave )
    end
end

return Net
