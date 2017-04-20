require ('Experiment')

local posix = require ('posix') -- sleep

-- runs an multicast experiment with fixed rate and fixed power setting
McastExperiment = Experiment:new()

function McastExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function McastExperiment:create ( control, data, is_fixed )
    local o = McastExperiment:new( { control = control
                                   , runs = data[1]
                                   , tx_powers = data[2]
                                   , tx_rates = data[3]
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
            --fixme: sort keys by rpc.tx_rate_indices
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
        self.control:send_debug ( "run multicast experiment for rates " .. table_tostring ( self.tx_rates ) )
        self.control:send_debug ( "run multicast experiment for powers " .. table_tostring ( self.tx_powers ) )
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

function McastExperiment:settle_measurement ( ap_ref, key, retrys )
    if ( self.is_fixed == true ) then
        local tx_rate = self:get_rate ( key )
        ap_ref.rpc.set_global_tx_rate ( ap_ref.wifi_cur, tx_rate )
        local tx_rate_new = ap_ref.rpc.get_global_tx_rate ( ap_ref.wifi_cur )
        if ( tx_rate_new ~= tx_rate ) then
            self.control:send_error ( "global rate not set correctly: should be " .. tx_rate
                                      .. " (set) but is " .. ( tx_rate_new or "unset" ) .. " (actual)" )
        end
    end
    if ( self.is_fixed == true ) then
        local tx_power = self:get_power ( key )
        ap_ref.rpc.set_global_tx_power ( ap_ref.wifi_cur, tx_power )
        local tx_power_new = ap_ref.rpc.get_global_tx_power ( ap_ref.wifi_cur )
        if ( tx_power_new ~= tx_power ) then
            self.control:send_error ( "global tx power not set correctly: should be " .. tx_power
                                      .. " (set) but is " .. ( tx_power_new or "unset" ) .. " (actual)" )
        end
    end
    --fixme: router reboot when "/sbin/wifi" is executed on AP
    --ap_ref.rpc.restart_wifi()
    --posix.sleep( 10 )
    ap_ref:restart_wifi ()
    self.control:send_info ("wifi restarted")
    self.control:send_info ("wait station")
    local visible = ap_ref:wait_station ( retrys )
    self.control:send_info ("wait linked")
    local linked = ap_ref:wait_linked ( retrys )
    ap_ref:add_monitor ()
    return (linked and visible)
end

function McastExperiment:start_measurement ( ap_ref, key )
    return ap_ref:start_measurement ( key )
end

function McastExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_measurement ( key )
end

function McastExperiment:start_experiment ( ap_ref, key )
    local wait = false
    local ap_wifi_addr = ap_ref:get_addr ( ap_ref.wifi_cur )

    -- start iperf client on AP
    local addr = "224.0.67.0"
    local ttl = 1
    local size = "1M"
    local wifi_addr = ap_ref:get_addr ( ap_ref.wifi_cur )
    local phy_num = tonumber ( string.sub ( ap_ref.wifi_cur, 4 ) )
    local iperf_port = 12000 + phy_num

    self.control:send_debug ( "run multicast udp client with multicast addr " 
                               .. ( addr or "unset" )
                               .. " local addr " .. ( wifi_addr or "unset" ) )

    ap_ref.rpc.run_multicast ( ap_ref.wifi_cur, iperf_port, wifi_addr, addr, ttl, size, self.udp_interval, wait )
end

function McastExperiment:wait_experiment ( ap_ref, key )
    -- wait for client on AP
    local wifi_addr = ap_ref:get_addr ( ap_ref.wifi_cur )
    local _, out = ap_ref.rpc.wait_iperf_c ( ap_ref.wifi_cur, wifi_addr )
    ap_ref.stats.iperf_c_outs [ key ] = out
end
