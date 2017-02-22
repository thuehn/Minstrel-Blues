require ('Experiment')

TcpExperiment = { runs = nil, tcpdata = nil }


function TcpExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function TcpExperiment:create ( data )
    local o = TcpExperiment:new( { runs = data[1], tcpdata = data[2] } )
    return o
end

function TcpExperiment:keys ( ap_ref )
    local keys = {}
    for run = 1, self.runs do
        keys [ #keys + 1 ] = tostring ( run )
    end
    return keys
end


function TcpExperiment:prepare_measurement ( ap_ref )
    ap_ref:create_measurement()
    ap_ref.stats:enable_rc_stats ( ap_ref.stations )
end

function TcpExperiment:settle_measurement ( ap_ref, key, retrys )
    ap_ref:restart_wifi ()
    ap_ref:add_monitor ()
    return ap_ref:wait_linked ( retrys )
end

function TcpExperiment:start_measurement ( ap_ref, key )
    ap_ref:start_measurement ( key )
    ap_ref:start_iperf_servers()
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
        ap_ref.rpc.run_tcp_iperf( addr, self.tcpdata, wait )
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
        ap_ref.rpc.wait_iperf_c( addr )
    end
end

function create_tcp_measurement ( runs, tcpdata )
    local tcp_exp = TcpExperiment:create( runs, tcpdata )
    return function ( ap_ref ) return run_experiment ( tcp_exp, ap_ref ) end
end
