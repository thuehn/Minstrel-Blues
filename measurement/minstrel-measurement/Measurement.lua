require ('misc')

--[[
--  STA: regmon, tcpdump, cpusage
--  AP: regmon, tcpdump, cpusage, rc_stats per station
--]]

-- TODO: don't overwrite old measuremnt data

pprint = require('pprint')

Measurement = { rpc_node = nil
              , node_name = nil
              , regmon_stats = nil
              , tcpdump_pcaps = nil
              , cpusage_stats = nil
              , rc_stats = nil
              , rc_stats_enabled = nil
              , stations = nil
              , output_dir = nil
              }

function Measurement:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Measurement:create ( name, rpc, output_dir )
    local o = Measurement:new( { rpc_node = rpc
                               , node_name = name
                               , regmon_stats = {}
                               , tcpdump_pcaps = {}
                               , cpusage_stats = {}
                               , rc_stats = {}
                               , rc_stats_enabled = false
                               , output_dir = output_dir
                               } )
    return o
end

function Measurement:read ()
    if ( self.output_dir == nil ) then
        return false, "output dir unset"
    end

    local base_dir = self.output_dir .. "/" .. self.node_name

    -- regmon stats
    for key, stats in pairs ( self.regmon_stats ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-regmon_stats.txt"
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            stats = file:read ( "*a" )
            self.regmon_stats [ key ] = stats
            file:close ()
        end
    end

    -- cpusage stats
    for key, stats in pairs ( self.cpusage_stats ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-cpusage_stats.txt"
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            stats = file:read ( "*a" )
            self.cpusage_stats [ key ] = stats
            file:close ()
        end
    end

    -- tcpdump pcap
    for key, stats in pairs ( self.tcpdump_pcaps ) do
        local fname = self.output_dir .. "/" .. self.node_name 
                    .. "/" .. self.node_name .. "-" .. key .. ".pcap"
        local file = io.open(fname, "rb")
        if ( file ~= nil ) then
            stats = file:read ("*a")
            self.tcpdump_pcaps [ key ] = stats
            file:close()
        end
    end

    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            if ( self.rc_stats ~= nil and self.rc_stats [ station ] ~= nil ) then
                for key, stats in pairs ( self.rc_stats [ station ] ) do
                    local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-rc_stats-"
                            .. station .. ".txt"
                    local file = io.open(fname, "r")
                    if ( file ~= nil ) then
                        stats = file:read ( "*a" )
                        self.rc_stats [ station ] [ key ] = stats
                        file:close ()
                    end
                end
            end
        end
    end

    return true, nil
end

function Measurement:write ()
    if ( self.output_dir == nil ) then
        return false, "output dir unset"
    end

    local base_dir = self.output_dir .. "/" .. self.node_name

    local status, err = lfs.mkdir ( base_dir )
    if ( status == false ) then 
        return false, err
    end

    -- regmon stats
    for key, stats in pairs ( self.regmon_stats ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-regmon_stats.txt"
        local file = io.open ( fname, "w" )
        file:write ( stats )
        file:close ()
    end

    -- cpusage stats
    for key, stats in pairs ( self.cpusage_stats ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key  .. "-cpusage_stats.txt"
        local file = io.open ( fname, "w" )
        file:write ( stats )
        file:close ()
    end
    
    -- tcpdump pcap
    for key, stats in pairs ( self.tcpdump_pcaps ) do
        local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. ".pcap"
        local file = io.open ( fname, "w")
        if ( file ~= nil )  then
            file:write ( stats )
            file:close()
        end
    end
    
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            if ( self.rc_stats ~= nil and self.rc_stats [ station ] ~= nil ) then
                for key, stats in pairs ( self.rc_stats [ station ] ) do
                    local fname = base_dir .. "/" .. self.node_name .. "-" .. key .. "-rc_stats-"
                            .. station .. ".txt"
                    local file = io.open ( fname, "w" )
                    file:write ( stats )
                    file:close ()
                end
            end
        end
    end
    return true
end

function Measurement:__tostring () 
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
    end
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            out = out .. "rc_stats:" .. table_size ( self.rc_stats [ station ] ) .. " stats\n"
            if ( self.rc_stats ~= nil and self.rc_stats [ station ] ~= nil) then
                for key, stat in pairs ( self.rc_stats [ station ] ) do
                    out = out .. "rc_stats-" .. station .. "-" .. key .. ": " .. string.len ( stat ) .. " bytes\n"
                    -- if (stat ~= nil) then print (stat) end
                end
            end
        end
    end

    return out 
end

function Measurement:enable_rc_stats ( stations )
    if ( stations == nil or stations == {} ) then
        self.rc_stats_enabled = false
        return
    end
    self.rc_stats_enabled = true
    self.stations = stations
    for _, station in ipairs ( stations ) do
        self.rc_stats [ station ] = {}
    end
end

function Measurement:start ( phy, key )
    -- regmon 
    local regmon_pid = self.rpc_node.start_regmon_stats ( phy )
    -- cpusage
    local cpusage_pid = self.rpc_node.start_cpusage()
    -- tcpdump
    local tcpdump_fname = "/tmp/" .. self.node_name .. "-" .. key .. ".pcap"
    local tcpdump_pid = self.rpc_node.start_tcpdump ( phy, tcpdump_fname )
    -- rc stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            local rc_stats_pid = self.rpc_node.start_rc_stats ( phy, station )
        end
    end
    return true
end

function Measurement:stop ()
    -- regmon 
    local exit_code = self.rpc_node.stop_regmon_stats ()
    -- cpusage
    local exit_code = self.rpc_node.stop_cpusage ()
    -- tcpdump
    local exit_code = self.rpc_node.stop_tcpdump ()
    -- rc_stats
    if ( self.rc_stats_enabled == true ) then
        for _, station in ipairs ( self.stations ) do
            local exit_code = self.rpc_node.stop_rc_stats ( station )
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
