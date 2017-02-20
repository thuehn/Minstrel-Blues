require ('NodeRef')

AccessPointRef = NodeRef:new()

function AccessPointRef:create ( name, ctrl, port )
    -- fixme: init of wifis, addrs should be done by NodeRef:create
    local o = AccessPointRef:new{ name = name, ctrl = ctrl, wifis = {}, addrs = {}, macs = {}, ssid = nil
                                , stations = {}, refs = {} }
    return o
end

function AccessPointRef:__tostring() 
    local out = NodeRef.__tostring( self )

    out = out .. "\n\t"
          .. "stations: "
    if ( self.stations == {} ) then
        out = out .. " none"
    else
        local i = 1
        for _, mac in pairs ( self.stations ) do
            if ( i ~= 1 ) then out = out .. ", " end
            out = out .. mac
            i = i + 1
        end
    end

    return out
end

-- fixme: map by phy0, phy1
function AccessPointRef:add_station ( mac, ref )
    --self.stations [ mac ] = ref
    self.stations [ #self.stations + 1 ] = mac
    self.refs [ #self.refs + 1 ] = ref
end

function AccessPointRef:set_ssid ( ssid )
    self.ssid = ssid 
end

function AccessPointRef:get_ssid ()
    return self.ssid
end

function AccessPointRef:create_measurement()
    NodeRef.create_measurement( self )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:create_measurement()
    end
end

function AccessPointRef:restart_wifi( )
    NodeRef.restart_wifi( self )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:restart_wifi()
    end
end

function AccessPointRef:add_monitor( )
    NodeRef.add_monitor( self, self.wifi_cur )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:add_monitor()
    end
end

function AccessPointRef:remove_monitor( )
    NodeRef.remove_monitor( self, self.wifi_cur )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:remove_monitor()
    end
end

function AccessPointRef:wait_linked( retrys )
    for i, sta_ref in ipairs ( self.refs ) do
        local res = sta_ref:wait_linked ( retrys )
        if ( res == false ) then
            break
        end
    end
end

function AccessPointRef:start_measurement( key )
    NodeRef.start_measurement( self, key )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:start_measurement ( key )
    end
end

function AccessPointRef:stop_measurement( key )
    NodeRef.stop_measurement( self, key )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:stop_measurement ( key )
    end
end


function AccessPointRef:start_iperf_servers()
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:start_iperf_server ()
    end
end

function AccessPointRef:stop_iperf_servers()
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:stop_iperf_server ()
    end
end
