
require ('NetIF')
require ('parsers/iw_info')
require ('parsers/iw_link')
local uci = require ('Uci')

local misc = require ('misc')
local pprint = require ('pprint')
local lpc = require ('lpc')

WifiIF = NetIF:new()
local debugfs = "/sys/kernel/debug/ieee80211"

function WifiIF:create ( iface, addr, mon, phy, node )
    local o = WifiIF:new ( { iface = iface
                           , addr = addr
                           , mon = mon
                           , phy = phy
                           , node = node
                           , regmon_proc = nil
                           } )

    return o
end

function WifiIF:enable_wifi ( enabled )
    if ( self.node.proc_version.system == "LEDE" ) then
        local var = "wireless.radio"
        var = var .. string.sub ( self.phy, 4, string.len ( self.phy ) )
        var = var .. ".disabled"
        self.node:send_debug ( " enable wifi: " .. var .. " = " .. tostring ( not enabled ) )
        local value = 1
        if ( enabled == true ) then 
            value = 0
        else
            value = 1
        end
        local _, exit_code = uci.set_var ( var, value )
        return ( exit_code == 0 )
    end
    return true
end

function WifiIF:get_iw_info ()
    self.node:send_info ( "send iw info for " .. ( self.iface or "none" ) )
    local str, exit_code = misc.execute ( "iw", self.iface, "info" )
    if ( str ~= nil and exit_code == 0) then
        return str
    end
    return nil
end

-- AP only
-- wireless.default_radio0.ssid='LEDE'
function WifiIF:get_ssid ()
    self.node:send_info ( "send ssid for " .. ( self.iface or "none" ) )
    local str, exit_code = misc.execute ( "iw", self.iface, "info" )
    if ( str ~= nil and exit_code == 0) then
        local iwinfo = parse_iwinfo ( str )
        if ( iwinfo ~= nil ) then
            self.node:send_info ( " ssid " .. ( iwinfo.ssid or "none" ) )
            return iwinfo.ssid, nil
        end
    end
    return nil, nil
end

function WifiIF:restart_wifi ()
    self.node:send_debug ("restart wifi" )
    if ( self.node.proc_version.system == "LEDE" ) then
        local wifi, err = misc.execute ( "/sbin/wifi" )
        self.node:send_info( "restart wifi done: " .. wifi )
        return true
    elseif ( self.node.proc_version.system == "Gentoo" ) then
        local init_script = "/etc/init.d/net." .. self.iface
        if ( isFile ( init_script ) ) then
            local wifi, err = misc.execute ( init_script, "restart")
            self.node:send_info( "restart wifi done (" .. ( self.iface or "none" ) .. "): " .. ( wifi or "none" ) )
            return ( err == 0 )
        end
        self.node:send_debug ( "Cannot restart wifi. No init script found for phy " .. ( self.phy or "none" ) )
        return false
    end
    return false
end

-- iw dev mon0 info
-- iw phy phy0 interface add mon0 type monitor
-- ifconfig mon0 up
function WifiIF:add_monitor ()
    self.node:send_debug ("iw dev " .. self.mon .. " info" )
    local _, exit_code = misc.execute ( "iw", "dev", self.mon, "info" )
    if ( exit_code ~= 0 ) then
        self.node:send_info ( "Adding monitor " .. self.mon .. " to " .. self.phy)
        self.node:send_debug ("iw phy " .. self.phy .. " interface add " .. self.mon .. " type monitor" )
        local _, exit_code = misc.execute ( "iw", "phy", self.phy, "interface", "add", self.mon, "type", "monitor" )
        if ( exit_code ~= 0 ) then
            self.node:send_error ( "Add monitor failed with exit code: " .. exit_code )
            return
        end
    else
        self.node:send_info ( "Monitor " .. self.mon .. " not added to " .. self.phy )
    end
    self.node:send_info ( "enable monitor " .. self.mon )
    self.node:send_debug ( "ifconfig " .. self.mon .. " up" )
    local _, exit_code = misc.execute ("ifconfig", self.mon, "up")
    if ( exit_code ~= 0 ) then
        self.node:send_error ( "add monitor for device " .. self.phy .. "failed with exit code: " .. exit_code )
    end
end

-- iw dev mon0 info
-- iw dev mon0 del
function WifiIF:remove_monitor ()
    local _, exit_code = misc.execute ( "iw", "dev", self.mon, "info" )
    if ( exit_code == 0 ) then
        self.node:send_info ( "Removing monitor " .. self.mon .. " from " .. self.phy )
        self.node:send_debug ( "iw dev " .. self.mon .. " del" )
        local _, exit_code = misc.execute ( "iw", "dev", self.mon, "del" )
        if (exit_code ~= 0) then
            self.node:send_error ( "Remove monitor failed with exit code. " .. exit_code )
        end
    end
end

function WifiIF:get_mac ( bridged )
    local iface = self.iface
    if ( bridged ~= nil and bridged == true ) then
        local bridge = self:check_bridge ( iface )
        if ( bridge ~= nil ) then
            iface = bridge
        end
    end
    self.node:send_info ( "send mac for " .. iface )
    local content = misc.execute ( "ifconfig", iface )
    local ifconfig = parse_ifconfig ( content )
    if ( ifconfig == nil or ifconfig.mac == nil ) then return nil end
    self.node:send_info (" mac for " .. iface .. ": " .. ifconfig.mac )
    return ifconfig.mac
end

function WifiIF:check_bridge ()
    local content = misc.execute ( "brctl", "show" )
    if ( content ~= nil ) then
        local brctl = parse_brctl ( content )
        for _, interface in ipairs ( brctl.interfaces ) do
            if ( self.iface == interface ) then
                return brctl.name
            end
        end
    end
    return nil
end

function WifiIF:get_iw_link ( parse )
    self.node:send_debug ( "iw dev " .. ( self.iface or "none" ) .. " link" )
    self.node:send_info ( "send iw link for " .. ( self.iface or "none" ) )
    if ( self.iface ~= nil ) then
        local content, exit_code = misc.execute ( "iw", "dev", self.iface, "link" )
        --self:send_debug (" " .. ( content or "none" ) )
        --self:send_debug ( "iw link exit code : " .. tostring (exit_code) )
        if ( exit_code > 0 or content == nil) then return nil end
        if ( parse ~= nil and parse == true ) then
            local iwlink = parse_iwlink ( content )
            return iwlink
        else
            return content
        end
    end
end

function WifiIF:set_ani ( enabled )
    self.node:send_info ( "set ani for " .. ( self.phy or "none" ) .. " to " .. tostring ( enabled ) )
    if ( self.phy ~= nil and debugfs ~= nil ) then
        local filename = debugfs .. "/" .. self.phy .. "/" .. "ath9k" .. "/"  .. "ani"
        local file = io.open ( filename, "w" )
        if ( enabled ) then
            file:write(1)
        else
            file:write(0)
        end
        file:close()
    end
end

function WifiIF:list_stations ()
    local stations = debugfs .. "/" .. self.phy .. "/netdev:" .. self.iface .. "/stations/"
    local out = {}
    if ( isDir ( stations ) ) then
        for _, name in ipairs ( scandir ( stations ) ) do
            if ( name ~= "." and name ~= "..") then
                out [ #out + 1 ] = name
            end
        end
    end
    return out
end

-- --------------------------
-- regmon stats
-- --------------------------

local fetch_file_bin = "/usr/bin/fetch_file"

function WifiIF:start_regmon_stats ()
    if ( self.regmon_proc ~= nil ) then
        self.node:send_error ( "Not collecting regmon stats for " 
                               .. self.iface .. ", " .. self.phy .. ". Alraedy running" )
        return nil
    end
    local file = debugfs .. "/" .. self.phy .. "/regmon/register_log"
    if ( not isFile ( file ) ) then
        self.node:send_warning ( "no regmon-stats for " .. self.iface .. ", " .. self.phy )
        self.regmon_proc = nil
        return nil
    end
    self.node:send_info ( "start collecting regmon stats for " .. self.iface .. ", " .. self.phy )
    local pid, stdin, stdout = misc.spawn ( "lua", fetch_file_bin, "-l", "-i", 500000000, file )
    self.regmon_proc = { pid = pid, stdin = stdin, stdout = stdout }
    return pid
end

function WifiIF:get_regmon_stats ()
    if ( self.regmon_proc == nil ) then 
        self.node:send_error ( "no regmon process running" )
        return nil 
    end
    self.node:send_info ( "send regmon-stats" )
    local content = self.regmon_proc.stdout:read ( "*a" )
    self.regmon_proc.stdin:close ()
    self.regmon_proc.stdout:close ()
    self.node:send_info ( string.len ( content ) .. " bytes from regmon" )
    self.regmon_proc = nil
    return content
end

function WifiIF:stop_regmon_stats ()
    if ( self.regmon_proc == nil ) then 
        self.node:send_error ( "no regmon process running" )
        return nil 
    end
    self.node:send_info ( "stop collecting regmon stats with pid " .. self.regmon_proc.pid )
    local exit_code
    if ( self.node:kill ( self.regmon_proc.pid ) ) then
        exit_code = lpc.wait ( self.regmon_proc.pid )
    end
    return exit_code
end
