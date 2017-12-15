
local misc = require ('misc')
local posix = require ('posix') -- sleep
require ('NodeRef')

AccessPointRef = NodeRef:new()

function AccessPointRef:create ( name, lua_bin, ctrl_if, rsa_key, output_dir, log_addr, log_port, retries )
    local ctrl_net_ref = NetIfRef:create ( ctrl_if )
    ctrl_net_ref:set_addr ( name )

    local o = AccessPointRef:new { name = name
                                 , lua_bin = lua_bin
                                 , ctrl_net_ref = ctrl_net_ref
                                 , rsa_key = rsa_key
                                 , output_dir = output_dir
                                 , refs = {}
                                 , stations = {}
                                 , log_addr = log_addr
                                 , log_port = log_port
                                 , retries = retries
                                 }
    return o
end

function AccessPointRef:__tostring ()
    local out = NodeRef.__tostring ( self )

    out = out .. "\n\t"
          .. "stations: "
    if ( self.stations == {} ) then
        out = out .. " none"
    else
        local i = 1
        for _, mac in pairs ( self.stations ) do
            if ( i ~= 1 ) then out = out .. ", " end
            out = out .. ( mac or "none" )
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

-- all macs of linked stations are returned
function AccessPointRef:get_opposite_macs_br ()
    local macs = {}
    for _, node_ref in ipairs ( self.refs ) do
        macs [ #macs + 1 ] = node_ref:get_mac_br ()
    end
    return macs
end

-- waits until all stations appears on ap
-- not precise, sta maybe not really connected afterwards
-- waits until station is reachable (not mandatory  connected)
function AccessPointRef:wait_station ()
    local retries = tonumber ( self.retries )
    repeat
        self.log_ref:send_info ( "wait for stations becomes visible" )
        local wifi_stations_cur = self.rpc.visible_stations ( self.wifi_cur )
        self.log_ref:send_debug ( "stations visible: " .. table_tostring ( wifi_stations_cur ) )
        local miss = false
        for _, str in ipairs ( self.stations ) do
            self.log_ref:send_debug ( " check visibility of " .. str )
            if ( table.contains ( wifi_stations_cur, str ) == false ) then
                miss = true
                break
            end
        end
        retries = retries - 1
        posix.sleep (1)
    until ( miss == false or retries == 0 )
    return retries ~= 0
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

function AccessPointRef:create_measurement ( online )
    NodeRef.create_measurement ( self, online )
    self.stats.enable_rc_stats ( self.stations )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref:create_measurement ( online )
        end
    end
end

function AccessPointRef:restart_wifi ()
    --fixme: router reboot when "/sbin/wifi" is executed on AP
    --NodeRef.restart_wifi ( self )
    --self.rpc.restart_wifi ( self.wifi_cur )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref.rpc.restart_wifi ( sta_ref.wifi_cur )
            --sta_ref:restart_wifi ()
        end
    end
end

function AccessPointRef:add_monitor ()
    NodeRef.add_monitor ( self, self.wifi_cur )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref:add_monitor()
        end
    end
end

function AccessPointRef:remove_monitor ()
    NodeRef.remove_monitor ( self, self.wifi_cur )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref:remove_monitor()
        end
    end
end

function AccessPointRef:wait_linked ()
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            local res = sta_ref:wait_linked ()
            if ( res == false ) then
                return false
            end
        end
    end
    return true
end

function AccessPointRef:start_measurement ( key )
    NodeRef.start_measurement ( self, key )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref:start_measurement ( key )
        end
    end
end

function AccessPointRef:stop_measurement ( key )
    NodeRef.stop_measurement ( self, key )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref:stop_measurement ( key )
        end
    end
end

function AccessPointRef:fetch_measurement ( key )
    self.log_ref:send_debug ( "AccessPointRef:fetch_measurement for key: " .. ( key or "none" ) )
    local succ, res = NodeRef.fetch_measurement ( self, key )
    if ( succ == false ) then
        return succ, res
    end
    self:send_debug ( "AccesspointRef:fetch_measurement " .. self.name .. ": " .. self.stats:__tostring() )
    local self_running = res
    local experiments_running = {}
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            self.log_ref:send_debug ( "AccessPointRef:fetch_measurement for station: " .. ( sta_ref.name or "none" ) )
            local succ, res = sta_ref:fetch_measurement ( key )
            if ( succ == false ) then
                return succ, res
            end
            self:send_debug ( "AccesspointRef:fetch_measurement " .. sta_ref.name .. ":" .. sta_ref.stats:__tostring() )
            experiments_running [i] = res
        end
    end
    return true, ( self_running and Misc.all_true ( experiments_running ) )
end

function AccessPointRef:cleanup_measurement ( key )
    NodeRef.cleanup_measurement ( self, key )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            sta_ref:cleanup_measurement ( key )
        end
    end
end

function AccessPointRef:start_iperf_servers ( tcp, key )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            if ( tcp == true ) then
                sta_ref:start_tcp_iperf_s ( key )
            else
                sta_ref:start_udp_iperf_s ( key )
            end
        end
    end
end

function AccessPointRef:stop_iperf_servers ( key )
    for i, sta_ref in ipairs ( self.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            local _, out = sta_ref:stop_iperf_server ( key )
            self.stats.iperf_s_outs [ key ] = out
        end
    end
end

function AccessPointRef:is_exp_running ( )
    local running = false
    for i, sta_ref in ipairs ( self.refs ) do
        running = running or sta_ref:is_exp_running ()
    end
    running = running or NodeRef.is_exp_running ( self )
    return running
end
