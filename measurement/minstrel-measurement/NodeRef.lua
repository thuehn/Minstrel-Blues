
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
          , ssid = nil
          , refs = nil
          , stats = nil
          , iperf_s_proc = nil
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
    if (self.rpc ~= nil) then
        self.phys = self.rpc.phy_devices()
        for _, phy in ipairs ( self.phys ) do
            self.addrs [ phy ] = self.rpc.get_addr ( phy )
            self.macs [ phy ] = self.rpc.get_mac ( phy )
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

function NodeRef:get_mac ( )
    return self.macs [ self.wifi_cur ]
end

function NodeRef:__tostring() 
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
        for i, wifi in ipairs ( self.phys ) do
            if ( i ~= 1 ) then out = out .. ", " end
            local addr = self.addrs [ wifi ]
            if ( addr == nil ) then addr = "none" end
            out = out .. wifi .. ", addr " .. addr
        end
    end
    return out        
end

function NodeRef:link_to_ssid ( ssid, phy )
   self.rpc.link_to_ssid ( ssid, phy )
end

-- wait for station is linked to ssid
function NodeRef:wait_linked ( retrys )
    local connected = false

    repeat
        local ssid = self.rpc.get_linked_ssid ( self.wifi_cur )
        if (ssid == nil) then 
            os.sleep (1)
        else
            connected = true
        end
        retrys = retrys - 1
    until connected or retrys == 0
    return retrys ~= 0
end

function NodeRef:create_measurement()
    self.stats = Measurement:create ( self.name, self.rpc )
end

function NodeRef:restart_wifi( )
end

function NodeRef:add_monitor( )
    self.rpc.add_monitor ( self.wifi_cur )
end

function NodeRef:remove_monitor( )
    self.rpc.remove_monitor ( self.wifi_cur )
end
function NodeRef:start_measurement( key )
    self.stats:start ( self.wifi_cur, key )
end

function NodeRef:stop_measurement( key )
    self.stats:stop ()
    -- collect traces
    self.stats:fetch ( self.wifi_cur, key )
end

function NodeRef:start_iperf_server()
    local iperf_s_proc_str = self.rpc.start_tcp_iperf_s()
    self.iperf_server_proc = parse_process ( iperf_s_proc_str )
end

function NodeRef:stop_iperf_server()
    self.rpc.stop_iperf_server( self.iperf_server_proc['pid'] )
end

function NodeRef:set_nameserver ( nameserver )
    self.rpc.set_nameserver ( nameserver )
end

function NodeRef:set_date ( year, month, day, hour, minute, second )
    return self.rpc.set_date (  year, month, day, hour, minute, second )
end

function NodeRef:check_bridge ()
    return self.rpc.check_bridge ( self.wifi_cur )
end
