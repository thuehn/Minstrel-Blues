Measurement = { name = nil
              , key = nil
              , stats = nil
              , fname = nil
              , binary_mode = nil
              , online_file = nil
              }

function Measurement:new ( o )
    local o = o or { stats = ""
                   , binary_mode = false
                   }
    setmetatable ( o, self )
    self.__index = self
    return o
end

function Measurement:read ()
    if ( self.fname ~= nil and self.key ~= nil ) then
        local file_mode = "r"
        if ( self.binary_mode == true ) then
            file_mode = file_mode .. "b"
        end
        local file = io.open ( iself.fname, file_mode )
        if ( file ~= nil ) then
            stats = file:read ( "*a" )
            self.stats = stats
            file:close ()
        else
            self.stats = ""
        end
    end
end

function Measurement:open_online ()
    local file_mode = "w"
    if ( self.binary_mode == true ) then
        file_mode = file_mode .. "b"
    end
    self.online_file = io.open ( self.fname, file_mode )
end

function Measurement:close_online ()
    if ( self.online_file ~= nil ) then
        self.online_file:close ()
    end
end

function Measurement:write ( online )
    if ( online == false ) then
        local file = io.open ( self.fname, "w" )
        file:write ( self.stats )
        file:close ()
    else
        self.online_file:write ( self.stats or "" )
    end
end

function Measurement:__tostring ()
    local len = 0
    if ( self.stats ~= nil ) then
        len = string.len ( self.stats )
    end
    local out = ( self.name or "none" )
                .. "-" .. ( self.key or "none" )
                .. ": " .. len .. " bytes\n"
    return out
end

-- regmon_stats

RegmonMeas = Measurement:new ()

function RegmonMeas:create ( key, fname )
    local o = RegmonMeas:new ( { name = "regon_stats"
                               , key = key
                               , fname = fname
                               } )
    return o
end

-- cpusage_stats

CpusageMeas = Measurement:new ()

function CpusageMeas:create ( key, fname )
    local o = CpusageMeas:new ( { name = "cpusage_stats"
                                , key = key
                                , fname = fname
                                } )
    return o
end

-- rc_stats

RcStatsMeas = Measurement:new ()

function RcStatsMeas:create ( station, key, fname )
    local o = RcStatsMeas:new ( { name = "rc_stats-" .. station
                                , key = key
                                , fname = fname
                                } )
    return o
end

-- tcpdump_pcaps

TcpdumpPcapsMeas = Measurement:new ()

function TcpdumpPcapsMeas:create ( key, fname )
    local o = TcpdumpPcapsMeas:new ( { name = "tcpdump_pcaps"
                                     , key = key
                                     , fname = fname
                                     , binary_mode = false --fixme: true not tested
                                     } )
    return o
end
