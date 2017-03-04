require ('Experiment')

TcpExperiment = { control = nil, runs = nil, tx_powers = nil, tx_rates = nil, tcpdata = nil }


function TcpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function TcpExperiment:create ( control, data )
    local o = TcpExperiment:new( { control = control, runs = data[1], tx_powers = data[2], tx_rates = data[3], tcpdata = data[2] } )
    return o
end

function TcpExperiment:keys ( ap_ref )
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
    self.control:send_debug( "run tcp experiment for rates " .. table_tostring ( self.tx_rates ) )
    self.control:send_debug( "run tcp experiment for powers " .. table_tostring ( self.tx_powers ) )

    for run = 1, self.runs do
        for _, tx_rate in ipairs ( self.tx_rates ) do
            for _, tx_power in ipairs ( self.tx_powers ) do
                local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) .. "-" .. tostring( run )
                keys [ #keys + 1 ] = key
            end
        end
    end

    return keys
end

function TcpExperiment:get_rate( key )
    return split ( key, "-" ) [1]
end

function TcpExperiment:get_power( key )
    return split ( key, "-" ) [2]
end

function TcpExperiment:prepare_measurement ( ap_ref )
    ap_ref:create_measurement()
    ap_ref.stats:enable_rc_stats ( ap_ref.stations )
end

function TcpExperiment:settle_measurement ( ap_ref, key, retrys )
    ap_ref:restart_wifi ()
    local linked = ap_ref:wait_linked ( retrys )
    local visible = ap_ref:wait_station ( retrys )
    ap_ref:add_monitor ()
    ap_ref:set_tx_power ( self:get_power ( key ) )
    ap_ref:set_tx_rate ( self:get_rate ( key ) )
    return (linked and visible)
end

function TcpExperiment:start_measurement ( ap_ref, key )
    local started = ap_ref:start_measurement ( key )
    ap_ref:start_iperf_servers()
    return started
end

function TcpExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_iperf_servers()
    ap_ref:stop_measurement ( key )
end

function TcpExperiment:unsettle_measurement ( ap_ref, key )
    ap_ref:remove_monitor ()
end

-- fixme: wait
function TcpExperiment:start_experiment ( ap_ref, key )
    -- start iperf clients on AP
    for _, sta_ref in ipairs ( ap_ref.refs ) do
        local addr = sta_ref:get_addr ()
        if ( addr == nil ) then
            error ( "start_experiment: address is unset" )
            return
        end
        local wait = false
        if ( ap_ref.rpc.run_tcp_iperf( addr, self.tcpdata, wait ) == false ) then
            return false
        end
    end
    return true
end

function TcpExperiment:wait_experiment ( ap_ref )
    -- wait for clients on AP
    for _, sta_ref in ipairs ( ap_ref.refs ) do
        local addr = sta_ref:get_addr ()
        if ( addr == nil ) then
            error ( "wait_experiment: address is unset" )
            return
        end
        ap_ref.rpc.wait_iperf_c( addr )
    end
end

function create_tcp_measurement ( runs, tcpdata )
    local tcp_exp = TcpExperiment:create( runs, tcpdata )
    return function ( ap_ref ) return run_experiment ( tcp_exp, ap_ref ) end
end
