
function create_tcp_measurement ( runs, tcpdata )
    
    return function ( ap_ref, sta_refs ) 
            local ap_stats = Measurement:create( ap_ref.rpc )
            ap_stats:enable_rc_stats ( ap_ref.stations )
            local stas_stats = {}
            for i,sta_ref in ipairs ( sta_refs ) do
                stas_stats[i] = Measurement:create( sta_ref.rpc )
            end
            local iperf_s_procs = {}
            local iperf_c_pids = {}

            for run = 1, runs do

                local key = tostring ( run )

                -- start tcp iperf server on STAs
                for i, sta_ref in ipairs ( sta_refs ) do
                    local iperf_s_proc_str = sta_ref.rpc.start_tcp_iperf_s()
                    iperf_s_procs[i] = parse_process ( iperf_s_proc_str )
                end

                ap_ref.rpc.add_monitor( ap_ref.wifis[1] )

                -- restart wifi on STAs
                -- add monitor on STAs
                for i, sta_ref in ipairs ( sta_refs ) do
                    sta_ref.rpc.restart_wifi()
                    -- fixme: mon0 not created because of too many open files (~650/12505)
                    sta_ref.rpc.add_monitor( sta_ref.wifis[1] )
                end

                for i, sta_ref in ipairs ( sta_refs ) do
                    sta_ref:wait_linked ( sta_ref.wifis[1] )
                end

                -- start measurement on STAs and AP
                ap_stats:start ( ap_ref.wifis[1], key )
                for i, sta_ref in ipairs ( sta_refs ) do
                    stas_stats[i]:start ( sta_ref.wifis[1], key )
                end

                -- -------------------------------------------------------
                -- Experiment
                -- -------------------------------------------------------
                
                -- start iperf clients on AP
                for i, sta_ref in ipairs ( sta_refs ) do
                    local wait = false
                    local pid = ap_ref.rpc.run_tcp_iperf( sta_ref:get_addr ( sta_ref.wifis[1] ), tcpdata, wait )
                    iperf_c_pids[i] = pid 
                end
                -- wait for clients on AP
                for i, sta_ref in ipairs ( sta_refs ) do
                    ap_ref.rpc.wait_iperf_c( iperf_c_pids[i] )
                end
                -- -------------------------------------------------------

                -- stop measurement on STAs and AP
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

            end

            return ap_stats, stas_stats
    end
end
