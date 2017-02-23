
McastExperiment = { runs = nil, udp_interval = nil }

function McastExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function McastExperiment:create ( data )
    local o = McastExperiment:new( { runs = data[1], udp_interval = data[2] } )
    return o
end

function McastExperiment:keys ( ap_ref )

    local keys = {}
    local tx_rates = ap_ref.rpc.tx_rate_indices( ap_ref.wifi_cur, ap_ref.stations[1] )
    local tx_powers = {}
    for i = 1, 25 do
        tx_powers[i] = i
    end

    for run = 1, self.runs do
        for _, tx_rate in ipairs ( tx_rates ) do
            for _, tx_power in ipairs ( tx_powers ) do
                local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) .. "-" .. tostring(run)
                keys [ #keys + 1 ] = key
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
    local ret = ap_ref:wait_linked ( retrys )
    ap_ref:add_monitor ()
    return ret
end

function McastExperiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
end

function McastExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_measurement ( key )
end

function McastExperiment:unsettle_measurement ( ap_ref, key )
    ap_ref:remove_monitor ()
end

function McastExperiment:start_experiment ( ap_ref, key )
    local wait = false
    for i, sta_ref in ipairs ( ap_ref.refs ) do
        -- start iperf client on AP
        local addr = "224.0.67.0"
        local ttl = 32
        local size = "100M"
        ap_ref.rpc.run_multicast( sta_ref:get_addr ( sta_ref.wifi_cur ), addr, ttl, size, self.udp_interval, wait )
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

