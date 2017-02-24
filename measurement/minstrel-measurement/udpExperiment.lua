
require ('functional') -- head
require ('Experiment')
require ('misc')

UdpExperiment = { runs = nil, packet_sizes = nil, cct_intervals = nil, packet_rates = nil, udp_interval = nil }


function UdpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function UdpExperiment:create ( data )
    local o = UdpExperiment:new( { runs = data[1]
                                 , packet_sizes = data[2]
                                 , cct_intervals = data[3]
                                 , packet_rates = data[4]
                                 , udp_interval = data[5]
                                 } )
    return o
end

function UdpExperiment:keys ( ap_ref )
    local keys = {}
    for _, interval in ipairs ( split( self.cct_intervals, ",") ) do
        -- fixme: attenuate
        -- https://github.com/thuehn/Labbrick_Digital_Attenuator
        for _, rate in ipairs ( split ( self.packet_rates, ",") ) do
            for run = 1, self.runs do
                local key = tostring(rate) .. "-" .. tostring(interval) .. "-" .. tostring(run)
                keys [ #keys + 1 ] = key
            end
        end
    end
    return keys
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
    return (linked and visible)
end

function UdpExperiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
    ap_ref:start_iperf_servers()
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
        ap_ref.rpc.run_udp_iperf( addr, size, rate, self.udp_interval )
    end
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

