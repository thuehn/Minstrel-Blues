require ('misc')

--[[
              best   ____________rate__________    ________statistics________    ________last_______    ______sum-of________
mode guard #  rate  [name   idx airtime  max_tp]  [avg(tp) avg(prob) sd(prob)]  [prob.|retry|suc|att]  [#success | #attempts]
CCK    LP  1 A   P    1.0M  120   10548     0.7       0.7     100.0      0.0     100.0   2     1 1            13   13       
CCK    SP  1          2.0M  125    5380     1.5       0.0       0.0      0.0       0.0   0     0 0             0   0        
CCK    SP  1          5.5M  126    2315     3.8       0.0       0.0      0.0       0.0   0     0 0             0   0        
CCK    SP  1         11.0M  127    1439     6.1       0.0       0.0      0.0       0.0   0     0 0             0   0        
HT20  LGI  1   BCD   MCS0     0    1477     5.6       0.0       0.0      0.0       0.0   1     0 0             0   0        
--]]

-- rc_stats_cvs: 7,3,1.0 left

RcRate = { name = nil
         , idx = nil
         , airtime = nil
         , max_tp = nil
         }

function RcRate:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcRate:create ( name, idx, airtime, max_tp )
    local o = RcRate:new( { name = name
                          , idx = idx
                          , airtime = airtime
                          , max_tp = max_tp
                          } )
    return o
end

function RcRate:__tostring() 
    local out = ""
    out = out .. "name: " .. (self.name or "") .. " "
    out = out .. "idx: " .. (self.idx or "") .. " "
    out = out .. "airtime: " .. (self.airtime or "") .. " "
    out = out .. "max_tp: " .. (self.max_tp or "") .. " "
    return out
end

RcStats = { avg_tp = nil
          , avg_prob = nil
          , sd_prob = nil
          }

function RcStats:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcStats:create ( avg_tp, avg_prob, sd_prob )
    local o = RcStats:new( { avg_tp = avg_tp
                           , avg_prob = avg_prob
                           , sd_prob = sd_prob
                           } )
    return o
end

function RcStats:__tostring() 
    local out = ""
    out = out .. "avg(tp): " .. (self.avg_tp or "") .. " "
    out = out .. "avg(prob): " .. (self.avg_prob or "") .. " "
    out = out .. "sd(prob): " .. (self.sd_prob or "") .. " "
    return out
end

RcLast = { prob = nil
         , retry = nil
         , suc = nil
         , att = nil
         }

function RcLast:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcLast:create ( prob, retry, suc, att )
    local o = RcLast:new( { prob = prob
                          , retry = retry
                          , suc = suc
                          , att = att
                          } )
    return o
end

function RcLast:__tostring() 
    local out = ""
    out = out .. "prob: " .. (self.prob or "") .. " "
    out = out .. "retry: " .. (self.retry or "") .. " "
    out = out .. "suc: " .. (self.suc or "") .. " "
    out = out .. "att: " .. (self.att or "") .. " "
    return out
end

RcSumOf = { num_success = nil
          , num_attemps = nil
          }

function RcSumOf:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcSumOf:create ( num_success, num_attemps )
    local o = RcSumOf:new( { num_success = num_success
                           , num_attemps = num_attemps
                           } )
    return o
end

function RcSumOf:__tostring() 
    local out = ""
    out = out .. "#success: " .. (self.num_success or "") .. " "
    out = out .. "#attemps: " .. (self.num_attemps or "") .. " "
    return out
end

RcStatsCsv = { mode = nil
             , guard = nil
             , count = nil
             , best_rate = nil 
             , rate = nil
             , stats = nil
             , last = nil
             , sum_of = nil
             }

function RcStatsCsv:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcStatsCsv:create ( ts, mode, guard, count, best_rate, rate, stats, last, sum_of )
    local o = RcStatsCsv:new( { ts = ts
                              , mode = mode
                              , guard = guard
                              , count = count
                              , best_rate = best_rate 
                              , rate = rate
                              , stats = stats
                              , last = last
                              , sum_of = sum_of
                              } )
    return o
end

function RcStatsCsv:__tostring() 
    local rate = ""
    local stats = ""
    local last = ""
    local sum_of = ""

    if ( self.rate ~= nil ) then rate = self.rate:__tostring() else rate = "" end
    if ( self.stats ~= nil ) then stats = self.stats:__tostring() else stats = "" end
    if ( self.last ~= nil ) then last = self.last:__tostring() else last = "" end
    if ( self.sum_of ~= nil ) then sum_of = self.sum_of:__tostring() else sum_of = "" end

    local out = ""
    out = out .. "timestamp: " .. (self.ts or "") .. " "
    out = out .. "mode: " .. (self.mode or "") .. " "
    out = out .. "guard: " .. (self.guard or "") .. " "
    out = out .. "count: " .. (self.count or "") .. " "
    out = out .. "best rate: " .. (self.best_rate or "") .. "\n"

    out = out .. "[rate] " .. rate .. "\n"
    out = out .. "[stats] " .. stats .. "\n"
    out = out .. "[last] " .. last .. "\n"
    out = out .. "[sum of] " .. sum_of
    return out
end

function parse_rc_stats_csv( rest )

    function trim ( s )
        return ( s:gsub("^%s*(.-)%s*$", "%1") )
    end

    local fields = split ( rest, ',' )

    local stats = RcStatsCsv:create ()
    stats.ts = fields [ 1 ]
    stats.mode = fields [ 2 ]
    stats.guard = fields [ 3 ]
    stats.count = fields [ 4 ]
    stats.best_rate = fields [ 5 ]

    stats.rate = RcRate:create()
    stats.rate.name = trim ( fields [ 6 ] )
    stats.rate.idx = fields [ 7 ]
    stats.rate.airtime = fields [ 8 ]
    stats.rate.max_tp = fields [ 9 ]
    
    stats.stats = RcStats:create()
    stats.stats.avg_tp = fields [ 10 ]
    stats.stats.avg_prob = fields [ 11 ]
    stats.stats.sd_prob = fields [ 12 ]

    stats.last = RcLast:create()
    stats.last.prob = fields [ 13 ]
    stats.last.retry = fields [ 14 ]
    stats.last.suc = fields [ 15 ]
    stats.last.att = fields [ 16 ]
    
    stats.sum_of = RcSumOf:create()
    stats.sum_of.num_success = fields [ 17 ]
    stats.sum_of.num_attemps = fields [ 18 ]

    return stats
end
