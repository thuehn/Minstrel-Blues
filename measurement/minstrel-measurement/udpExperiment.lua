
require ('Experiment')

local pprint = require ('pprint')

UdpExperiment = Experiment:new()

function UdpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function UdpExperiment:create ( control, data, is_fixed )
    local o = UdpExperiment:new( { control = control
                                 , runs = data [1]
                                 , tx_powers = data [2]
                                 , tx_rates = data [3]
                                 , packet_rates = data [4]
                                 , durations = data [5]
                                 , is_fixed = is_fixed
                                 } )
    return o
end

function UdpExperiment:keys ( ap_ref )
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
        self.control:send_debug( "run udp experiment for rates " .. table_tostring ( self.tx_rates, 80 ) )
        self.control:send_debug( "run udp experiment for powers " .. table_tostring ( self.tx_powers, 80 ) )
    end

    -- fixme: attenuate
    -- https://github.com/thuehn/Labbrick_Digital_Attenuator

    for run = 1, self.runs do
        local run_key = tostring ( run )
        if ( self.is_fixed == true and ( self.tx_rates ~= nil and self.tx_powers ~= nil ) ) then
            for _, tx_rate in ipairs ( self.tx_rates ) do
                local txrate_key = tostring ( tx_rate )
                for _, tx_power in ipairs ( self.tx_powers ) do
                    local power_key = tostring ( tx_power )
                    for _, duration in ipairs ( split ( self.durations, "," ) ) do
                        local duration_key = tostring ( duration )
                        for _, rate in ipairs ( split ( self.packet_rates, "," ) ) do
                            local rate_key = tostring ( rate )
                            keys [ #keys + 1 ] = txrate_key .. "-" .. power_key 
                                                 .. "-" .. duration_key .. "-"  .. rate_key .. "-" .. run_key
                        end
                    end
                end
            end
        else
            for _, duration in ipairs ( split( self.durations, ",") ) do
                local duration_key = tostring ( duration )
                for _, rate in ipairs ( split ( self.packet_rates, ",") ) do
                    local rate_key = tostring ( rate )
                    keys [ #keys + 1 ] = duration_key .. "-" .. rate_key .. "-" .. run_key
                end
            end
        end
    end

    return keys
end

function UdpExperiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
    local tcp = false
    ap_ref:start_iperf_servers ( tcp )
end

function UdpExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_iperf_servers()
    ap_ref:stop_measurement ( key )
end

function UdpExperiment:start_experiment ( ap_ref, key )
    -- start iperf client on AP
    local wait = false
    local keys = split ( key, "-" )
    local duration = keys [3]
    local rate = keys [4]
    for i, sta_ref in ipairs ( ap_ref.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            local addr = sta_ref:get_addr ()
            ap_ref.rpc.run_udp_iperf ( addr, rate, duration, wait )
        end
    end
    return true
end

function UdpExperiment:wait_experiment ( ap_ref )
    -- wait for clients on AP
    for i, sta_ref in ipairs ( ap_ref.refs ) do
        if ( sta_ref.is_passive == nil or sta_ref.is_passive == false ) then
            local addr = sta_ref:get_addr ()
            ap_ref.rpc.wait_iperf_c ( addr )
        end
    end
end
