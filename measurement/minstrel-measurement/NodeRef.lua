
local posix = require ('posix') -- sleep

require ('Measurement')
require ('NetIF')

NodeRef = { name = nil
          , ctrl = nil
          , rsa_key = nil
          , rpc = nil
          , phys = nil
          , wifi_cur = nil
          , addrs = nil
          , macs = nil
          , stats = nil
          , output_dir = nil
          , is_passive = nil
          , control_node = nil
          }

function NodeRef:new (o)
    local o = o or {}
    o.phys = {}
    o.addrs = {}
    o.macs = {}
    o.stats = {}
    o.refs = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- pre: connected to node
-- post: phys set, macs set, addrs.set
function NodeRef:init ( rpc )
    self.rpc = rpc
    if ( self.rpc ~= nil) then
        self.phys = self.rpc.phy_devices()
        for _, phy in ipairs ( self.phys ) do
            self.addrs [ phy ] = self.rpc.get_addr ( phy )
            if ( self.macs [ phy ] == nil ) then
                self.macs [ phy ] = self.rpc.get_mac ( phy )
            end
        end
    end
end

function NodeRef:set_phy ( phy )
    self.wifi_cur = phy
end

function NodeRef:get_addr ()
--    return self.rpc.get_addr ( self.wifi_cur )
    return self.addrs [ self.wifi_cur ]
end

function NodeRef:get_mac ()
    return self.macs [ self.wifi_cur ]
end

function NodeRef:__tostring ()
    local out = ""
    out = out .. self.name .. " :: " 
          .. "ctrl: " .. tostring ( self.ctrl ) .. "\n\t"
    if ( self.rpc ~= nil ) then
        out = out .. "rpc connected\n\t"
    else
        out = out .. "rpc not connected\n\t"
    end
    out = out .. "phys: "
    if ( self.phys == {} ) then
        out = out .. " none"
    else
        for i, phy in ipairs ( self.phys ) do
            if ( i ~= 1 ) then out = out .. "\n\t" end
            local addr = self.addrs [ phy ]
            if ( addr == nil ) then addr = "none" end
            out = out .. phy .. ", addr " .. addr
            local mac = self.macs [ phy ]
            if ( mac == nil ) then mac = "none" end
            out = out .. ", mac " .. mac
        end
    end
    return out
end

-- wait for station is linked to ssid
function NodeRef:wait_linked ( runs )
    local connected = false

    if ( self.is_passive ~= nil and self.is_passive == true ) then
        return true
    end

    local retrys = runs
    repeat
        local ssid = self.rpc.get_linked_ssid ( self.wifi_cur )
        if ( ssid == nil ) then 
            posix.sleep (1)
        else
            connected = true
        end
        retrys = retrys - 1
    until connected or retrys == 0
    return retrys ~= 0
end

function NodeRef:create_measurement()
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.stats = Measurement:create ( self.name, self:get_mac (), self:get_opposite_macs (), self.rpc, self.output_dir )
    end
end

function NodeRef:restart_wifi( )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.restart_wifi ()
    end
end

function NodeRef:add_monitor( )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.add_monitor ( self.wifi_cur )
    end
end

function NodeRef:remove_monitor( )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.remove_monitor ( self.wifi_cur )
    end
end

function NodeRef:start_measurement( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.stats:start ( self.wifi_cur, key )
    end
end

function NodeRef:stop_measurement( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.stats:stop ()
    end
end

-- collect traces
function NodeRef:fetch_measurement( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.stats:fetch ( self.wifi_cur, key )
    end
end

function NodeRef:start_tcp_iperf_s()
    if ( self.is_passive == nil or self.is_passive == false ) then
        local proc = self.rpc.start_tcp_iperf_s()
    end
end

function NodeRef:start_udp_iperf_s()
    if ( self.is_passive == nil or self.is_passive == false ) then
        local proc = self.rpc.start_udp_iperf_s()
    end
end

function NodeRef:stop_iperf_server()
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.stop_iperf_server()
    end
end

-- TODO: eliminate the next funs with direct calls
-- these are not measurement related ( STAs on APs)
-- but the controller can handle this for the whole
-- Network
function NodeRef:get_board ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.get_board ()
    end
end

function NodeRef:enable_wifi ( enabled )
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.enable_wifi ( enabled, self.wifi_cur )
    end
end

function NodeRef:link_to_ssid ( ssid, phy )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.link_to_ssid ( ssid, phy )
    end
end

function NodeRef:set_nameserver ( nameserver )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.set_nameserver ( nameserver )
    end
end

function NodeRef:set_date ( year, month, day, hour, minute, second )
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.set_date (  year, month, day, hour, minute, second )
    end
end

function NodeRef:check_bridge ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.check_bridge ( self.wifi_cur )
    end
end

function NodeRef:get_free_mem ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.get_free_mem()
    end
end
