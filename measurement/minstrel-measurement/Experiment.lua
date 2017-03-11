
Experiment = { control = nil
             , runs = nil
             , tx_powers = nil
             , tx_rates = nil
             , tcpdata = nil
             , is_fixed = nil }


function Experiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Experiment:keys ( ap_ref )
    local keys = {}
    return keys
end

function Experiment:get_rate( key )
    if ( key ~= nil ) then
        return split ( key, "-" ) [1]
    end
end

function Experiment:get_power( key )
    if ( key ~= nil ) then
        return split ( key, "-" ) [2]
    end
end

function Experiment:prepare_measurement ( ap_ref )
    ap_ref:create_measurement()
    ap_ref.stats:enable_rc_stats ( ap_ref.stations )
end

function Experiment:settle_measurement ( ap_ref, key, retrys )
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

function Experiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
    ap_ref:start_iperf_servers ()
end

function Experiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_iperf_servers()
    ap_ref:stop_measurement ( key )
end

function Experiment:fetch_measurement ( ap_ref, key )
    ap_ref:fetch_measurement ( key )
end

function Experiment:unsettle_measurement ( ap_ref, key )
    ap_ref:remove_monitor ()
end

function Experiment:start_experiment ( ap_ref, key )
    self.control:send_debug("start_experiment not implemented")
end

function Experiment:wait_experiment ( ap_ref )
    self.control:send_debug("wait_experiment not implemented")
end
