require ('misc')
local pprint = require ('pprint')
require ('Measurement')
require ('MeasurementOption')

--[[
--  STA: regmon, tcpdump, cpusage
--  AP: regmon, tcpdump, cpusage, rc_stats per station
--]]

Measurements = { rpc_node = nil
               , node_name = nil
               , node_mac = nil
               , node_mac_br = nil
               , opposite_macs = nil
               , opposite_macs_br = nil
               , rc_stats_enabled = nil
               , iperf_s_outs = nil
               , iperf_c_outs = nil
               , stations = nil
               , output_dir = nil
               , online = nil
               , regmon_meas = nil
               , cpusage_meas = nil
               , tcpdump_meas = nil
               , rc_stats_meas = nil
               , mopts = nil
               }

function Measurements:new (o)
    local o = o or {}
    setmetatable ( o, self )
    self.__index = self
    return o
end

function Measurements:create ( name, mac, opposite_macs, rpc, output_dir, online )
    local o = Measurements:new ( { rpc_node = rpc
                                 , node_name = name
                                 , node_mac = mac
                                 , node_mac_br = nil
                                 , opposite_macs = opposite_macs
                                 , opposite_macs_br = nil
                                 , rc_stats_enabled = false
                                 , iperf_s_outs = {}
                                 , iperf_c_outs = {}
                                 , output_dir = output_dir
                                 , online = online
                                 , regmon_meas = {}
                                 , cpusage_meas = {}
                                 , tcpdump_meas = {}
                                 , rc_stats_meas = {}
                                 , mopts = {}
                                 } )

    o.mopts [ "node_name" ] = MeasurementsOption:create ( "node_name", "String", name )
    o.mopts [ "node_mac" ] = MeasurementsOption:create ( "node_mac", "String", mac )
    o.mopts [ "node_mac_br" ] = MeasurementsOption:create ( "node_mac_br", "String", "" )
    o.mopts [ "opposite_macs" ] = MeasurementsOption:create ( "opposite_macs", "List", opposite_macs )
    o.mopts [ "opposite_macs_br" ] = MeasurementsOption:create ( "opposite_macs_br", "List", {} )
    o.mopts [ "online" ] = MeasurementsOption:create ( "online", "String", tostring ( online ) )

    return o
end

function Measurements:set_node_mac_br ( mac_br )
    self.mopts [ "node_mac_br" ] = MeasurementsOption:create ( "node_mac_br", "String", mac_br )
end

function Measurements:set_opposite_macs_br ( macs_br )
    self.mopts [ "opposite_macs_br" ] = MeasurementsOption:create ( "opposite_macs_br", "List", macs_br )
end

function read_stations ( input_dir )
    local fname = input_dir .. "/stations.txt"
    if ( isFile ( fname ) ) then
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            local content  = file:read ( "*a" )
            if ( content ~= nil ) then
                local stations = split ( content, "\n" )
                if ( stations [ #stations ] == "" ) then
                    stations [ #stations ] = nil
                end
                return stations
            end
        end
    end
    return nil
end

function Measurements:add_key ( key, output_dir )

    if ( key == nil ) then
        return false, "Measurement::add_key: key unset"
    end

    if ( output_dir == nil ) then
        return false, "Measurement::add_key: output dir unset"
    end

    local base_dir = output_dir .. "/" .. self.node_name

    local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-regmon_stats.txt"
    self.regmon_meas [ key ] = RegmonMeas:create ( key, fname )

    local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-cpusage_stats.txt"
    self.cpusage_meas [ key ] = CpusageMeas:create ( key, fname )

    local fname = output_dir .. "/" .. self.node_name 
                .. "/" .. self.node_name .. "-" .. key .. ".pcap"
    self.tcpdump_meas [ key ] = TcpdumpPcapsMeas:create ( key, fname )

    if ( self.rc_stats_enabled == true ) then
        local stations = read_stations ( output_dir )
        if ( table_size ( stations ) == 0 ) then
            return false, "Measurement::add_key: rc_stats enabled but no stations linked"
        end
        for _, station in ipairs ( stations ) do
            if ( self.rc_stats_meas == nil ) then
                self.rc_stats_meas = {}
            end
            if ( self.rc_stats_meas [ station ] == nil ) then
                self.rc_stats_meas [ station ] = {}
            end
            if ( key ~= nil ) then
                local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-rc_stats-"
                                       .. station .. ".txt"
                self.rc_stats_meas [ station ] [ key ] = RcStatsMeas:create ( station, key, fname )
            end
        end
    end
    return true, nil
end

function read_keys ( input_dir )
    local fname = input_dir .. "/experiment_order.txt"
    if ( isFile ( fname ) ) then
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            local content = file:read ("*a")
            if ( content ~= nil ) then
                local keys = split ( content, "\n" )
                if ( keys [ #keys ] == "" ) then
                    keys [ #keys ] = nil
                end
                return keys
            end
        end
    end
    return nil
end

function Measurements.parse ( name, input_dir, key, online )

    function init_measurements ( measurements, name, input_dir, key )
        -- load single measurement
        if ( key ~= nil ) then

            local succ, res = measurements:add_key ( key, input_dir )
        
            measurements.iperf_s_outs [ key ] = ""
            measurements.iperf_c_outs [ key ] = ""
        end
    end

    local measurements = Measurements:create ( name, nil, nil, nil, input_dir, online )

    if ( key ~= nil ) then
        init_measurements ( measurements, name, input_dir, key )
        measurements:read ()
    else
        local keys = read_keys ( input_dir )
        if ( keys ~= nil ) then
        for _, key in ipairs ( keys ) do
                init_measurements ( measurements, name, input_dir, key )
            end
        end
        measurements:read ()
    end
    return measurements
end

function Measurements:read ()
    if ( self.output_dir == nil ) then
        return false, "Measurements:read: output dir unset"
    end

    local base_dir = self.output_dir .. "/" .. self.node_name

    -- options
    local succ, res = MeasurementsOption.read_file ( base_dir )
    if ( succ == true ) then self.mopts = res end

    -- regmon stats
    for key, stats in pairs ( self.regmon_meas ) do
        local succ, res = self.add_key ( self, key, self.output_dir )
        if ( succ == false ) then
            return false, "Measurements:read: add_key failed: " .. ( res or "unknown" )
        end
        meas : read ()
    end

    -- cpusage stats
    for key, meas in pairs ( self.cpusage_meas ) do
        meas : read ()
    end

    -- tcpdump pcap
    for key, meas in pairs ( self.tcpdump_meas ) do
        meas : read ()
    end

    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            if ( self.rc_stats_meas ~= nil and self.rc_stats_meas [ station ] ~= nil ) then
                for key, meas in pairs ( self.rc_stats_meas [ station ] ) do
                    meas : read ()
                end
            end
        end
    end

    -- iperf server out
    for key, stats in pairs ( self.iperf_s_outs ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-iperf-server.txt"
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            stats = file:read ( "*a" )
            self.iperf_s_outs [ key ] = stats
            file:close ()
        end
    end

    -- iperf server out
    for key, stats in pairs ( self.iperf_c_outs ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-iperf-client.txt"
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            stats = file:read ( "*a" )
            self.iperf_c_outs [ key ] = stats
            file:close ()
        end
    end

    return true, nil
end

function Measurements:is_open ( key )
    return self.regmon_meas [  key ].online_file ~= nil and self.tcdump_pcap_file ~= nil
end


function Measurements:write ( online, finish, key )
    if ( online == nil ) then online = false end
    if ( finish == nil ) then finish = true end
    if ( self.output_dir == nil ) then self.output_dir = "/tmp" end

    if ( key ~= nil and self.regmon_meas [ key ] == nil ) then
        local succ, res = self.add_key ( self, key, self.output_dir )
        if ( succ == false ) then
            return false, "Measurements:write: " .. ( res or "unknown" )
        end
    end

    local base_dir = self.output_dir .. "/" .. self.node_name

    if ( self:is_open ( key ) == false and isDir ( base_dir ) == false ) then
        local status, err = lfs.mkdir ( base_dir )
        if ( status == false ) then 
            return false, err
        end
    end

    if ( self:is_open ( key ) == false ) then
        -- options
        MeasurementsOption.write_file ( base_dir, self.mopts )

        -- regmon stats
        if ( online == true ) then
            self.regmon_meas [ key ] : open_online ()
        end

        -- cpusage stats
        if ( online == true ) then
            self.cpusage_meas [ key ] : open_online ()
        end

        -- tcpdump pcap
        if ( online == true ) then
            self.tcpdump_meas [ key ] : open_online ()
        end

        -- rc_stats
        if ( online == true ) then
            if ( self.rc_stats_enabled == true ) then
                for _, station in ipairs ( self.stations ) do
                    if ( self.rc_stats_meas ~= nil and self.rc_stats_meas [ station ] ~= nil
                         and self.rc_stats_meas [ station ] [ key ] ~= nil ) then
                        self.rc_stats_meas [ station ] [ key ] : open_online ()
                    end
                end
            end
        end
    end

    -- regmon stats
    self.regmon_meas [ key ] : write ( online )
    if ( finish == true ) then
        self.regmon_meas [ key ]:close_online ()
    end

    -- cpusage stats
    self.cpusage_meas [ key ] : write ( online )
    if ( finish == true ) then
        self.cpusage_meas [ key ]:close_online ()
    end
    
    -- tcpdump pcap
    self.tcpdump_meas [ key ] : write ( online )
    if ( finish == true ) then
        self.tcpdump_meas [ key ]:close_online ()
    end

    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            if ( self.rc_stats_meas ~= nil and self.rc_stats_meas [ station ] ~= nil
                 and self.rc_stats_meas [ station ] [ key ] ~= nil ) then
                --fixme: never reached
                self.rc_stats_meas [ station ] [ key ] : write ( online )
                if ( finish == true ) then
                    self.rc_stats_meas [ station ] [ key ] : close_online ()
                end
            end
        end
    end

    if ( online == false or finish == true ) then
        -- iperf server out
        for key, stats in pairs ( self.iperf_s_outs ) do
            local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-iperf_server.txt"
            local file = io.open ( fname, "w")
            if ( file ~= nil )  then
                file:write ( stats )
                file:close ()
            end
        end

        -- iperf client out
        for key, stats in pairs ( self.iperf_c_outs ) do
            local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-iperf_client.txt"
            local file = io.open ( fname, "w")
            if ( file ~= nil )  then
                file:write ( stats )
                file:close ()
            end
        end
    end

    return true, nil
end

function Measurements:__tostring () 
    local out = "Measurements\n==========\n"
    out = out .. self.node_name .. "\n"
    if ( self.mopts == nil or self.mopts == {} ) then
        out = "no options set"
    else
        local i = 1
        for _, option in pairs ( self.mopts ) do
            if ( i == 1 ) then out = out .. '\n' end
            out = out .. option:__tostring ()
        end
    end
    out = '\n'

    out = out .. ( self.node_mac_br or "no mac (bridged) set" ) .. "\n"
    -- regmon stats
    out = out .. "regmon: " .. table_size ( self.regmon_meas ) .. " stats\n"
    local key
    local stat
    for _, meas in pairs ( self.regmon_meas ) do
        out = out .. meas : __tostring ()
    end
    -- cpusage stats
    out = out .. "cpusage: " .. table_size ( self.cpusage_meas ) .. " stats\n"
    for _, meas in pairs ( self.cpusage_meas ) do
        out = out .. meas : __tostring ()
    end
    -- tcpdump pcap
    -- -- pcap.DLT = { EN10MB=DLT_EN10MB, [DLT_EN10MB] = "EN10MB", ... }
    out = out .. "pcaps: " .. table_size ( self.tcpdump_meas ) .. " stats\n"
    for _, meas in pairs ( self.tcpdump_meas ) do
        out = out .. meas : __tostring ()
    end
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            out = out .. "rc_stats:" .. table_size ( self.rc_stats_meas [ station ] ) .. " stats\n"
            if ( self.rc_stats_meas ~= nil and self.rc_stats_meas [ station ] ~= nil ) then
                for _, meas in pairs ( self.rc_stats_meas [ station ] ) do
                    out = out .. meas : __tostring ()
                end
            end
        end
    end
    -- iperf server out
    for key, stat in pairs ( self.iperf_s_outs ) do
        out = out .. "iperf-server-" .. key .. ": " .. stat .. "\n"
    end
    -- iperf client out
    for key, stat in pairs ( self.iperf_c_outs ) do
        out = out .. "iperf-client-" .. key .. ": " .. stat .. "\n"
    end

    return out 
end

function Measurements:enable_rc_stats ( stations )
    if ( stations == nil or stations == {} ) then
        self.rc_stats_enabled = false
        return
    end
    self.rc_stats_enabled = true
    self.stations = stations
    for _, station in ipairs ( stations ) do
        self.rc_stats_meas [ station ] = {}
        --self.rc_stats [ station ] = {}
    end
end

function Measurements:start ( phy, key )
    local succ, res = self.add_key ( self, key, self.output_dir )
    if ( succ == false ) then
        return false, "Measurements:start add_key failed: " .. ( res or "unknown" ) end
    -- regmon 
    local regmon_pid = self.rpc_node.start_regmon_stats ( phy )
    -- cpusage
    local cpusage_pid = self.rpc_node.start_cpusage ( phy )
    -- tcpdump
    local fname = nil
    if ( self.online == false ) then
        local fname = "/tmp/" .. self.node_name .. "-" .. key .. ".pcap"
        local tcpdump_pid = self.rpc_node.start_tcpdump ( phy, fname )
    else
        local tcpdump_pid = self.rpc_node.start_tcpdump ( phy )
    end
    -- rc stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            local rc_stats_pid = self.rpc_node.start_rc_stats ( phy, station )
        end
    end
    return true, nil
end

function Measurements:stop ( phy, key )
    -- regmon 
    local exit_code = self.rpc_node.stop_regmon_stats ( phy )
    -- cpusage
    local exit_code = self.rpc_node.stop_cpusage ( phy )
    -- tcpdump
    local exit_code = self.rpc_node.stop_tcpdump ( phy )
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            local exit_code = self.rpc_node.stop_rc_stats ( phy, station )
        end
    end
end

function Measurements:fetch ( phy, key, debug_node )

    if ( phy == nil ) then
        return false, "Measurements:fetch failed: phy unset"
    end

    if ( key == nil ) then
        return false, "Measurements:fetch failed: key unset"
    end

    local running = true
    local stats = nil
    -- regmon
    if ( self.regmon_meas [ key ] == nil ) then
        local succ, res = self.add_key ( self, key, self.output_dir )
        if ( succ == false ) then
            return false, "Measurements:fetch add_key failed: " .. ( res or "unknown" )
        end
    end
    debug_node:send_debug ( "fetch: init regmon " .. self.regmon_meas [ key ]:__tostring () )

    stats = self.rpc_node.get_regmon_stats ( phy, self.online )
    if ( stats ~= nil ) then
        if ( debug_node ~= nil ) then
            debug_node:send_debug ( "Measurements:fetch regmon " .. string.len ( stats ) .. " bytes" )
        end
        self.regmon_meas [ key ].stats = ( self.regmon_meas [ key ].stats or "" ) .. stats
        debug_node:send_debug ( "fetch: new regmon " .. self.regmon_meas [ key ]:__tostring () )
    else
        --running = false
    end
    -- cpusage
    stats = self.rpc_node.get_cpusage ( phy, self.online )
    if ( stats ~= nil ) then
        if ( debug_node ~= nil ) then
            debug_node:send_debug ( "Measurements:fetch cpusage " .. string.len ( stats ) .. " bytes" )
        end
        self.cpusage_meas [ key ].stats = ( self.cpusage_meas [ key ].stats or "" ) .. stats
    end
    -- tcpdump
    local fname = nil
    if ( self.online == false ) then
        fname = "/tmp/" .. self.node_name .."-" .. key .. ".pcap"
    end
    stats = self.rpc_node.get_tcpdump ( phy, fname )
    if ( stats ~= nil ) then
        if ( debug_node ~= nil ) then
            debug_node:send_debug ( "Measurements:fetch tcpdump pcaps " .. string.len ( stats ) .. " bytes" )
        end
        self.tcpdump_meas [ key ].stats = ( self.tcpdump_meas [ key ].stats or "" ) .. stats
    else
        running = false
    end
    
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            local stats = self.rpc_node.get_rc_stats ( phy, station, self.online )
            if ( stats ~= nil
                and self.rc_stats_meas ~= nil and self.rc_stats_meas [ station ] ~= nil
                and self.rc_stats_meas [ station ] [ key ] ~= nil ) then
                    if ( debug_node ~= nil ) then
                        debug_node:send_debug ( "Measurements:fetch rc_stats " .. string.len ( stats ) .. " bytes" )
                    end
                    self.rc_stats_meas [ station ] [ key ].stats 
                        = ( self.rc_stats_meas [ station ] [ key ].stats or "" )
                          .. stats
            else
                running = false
            end
        end
    end

    debug_node:send_debug ( "fetched: "
                            .. self.regmon_meas [ key ]:__tostring()
                            .. self.cpusage_meas [ key ]:__tostring()
                            .. self.tcpdump_meas [ key ]:__tostring()
                          )
    return true, running

    -- iperf server out
    -- iperf client out
    -- already done by wait_iperf_c and stop_iperf_s
end

function Measurements:cleanup ( phy, key )
    self.rpc_node.cleanup_cpusage ( phy )
    self.rpc_node.cleanup_regmon ( phy )
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            self.rpc_node.cleanup_rc_stats ( phy, station )
        end
    end
    self.rpc_node.cleanup_tcpdump ( phy )
end

function Measurements.resume ( output_dir, online )
    local keys = nil
    for _, name in ipairs ( ( scandir ( output_dir ) ) ) do
        if ( name ~= "." and name ~= ".."  and isDir ( output_dir .. "/" .. name )
             and Config.find_node ( name, nodes ) ~= nil ) then
            local measurement = Measurements.parse ( name, output_dir, nil, online )
            for key, pcap in pairs ( measurement.tcpdump_meas ) do
                if ( pcap == nil or pcap == "" ) then
                    if ( keys == nil ) then
                        keys = {}
                        keys [1] = {}
                    end
                    if ( Misc.index_of ( key, keys [1] ) == nil ) then
                        keys [1] [ #keys [1] + 1 ] = key
                    end
                end
            end
        end
    end
    return keys
end
