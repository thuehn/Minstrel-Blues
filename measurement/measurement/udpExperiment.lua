
function create_udp_measurement ( runs, packet_sizes, cct_intervals, packet_rates, udp_interval )

    return function ( ap_ref, sta_refs ) 
            local ap_stats = Measurement:create( ap_ref.rpc )
            ap_stats:enable_rc_stats ( ap_ref.stations )
            local stas_stats = {}
            for i,sta_ref in ipairs ( sta_refs ) do
                stas_stats[i] = Measurement:create( sta_ref.rpc )
            end
            local iperf_s_procs = {}
            local iperf_c_pids = {}

            local size = head ( split ( packet_sizes, "," ) )
            for _,interval in ipairs ( split( cct_intervals, ",") ) do

                -- fixme: attenuate
                -- https://github.com/thuehn/Labbrick_Digital_Attenuator

                for _,rate in ipairs ( split ( packet_rates, ",") ) do

                    for run = 1, runs do

                        local key = tostring(rate) .. "-" .. tostring(interval) .. "-" .. tostring(run)

                        -- start udp iperf server on STAs
                        for i, sta_ref in ipairs ( sta_refs ) do
                            local iperf_s_proc_str = sta_ref.rpc.start_udp_iperf_s()
                            iperf_s_procs[i] = parse_process ( iperf_s_proc_str )
                        end
                    
                        ap_ref.rpc.add_monitor( ap_ref.wifis[1] )

                        -- restart wifi on STAs
                        -- add monitor on STAs
                        for i, sta_ref in ipairs ( sta_refs ) do
                            sta_ref.rpc.restart_wifi()
                            sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
                        end

                        for i, sta_ref in ipairs ( sta_refs ) do
                            sta_ref:wait_linked ( sta_ref.wifis[1] )
                        end

                        -- start measurement on AP and STAs
                        ap_stats:start ( ap_ref.wifis[1], key )
                        for i, sta_ref in ipairs ( sta_refs ) do
                            stas_stats[i]:start ( sta_ref.wifis[1], key )
                        end

                        -- -------------------------------------------------------
                        -- Experiment
                        -- -------------------------------------------------------

                        -- start iperf client on AP
                        local wait = false
                        for i, sta_ref in ipairs ( sta_refs ) do
                            iperf_c_pids[i] = ap_ref.rpc.run_udp_iperf( sta_ref:get_addr ( sta_ref.wifis[1] ), size, rate, udp_interval )
                        end
                        -- wait for clients on AP
                        for i, sta_ref in ipairs ( sta_refs ) do
                            ap_ref.rpc.wait_iperf_c( iperf_c_pids[i] )
                        end

                        -- -------------------------------------------------------

                        -- stop measurement on AP and STA
                        ap_stats:stop ()
                        for i, sta_ref in ipairs ( sta_refs ) do
                            stas_stats[i]:stop ()
                        end

                        -- stop iperf server on STAs
                        for i, sta_ref in ipairs ( sta_refs ) do
                            sta_ref.rpc.stop_iperf_server( iperf_s_procs[i]['pid'] )
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

                    end -- run
                end -- rate

                -- fixme: stop attenuate

            end -- cct

            return ap_stats, stas_stats
    end
end

