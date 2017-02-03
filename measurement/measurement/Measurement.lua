
--[[
--  STA: regmon, tcpdump, cpusage
--  AP: regmon, tcpdump, cpusage, rc_stats per station
--]]

require ("parsers/ex_process")

Measurement = { rpc_node = nil
              , regmon_stats = {}
              , tcpdump_pcaps = {}
              , cpusage_stats = {}
              , rc_stats = {}
              , enable_rc_stats = false
              , regmon_proc = nil
              , tcpdump_proc = nil
              , cpusage_proc = nil
              , rc_stats_procs = {}
              , stations = nil
              }

function Measurement:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Measurement:create ( rpc_node )
    if (rpc_node == nil) then error ( "rpc node unset" ) end
    o = Measurement:new( { rpc_node = rpc_node } )
    return o
end

function Measurement:__tostring() 
    local out = ""
    -- regmon stats
    -- print ( tostring ( table_size ( regmon_stats ) ) )
    for key, stat in pairs ( self.regmon_stats ) do
        out = out .. "regmon-" .. key .. ": " .. string.len(stat) .. " bytes\n"
        --print (stat)
    end
    -- cpusage stats
    for key, stat in pairs ( self.cpusage_stats ) do
        out = out .. "cpusage_stats-" .. key .. ": " .. string.len(stat) .. " bytes\n"
        for _, str in ipairs ( split ( stat, "\n" ) ) do
    --        local cpustat = parse_cpusage ( str )
    --        print (cpustat)
        end
    end
    -- tcpdump pcap
    for key, stats in pairs ( self.tcpdump_pcaps ) do
        out = out .. "tcpdump_pcap-" .. key .. ":\n"
        out = out .. "timestamp, wirelen, #capdata" .. key .. ":\n"
        local fname = "/tmp/" .. key .. ".pcap"
        local file = io.open(fname, "wb")
        file:write ( stats )
        file:close()
        local cap = pcap.open_offline( fname )
        if (cap ~= nil) then
            -- cap:set_filter(filter, nooptimize)

            for capdata, timestamp, wirelen in cap.next, cap do
                out = out .. tostring(timestamp) .. ", " .. tostring(wirelen) .. ", " .. tostring(#capdata) .. "\n"
            end
    
            cap:close()
        else
            print ("pcap open failed: " .. fname)
        end
    end
    -- rc_stats
    if ( self.enable_rc_stats ) then
        for _, station in ipairs ( self.stations ) do
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
    if ( stations == nil ) then
        error ( "stations unset" )
    end
    self.enable_rc_stats = true
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
    local tcpdump_fname = "/tmp/" .. key .. ".pcap"
    str = self.rpc_node.start_tcpdump( tcpdump_fname )
    self.tcpdump_proc = parse_process ( str )
    -- rc stats
    if ( self.enable_rc_stats ) then
        local rc_stats_procs = self.rpc_node.start_rc_stats ( phy )
        local rc_procs = {}
        for _, rc_proc_str in ipairs ( rc_stats_procs ) do
            self.rc_stats_procs [ #self.rc_stats_procs + 1 ] = parse_process ( rc_proc_str )
        end
    end
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
    if ( self.enable_rc_stats ) then
        for _, rc_proc in ipairs ( self.rc_stats_procs ) do
            if ( rc_proc ~= nil ) then
                local exit_code = self.rpc_node.stop_rc_stats( rc_proc['pid'] )
            end
        end
    end
end

function Measurement:fetch ( key )
    -- regmon
    self.regmon_stats [ key ] = self.rpc_node.get_regmon_stats()
    -- cpusage
    self.cpusage_stats [ key ] = self.rpc_node.get_cpusage()
    -- tcpdump
    local tcpdump_fname = "/tmp/" .. key .. ".pcap"
    self.tcpdump_pcaps[ key ] = self.rpc_node.get_tcpdump_offline ( tcpdump_fname )
    
    -- rc_stats
    if ( self.enable_rc_stats ) then
        for _, station in ipairs ( self.stations ) do
            self.rc_stats [ station ] [ key ] = self.rpc_node.get_rc_stats ( station )
        end
    end
end
