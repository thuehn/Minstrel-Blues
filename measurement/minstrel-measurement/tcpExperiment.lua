require ('Experiment')

TcpExperiment = Experiment:new()

function TcpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function TcpExperiment:create ( control, data, is_fixed )
    local o = TcpExperiment:new( { control = control, runs = data[1]
                                 , tx_powers = data[2], tx_rates = data[3]
                                 , tcpdata = data[4] 
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
            self.tx_powers = ap_ref.rpc.tx_power_indices ( ap_ref.wifi_cur, ap_ref.stations[1] )
        else
            self.tx_powers = split ( self.tx_powers, "," )
        end
    end

    if ( self.is_fixed == true ) then
        self.control:send_debug( "run tcp experiment for rates " .. table_tostring ( self.tx_rates, 80 ) )
        self.control:send_debug( "run tcp experiment for powers " .. table_tostring ( self.tx_powers, 80 ) )
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

function TcpExperiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
    ap_ref:start_tcp_iperf_s ()
end

function TcpExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_iperf_servers()
    ap_ref:stop_measurement ( key )
end

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
