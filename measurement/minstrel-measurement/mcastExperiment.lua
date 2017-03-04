
McastExperiment = { control = nil, runs = nil, tx_powers = nil, tx_rates = nil, udp_interval = nil, tx_rates = nil, tx_powers = nil }

function McastExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function McastExperiment:get_rate( key )
    return split ( key, "-" ) [1]
end

function McastExperiment:get_power( key )
    return split ( key, "-" ) [2]
end

function McastExperiment:create ( control, data )
    local o = McastExperiment:new( { control = control, runs = data[1], tx_powers = data[2], tx_rates = data[3], udp_interval = data[4] } )
    return o
end

function McastExperiment:keys ( ap_ref )

    local keys = {}
    if ( self.tx_rates == nil ) then
        self.tx_rates = ap_ref.rpc.tx_rate_indices( ap_ref.wifi_cur, ap_ref.stations[1] )
    end
    if ( self.tx_powers == nil ) then
        self.tx_powers = {}
        for i = 1, 25 do
            self.tx_powers[i] = i
        end
    end
    self.control:send_debug( "run multicast experiment for rates " .. table_tostring ( self.tx_rates ) )
    self.control:send_debug( "run multicast experiment for powers " .. table_tostring ( self.tx_powers ) )

    for run = 1, self.runs do
        for _, tx_rate in ipairs ( self.tx_rates ) do
            for _, tx_power in ipairs ( self.tx_powers ) do
                local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) .. "-" .. tostring( run )
                keys [ #keys + 1 ] = key
                --break -- REMOVE ME: testing only
            end
        end
    end

    return keys
end

function McastExperiment:prepare_measurement ( ap_ref )
    ap_ref:create_measurement()
    ap_ref.stats:enable_rc_stats ( ap_ref.stations )
end

function McastExperiment:settle_measurement ( ap_ref, key, retrys )
    ap_ref:restart_wifi ()
    local linked = ap_ref:wait_linked ( retrys )
    local visible = ap_ref:wait_station ( retrys )
    ap_ref:add_monitor ()
    ap_ref:set_tx_power ( self:get_power ( key ) )
    ap_ref:set_tx_rate ( self:get_rate ( key ) )
    return (linked and visible)
end

function McastExperiment:start_measurement ( ap_ref, key )
    return ap_ref:start_measurement ( key )
end

function McastExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_measurement ( key )
end

function McastExperiment:unsettle_measurement ( ap_ref, key )
    ap_ref:remove_monitor ()
end

function McastExperiment:start_experiment ( ap_ref, key )
    local wait = false
    local ap_wifi_addr = ap_ref:get_addr ( ap_ref.wifi_cur )
    self.control:send_debug ( "run multicast udp server with local addr " .. ap_wifi_addr )
    for i, sta_ref in ipairs ( ap_ref.refs ) do
        -- start iperf client on AP
        local addr = "224.0.67.0"
        local ttl = 32
        local size = "100M"
        local wifi_addr = sta_ref:get_addr ( sta_ref.wifi_cur )
        self.control:send_debug ( "run multicast udp client with local addr " .. wifi_addr )
        if ( ap_ref.rpc.run_multicast( wifi_addr, addr, ttl, size, self.udp_interval, wait ) == nil ) then
            return false
        end
    end
    return true
end

function McastExperiment:wait_experiment ( ap_ref )
    -- wait for clients on AP
    for _, sta_ref in ipairs ( ap_ref.refs ) do
        local addr = sta_ref:get_addr ( sta_ref.wifi_cur )
        ap_ref.rpc.wait_iperf_c( addr )
    end
end

function create_mcast_measurement ( runs, udp_interval )
    local mcast_exp = McastExperiment:create( runs, udp_interval )
    return function ( ap_ref ) return run_experiment ( mcast_exp, ap_ref ) end
end

