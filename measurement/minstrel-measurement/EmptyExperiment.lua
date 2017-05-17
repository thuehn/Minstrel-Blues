require ('Experiment')

local posix = require ('posix') -- sleep

-- runs an experiment that do nothing
EmptyExperiment = Experiment:new()

function EmptyExperiment:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function EmptyExperiment:create ( control, data, is_fixed )
    local o = EmptyExperiment:new( { control = control
                                   , runs = data[1]
                                   , tx_powers = data[2]
                                   , tx_rates = data[3]
                                   , is_fixed = is_fixed
                                   } )
    return o
end


function EmptyExperiment:keys ( ap_ref )
    local keys = {}
    for run = 1, self.runs do
        local run_key = tostring ( run )
        keys [ #keys + 1 ] = run_key
    end
    return keys
end

function EmptyExperiment:prepare_measurement ( ap_ref )
end

function EmptyExperiment:settle_measurement ( ap_ref, key )
    --fixme: router reboot when "/sbin/wifi" is executed on AP
    --ap_ref.rpc.restart_wifi()
    --posix.sleep ( 20 )
    ap_ref:restart_wifi ()
end

function EmptyExperiment:unsettle_measurement ( ap_ref, key )
end

function EmptyExperiment:start_measurement ( ap_ref, key )
end

function EmptyExperiment:stop_measurement ( ap_ref, key )
end

function EmptyExperiment:start_experiment ( ap_ref, key )
end

function EmptyExperiment:wait_experiment ( ap_ref )
end

function EmptyExperiment:fetch_measurement ( ap_ref, key )
end
