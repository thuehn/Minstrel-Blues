
local misc = require ('misc')
local posix = require ('posix') -- sleep
require ('NodeRef')

AccessPointRef = NodeRef:new()

function AccessPointRef:create ( name, ctrl, rsa_key, output_dir )
    local o = AccessPointRef:new { name = name, ctrl = ctrl, rsa_key = rsa_key, output_dir = output_dir, refs = {}, stations = {} }
    o.ctrl:get_addr()
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
    for _, ref2 in ipairs ( self.refs ) do
        if ( ref2.name == ref.name ) then
            return
        end
    end
    self.stations [ #self.stations + 1 ] = mac
    self.refs [ #self.refs + 1 ] = ref
end

function AccessPointRef:randomize_stations ()
    self.stations = misc.randomize_list ( self.stations )
    self.refs = misc.randomize_list ( self.refs )
end

-- all macs of linked stations are returned
function AccessPointRef:get_opposite_macs ()
    return self.stations
end

-- waits until all stations appears on ap
-- not precise, sta maybe not really connected afterwards
-- waits until station is reachable (not mandatory  connected)
function AccessPointRef:wait_station ( runs )
    local retrys = runs
    repeat
        local wifi_stations_cur = self.rpc.visible_stations ( self.wifi_cur )
        local miss = false
        for _, str in ipairs ( self.stations ) do
            if ( table.contains ( wifi_stations_cur, str ) == false ) then
                miss = true
                break
            end
        end
        retrys = retrys - 1
        posix.sleep (1)
    until not miss or retrys == 0
    return retrys ~= 0
end

function AccessPointRef:set_tx_power ( power )
    for _, str in ipairs ( self.stations ) do
        self.rpc.set_tx_power ( self.wifi_cur, str, power )
    end
end

function AccessPointRef:set_tx_rate ( rate_idx )
    for _, str in ipairs ( self.stations ) do
        self.rpc.set_tx_rate ( self.wifi_cur, str, rate_idx )
    end
end

function AccessPointRef:create_measurement()
    NodeRef.create_measurement( self )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:create_measurement()
    end
end

function AccessPointRef:restart_wifi ()
    --fixme: router reboot when "/sbin/wifi" is executed on AP
    --NodeRef.restart_wifi ( self )
    --posix.sleep ( 20 )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:restart_wifi ()
    end
end

function AccessPointRef:add_monitor ()
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

function AccessPointRef:fetch_measurement( key )
    NodeRef.fetch_measurement( self, key )
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:fetch_measurement ( key )
    end
end

function AccessPointRef:start_iperf_servers ( tcp )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( tcp == true ) then
            sta_ref:start_tcp_iperf_s ()
        else
            sta_ref:start_udp_iperf_s ()
        end
    end
end

function AccessPointRef:stop_iperf_servers()
    for i, sta_ref in ipairs ( self.refs ) do
        sta_ref:stop_iperf_server ()
    end
end
