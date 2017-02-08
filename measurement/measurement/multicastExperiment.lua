
function create_multicast_measurement ( runs, udp_interval )

    return function ( ap_ref, sta_refs )

            local ap_stats = Measurement:create( ap_ref.rpc )
            ap_stats:enable_rc_stats ( ap_ref.stations )
            local stas_stats = {}
            for i,sta_ref in ipairs ( sta_refs ) do
                stas_stats[i] = Measurement:create( sta_ref.rpc )
            end

            local tx_rates = ap_ref.rpc.tx_rate_indices( ap_ref.wifis[1], ap_ref.stations[1] )
            local tx_powers = {}
            for i = 1, 25 do
                tx_powers[1] = i
            end
            local size = "100M"

            for run = 1, runs do

                for _, tx_rate in ipairs ( tx_rates ) do
                    
                    for _, tx_power in ipairs ( tx_powers ) do

                        local key = tostring ( tx_rate ) .. "-" .. tostring ( tx_power ) .. "-" .. tostring(run)

                        ap_ref.rpc.set_tx_rate ( ap_ref.wifis[1], ap_ref.stations[1], tx_rate )
                        ap_ref.rpc.set_tx_power ( ap_ref.wifis[1], ap_ref.stations[1], tx_power )
            
                        -- add monitor on AP
                        ap_ref.rpc.add_monitor( ap_ref.wifis[1] )

                        for i, sta_ref in ipairs ( sta_refs ) do
                            -- restart wifi on STA
                            sta_ref.rpc.restart_wifi()
                            -- fixme: mon0 not created because of too many open files (~650/12505)
                            --   - maybe mon0 already exists
                            sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
                        end

                        -- wait for stations connect
                        for i,sta_ref in ipairs ( sta_refs ) do
                            sta_ref:wait_linked ( sta_ref.wifis[1] )
                        end

                        -- start measurement on AP an STA
                        ap_stats:start ( ap_ref.wifis[1], key )
                        for i,sta_ref in ipairs ( sta_refs ) do
                            stas_stats[i]:start ( sta_ref.wifis[1], key )
                        end

                        -- -------------------------------------------------------
                        -- Experiment
                        -- -------------------------------------------------------
                        local wait = true
                        for i, sta_ref in ipairs ( sta_refs ) do
                            -- start iperf client on AP
                            local addr = "224.0.67.0"
                            local ttl = 32
                            ap_ref.rpc.run_multicast( sta_ref:get_addr ( sta_ref.wifis[1] ), addr, ttl, size, udp_interval, wait )
                        end
                        -- -------------------------------------------------------

                        -- stop measurement on AP an STAs
                        ap_stats:stop ()
                        for i, sta_ref in ipairs ( sta_refs ) do
                            stas_stats[i]:stop ()
                        end

                        -- collect traces
                        ap_stats:fetch ( ap_ref.wifis[1], key )
                        for i, sta_ref in ipairs ( sta_refs ) do
                            stas_stats[i]:fetch ( sta_ref.wifis[1], key )
                        end

                        ap_ref.rpc.remove_monitor ( ap_ref.wifis[1] )
                        -- del monitor on STAs
                        for i, sta_ref in ipairs ( sta_refs ) do
                            sta_ref.rpc.remove_monitor( sta_ref.wifis[1] )
                        end

                    end
                end
            end

            return ap_stats, stas_stats
    end
end

