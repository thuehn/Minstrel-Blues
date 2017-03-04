
require ('functional') -- head
require ('Experiment')
require ('misc')

UdpExperiment = { control = control, runs = nil, tx_powers = nil, tx_rates = nil,
                  packet_sizes = nil, cct_intervals = nil, packet_rates = nil, udp_interval = nil }


function UdpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function UdpExperiment:create ( data )
    local o = UdpExperiment:new( { control = control
                                 , runs = data[1]
                                 , tx_powers = data[2]
                                 , tx_rates = data[3]
                                 , packet_sizes = data[4]
                                 , cct_intervals = data[5]
                                 , packet_rates = data[6]
                                 , udp_interval = data[7]
                                 } )
    return o
end

function UdpExperiment:keys ( ap_ref )
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
    self.control:send_debug( "run udp experiment for rates " .. table_tostring ( self.tx_rates ) )
    self.control:send_debug( "run udp experiment for powers " .. table_tostring ( self.tx_powers ) )

    -- fixme: attenuate
    -- https://github.com/thuehn/Labbrick_Digital_Attenuator
    for run = 1, self.runs do
        for _, tx_rate in ipairs ( self.tx_rates ) do
            for _, tx_power in ipairs ( self.tx_powers ) do
                for _, interval in ipairs ( split( self.cct_intervals, ",") ) do
                    for _, rate in ipairs ( split ( self.packet_rates, ",") ) do
                        local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) 
                                    .. "-" .. tostring(rate) .. "-" .. tostring(interval)
                                    .. "-" .. tostring( run )
                        keys [ #keys + 1 ] = key
                    end
                end
            end
        end
    end

    return keys
end

function UdpExperiment:get_rate( key )
    return split ( key, "-" ) [1]
end

function UdpExperiment:get_power( key )
    return split ( key, "-" ) [2]
end

function UdpExperiment:prepare_measurement ( ap_ref )
    ap_ref:create_measurement()
    ap_ref.stats:enable_rc_stats ( ap_ref.stations )
end

function UdpExperiment:settle_measurement ( ap_ref, key, retrys )
    ap_ref:restart_wifi ()
    local linked = ap_ref:wait_linked ( retrys )
    local visible = ap_ref:wait_station ( retrys )
    ap_ref:add_monitor ()
    ap_ref:set_tx_power ( self:get_power ( key ) )
    ap_ref:set_tx_rate ( self:get_rate ( key ) )
    return (linked and visible)
end

function UdpExperiment:start_measurement ( ap_ref, key )
    local started = ap_ref:start_measurement ( key )
    ap_ref:start_iperf_servers()
    return started
end

function UdpExperiment:stop_measurement ( ap_ref, key )
    ap_ref:stop_iperf_servers()
    ap_ref:stop_measurement ( key )
end

function UdpExperiment:unsettle_measurement ( ap_ref, key )
    ap_ref:remove_monitor ()
end

function UdpExperiment:start_experiment ( ap_ref, key )
    -- start iperf client on AP
    local wait = false
    local size = head ( split ( self.packet_sizes, "," ) )
    local rate = split ( key, "-") [1]
    for i, sta_ref in ipairs ( ap_ref.refs ) do
        local addr = sta_ref:get_addr ()
        if ( ap_ref.rpc.run_udp_iperf( addr, size, rate, self.udp_interval ) == nil ) then
            return false
        end
    end
    return true
end

function UdpExperiment:wait_experiment ( ap_ref )
    -- wait for clients on AP
    for i, sta_ref in ipairs ( ap_ref.refs ) do
        local addr = sta_ref:get_addr ()
        ap_ref.rpc.wait_iperf_c( addr )
    end
end

function create_udp_measurement ( runs, packet_sizes, cct_intervals, packet_rates, udp_interval )
    local udp_exp = UdpExperiment:create( runs, packet_sizes, cct_intervals, packet_rates, udp_interval )
    return function ( ap_ref ) return run_experiment ( udp_exp, ap_ref ) end
end

