
--[[
--  STA: regmon, tcpdump, cpusage
--  AP: regmon, tcpdump, cpusage, rc_stats per station
--]]

require ("parsers/ex_process")

Measurement = { rpc_node = nil
              , node_name = nil
              , regmon_stats = nil
              , tcpdump_pcaps = nil
              , cpusage_stats = nil
              , rc_stats = nil
              , rc_stats_enabled = nil
              , regmon_proc = nil
              , tcpdump_proc = nil
              , cpusage_proc = nil
              , rc_stats_procs = nil
              , stations = nil
              }

function Measurement:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Measurement:create ( name, rpc )
    local o = Measurement:new( { rpc_node = rpc
                               , node_name = name
                               , regmon_stats = {}
                               , tcpdump_pcaps = {}
                               , cpusage_stats = {}
                               , rc_stats = {}
                               , rc_stats_enabled = false
                               } )
    return o
end

function Measurement:__tostring() 
    local out = "Measurement\n==========\n"
    -- regmon stats
    out = out .. "regmon: " .. table_size ( self.regmon_stats ) .. " stats\n"
    local key
    local stat
    for key, stat in pairs ( self.regmon_stats ) do
        out = out .. "regmon-" .. key .. ": " .. string.len(stat) .. " bytes\n"
        --print (stat)
    end
    -- cpusage stats
    out = out .. "cpusage: " .. table_size ( self.cpusage_stats ) .. " stats\n"
    for key, stat in pairs ( self.cpusage_stats ) do
        out = out .. "cpusage_stats-" .. key .. ": " .. string.len(stat) .. " bytes\n"
        for _, str in ipairs ( split ( stat, "\n" ) ) do
    --        local cpustat = parse_cpusage ( str )
    --        print (cpustat)
        end
    end
    -- tcpdump pcap
    -- -- pcap.DLT = { EN10MB=DLT_EN10MB, [DLT_EN10MB] = "EN10MB", ... }
    out = out .. "pcaps: " .. table_size ( self.tcpdump_pcaps ) .. " stats\n"
    for key, stats in pairs ( self.tcpdump_pcaps ) do
        out = out .. "tcpdump_pcap-" .. key .. ":\n"
        out = out .. "timestamp, wirelen, #capdata\n"
        local fname = "/tmp/" .. self.node_name .. "-" .. key .. ".pcap"
        local file = io.open(fname, "wb")
        file:write ( stats )
        file:close()
        local cap = pcap.open_offline( fname )
        if (cap ~= nil) then
            -- cap:set_filter(filter, nooptimize)
            local count = 0
            for capdata, timestamp, wirelen in cap.next, cap do
                if (false) then
                    out = out .. tostring(timestamp) .. ", " .. tostring(wirelen) .. ", " .. tostring(#capdata) .. "\n"
                else
                    count = count + 1
                end
            end
            out = out .. tostring(count) .. "\n"
            cap:close()
        else
            print ("Measurement: pcap open failed: " .. fname)
        end
        os.remove ( fname )
    end
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            out = out .. "rc_stats:" .. table_size ( self.rc_stats [ station ] ) .. " stats\n"
            if ( self.rc_stats ~= nil and self.rc_stats [ station ] ~= nil) then
                for key, stat in pairs ( self.rc_stats [ station ] ) do
                    out = out .. "rc_stats-" .. station .. "-" .. key .. ": " .. string.len(stat) .. " bytes\n"
                    -- if (stat ~= nil) then print (stat) end
                end
            end
        end
    end

    return out 
end

function Measurement:enable_rc_stats ( stations )
    if ( stations == nil or stations == {} ) then
        error ( "stations unset" )
    end
    self.rc_stats_enabled = true
    self.stations = stations
    for _, station in ipairs ( stations ) do
        self.rc_stats [ station ] = {}
    end
end

function Measurement:start ( phy, key )
    local str
    -- regmon 
    str = self.rpc_node.start_regmon_stats ( phy )
    if ( str ~= nil ) then
        self.regmon_proc = parse_process ( str )
    end
    -- cpusage
    str = self.rpc_node.start_cpusage()
    if ( str ~= nil ) then
        self.cpusage_proc = parse_process ( str )
    end
    -- tcpdump
    local tcpdump_fname = "/tmp/" .. self.node_name .. "-" .. key .. ".pcap"
    str = self.rpc_node.start_tcpdump( phy, tcpdump_fname )
    if ( str == nil ) then
        return false
    end
    self.tcpdump_proc = parse_process ( str )
    -- rc stats
    self.rc_stats_procs = {}
    if ( self.rc_stats_enabled == true ) then
        local rc_stats_procs = self.rpc_node.start_rc_stats ( phy, self.stations )
        local rc_procs = {}
        for _, rc_proc_str in ipairs ( rc_stats_procs ) do
            self.rc_stats_procs [ #self.rc_stats_procs + 1 ] = parse_process ( rc_proc_str )
        end
    end
    return true
end

function Measurement:stop ()
    -- regmon 
    if ( self.regmon_proc ~= nil) then
        local exit_code = self.rpc_node.stop_regmon_stats( self.regmon_proc['pid'] )
    end
    -- cpusage
    if ( self.cpusage_proc ~= nil) then
        local exit_code = self.rpc_node.stop_cpusage( self.cpusage_proc['pid'] )
    end
    -- tcpdump
    if ( self.tcpdump_proc ~= nil ) then
        local exit_code = self.rpc_node.stop_tcpdump( self.tcpdump_proc['pid'] )
    end
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for i, rc_proc in ipairs ( self.rc_stats_procs ) do
            if ( rc_proc ~= nil ) then
                local exit_code = self.rpc_node.stop_rc_stats( rc_proc['pid'], self.stations[i] )
            end
        end
    end
end

function Measurement:fetch ( phy, key )
    -- regmon
    self.regmon_stats [ key ] = self.rpc_node.get_regmon_stats()
    -- cpusage
    self.cpusage_stats [ key ] = self.rpc_node.get_cpusage()
    -- tcpdump
    local tcpdump_fname = "/tmp/" .. self.node_name .."-" .. key .. ".pcap"
    self.tcpdump_pcaps[ key ] = self.rpc_node.get_tcpdump_offline ( tcpdump_fname )
    
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            local stats = self.rpc_node.get_rc_stats ( phy, station )
            self.rc_stats [ station ] [ key ] = stats 
        end
    end
end
