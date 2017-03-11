require ('Experiment')

TcpExperiment = { control = nil, runs = nil, tx_powers = nil, tx_rates = nil, tcpdata = nil
                , is_fixed = nil }


function TcpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function TcpExperiment:create ( control, data, is_fixed )
    local o = TcpExperiment:new( { control = control, runs = data[1]
                                 , tx_powers = data[2], tx_rates = data[3]
                                 , tcpdata = data[2] 
                                 , is_fixed = is_fixed
                                 } )
    return o
end

function TcpExperiment:keys ( ap_ref )
    local keys = {}
    if ( self.is_fixed == true ) then
        if ( self.tx_rates == nil ) then
            self.tx_rates = ap_ref.rpc.tx_rate_indices ( ap_ref.wifi_cur, ap_ref.stations[1] )
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
        self.control:send_debug( "run tcp experiment for rates " .. table_tostring ( self.tx_rates ) )
        self.control:send_debug( "run tcp experiment for powers " .. table_tostring ( self.tx_powers ) )
    end

    for run = 1, self.runs do
        local run_key = tostring ( run )
        if ( self.is_fixed == true and ( self.tx_rates ~= nil and self.tx_powers ~= nil ) ) then
            for _, tx_rate in ipairs ( self.tx_rates ) do
                local rate_key = tostring ( tx_rate )
                for _, tx_power in ipairs ( self.tx_powers ) do
                    local power_key = tostring ( tx_power )
                    keys [ #keys + 1 ] = rate_key .. "-" .. power_key .. "-" .. run_key
                end
            end
        else
            keys [ #keys + 1 ] = run_key
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
    local visible = ap_ref:wait_station ( retrys )
    local linked = ap_ref:wait_linked ( retrys )
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

function TcpExperiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
    ap_ref:start_iperf_servers ()
end

function TcpExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_iperf_servers()
    ap_ref:stop_measurement ( key )
end

function TcpExperiment:fetch_measurement ( ap_ref, key )
    ap_ref:fetch_measurement ( key )
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
        local pid, exit_code = ap_ref.rpc.run_tcp_iperf ( addr, self.tcpdata, wait )
    end
end

function TcpExperiment:wait_experiment ( ap_ref )
    -- wait for clients on AP
    for _, sta_ref in ipairs ( ap_ref.refs ) do
        local addr = sta_ref:get_addr ()
        if ( addr == nil ) then
            error ( "wait_experiment: address is unset" )
            return
        end
        local exit_code = ap_ref.rpc.wait_iperf_c( addr )
    end
end

function create_tcp_measurement ( runs, tcpdata )
    local tcp_exp = TcpExperiment:create( runs, tcpdata )
    return function ( ap_ref ) return run_experiment ( tcp_exp, ap_ref ) end
end
