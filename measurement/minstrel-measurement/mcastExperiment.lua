-- 1 run: 0.41s user 0.75s system 0% cpu 1:49:45.91 total

-- runs an multicast experiment with fixed rate and fixed power setting
McastExperiment = { control = nil, runs = nil, tx_powers = nil, tx_rates = nil, udp_interval = nil, tx_rates = nil, tx_powers = nil
                  , is_fixed = nil }

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

function McastExperiment:create ( control, data, is_fixed )
    local o = McastExperiment:new( { control = control, runs = data[1], tx_powers = data[2], tx_rates = data[3]
                                   , udp_interval = data[4]
                                   , is_fixed = is_fixed
                                   } )
    return o
end

function McastExperiment:keys ( ap_ref )

    local keys = {}
    if ( self.is_fixed == true ) then
        if ( self.tx_rates == nil ) then
            self.tx_rates = ap_ref.rpc.tx_rate_indices( ap_ref.wifi_cur, ap_ref.stations[1] )
        else
            self.tx_rates = split ( self.tx_rates, "," )
        end
    end

    if ( self.is_fixed == true ) then
        if ( self.tx_powers == nil ) then
            self.tx_powers = {}
            for i = 1, 25 do
                self.tx_powers[i] = i
            end
        else
            self.tx_powers = split ( self.tx_powers, "," )
        end
    end

    if ( self.is_fixed == true ) then
        self.control:send_debug( "run multicast experiment for rates " .. table_tostring ( self.tx_rates ) )
        self.control:send_debug( "run multicast experiment for powers " .. table_tostring ( self.tx_powers ) )
    end

    for run = 1, self.runs do
        local run_key = tostring ( run )
        if ( self.is_fixed == true and ( self.tx_rates ~= nil and self.tx_powers ~= nil ) ) then
            for _, tx_rate in ipairs ( self.tx_rates ) do
                local rate_key = tostring ( tx_rate )
                for _, tx_power in ipairs ( self.tx_powers ) do
                    local power_key = tostring ( tx_power )
                    keys [ #keys + 1 ] =  rate_key .. "-" .. power_key .. "-" .. run_key
                end
            end
        else
            keys [ #keys + 1 ] = run_key
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
    if ( self.is_fixed == true ) then
        for _, station in ipairs ( ap_ref.stations ) do
            self.control:send_info ( " set tx power and tx rate for station " .. station .. " on phy " .. ap_ref.wifi_cur )
            local tx_rate = self:get_rate ( key )
            ap_ref.rpc.set_tx_rate ( ap_ref.wifi_cur, station, tx_rate )
            local tx_rate_new = ap_ref.rpc.get_tx_rate ( ap_ref.wifi_cur, station )
            if ( tx_rate_new ~= tx_rate ) then
                self.control:send_error ( "rate not set correctly: should be " .. tx_rate 
                                          .. " (set) but is " .. ( tx_rate_new or "unset" ) .. " (actual)" )
            end
            local tx_power = self:get_power ( key )
            ap_ref.rpc.set_tx_power ( ap_ref.wifi_cur, station, tx_power )
            local tx_power_new = ap_ref.rpc.get_tx_power ( ap_ref.wifi_cur, station )
            if ( tx_power_new ~= tx_power ) then
                self.control:send_error ( "tx power not set correctly: should be " .. tx_power 
                                          .. " (set) but is " .. ( tx_power_new or "unset" ) .. " (actual)" )
            end
        end
    end
    return (linked and visible)
end

function McastExperiment:start_measurement ( ap_ref, key )
    return ap_ref:start_measurement ( key )
end

function McastExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_measurement ( key )
end

function McastExperiment:fetch_measurement ( ap_ref, key )
    ap_ref:fetch_measurement ( key )
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

        ap_ref.rpc.run_multicast( wifi_addr, addr, ttl, size, self.udp_interval, wait )
    end
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

