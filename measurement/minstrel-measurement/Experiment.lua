
function run_experiment ( exp, ap_ref )
    exp:prepare_measurement ( ap_ref )
    local keys = exp:keys ( ap_ref )

    for _, key in ipairs ( keys ) do

        if ( exp:settle_measurement ( ap_ref, key, 5 ) == false ) then
            break
        end
        exp:start_measurement (ap_ref, key )

        -- -------------------------------------------------------
        -- Experiment
        -- -------------------------------------------------------
            
        exp:start_experiment ( ap_ref, key )
        exp:wait_experiment ( ap_ref )

        -- -------------------------------------------------------

        exp:stop_measurement (ap_ref, key )
        exp:unsettle_measurement ( ap_ref, key )

    end
end
