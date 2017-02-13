
function run_experiment ( exp, ap_ref )
    exp:prepare_measurement ( ap_ref )
    local keys = exp:keys ( ap_ref )

    for _, key in ipairs ( keys ) do

        exp:settle_measurement ( ap_ref, key )
        exp:start_measurement (ap_ref, key )

        -- -------------------------------------------------------
        -- Experiment
        -- -------------------------------------------------------
            
        exp:start_experiment ( ap_ref )
        exp:wait_experiment ( ap_ref )

        -- -------------------------------------------------------

        exp:stop_measurement (ap_ref, key )
        exp:unsettle_measurement ( ap_ref, key )

    end
end
