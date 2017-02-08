require ('NetIF')

NodeRef = { name = nil
          , ctrl = nil
          , rpc = nil
          , wifis = nil
          , addrs = nil
          , macs = nil
          , ssid = nil
          }

function NodeRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NodeRef:create ( name, ctrl, port )
    local o = NodeRef:new({ name = name, ctrl = ctrl, wifis = {}, ssid = nil, addrs = {}, macs = {}, ssid = nil, stations = {} })
    return o
end

function NodeRef:connect ( port )
    function connect_rpc ()
        local l, e = rpc.connect ( self.ctrl.addr, port )
        return l, e
    end
    local status, slave, err = pcall ( connect_rpc )
    if (status == false) then
        print ( "Err: Connection to node failed" )
        print ( "Err: no node at address: " .. self.ctrl.addr .. " on port: " .. port )
        return
    end
    self.rpc = slave
end

function NodeRef:add_wifi ( phy )
    self.wifis [ #self.wifis + 1 ] = phy
    self.addrs [ phy ] = self.rpc.get_addr ( phy )
    self.macs [ phy ] = self.rpc.get_mac ( phy )
end

function NodeRef:get_addr ( phy )
    return self.addrs [ phy ]
end

function NodeRef:get_mac ( phy )
    return self.macs [ phy ]
end

function NodeRef:__tostring() 
    local out = ""
    out = out .. self.name .. " :: " 
          .. "ctrl: " .. tostring ( self.ctrl ) .. "\n\t"
          .. "wifis: "
    if ( self.wifis == {} ) then
        out = out .. " none"
    else
        for i, wifi in ipairs ( self.wifis ) do
            if ( i ~= 1 ) then out = out .. ", " end
            out = out .. wifi .. ", addr " .. self.addrs [ wifi ]
        end
    end
    return out        
end

-- waits until all stations appears on ap
-- not precise, sta maybe not really connected afterwards
-- but two or three seconds later
-- not used
function NodeRef:wait_station ()
    repeat
        print ("wait for stations to come up ... ")
        os.sleep(1)
        local wifi_stations_cur = self.rpc.stations( ap_phys[1] )
        local miss = false
        for _, str in ipairs ( wifi_stations ) do
            if ( table.contains ( wifi_stations_cur, str ) == false ) then
                miss = true
                break
            end
        end
    until miss
end

-- wait for station is linked to ssid
function NodeRef:wait_linked ( phy )
    local connected = false
    repeat
        local ssid = self.rpc.get_linked_ssid ( phy )
        if (ssid == nil) then 
            print ("Waiting: Station " .. self.name .. " not connected")
            os.sleep (1)
        else
            print ("Station " .. self.name .. " connected to " .. ssid)
            connected = true
        end
    until connected
end

