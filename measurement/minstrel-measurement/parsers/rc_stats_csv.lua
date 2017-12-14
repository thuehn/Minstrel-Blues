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

--[[
              best   ____________rate__________    ________statistics________    _____last____    ______sum-of________    _________________________tpc-statistics__________________________
mode guard #  rate  [name   idx airtime  max_tp]  [avg(tp) avg(prob) sd(prob)]  [retry|suc|att]  [#success | #attempts]  [     sample-power    |   reference-power   |      data-power     ]
														                                                             	 [  suc|att   prob dBm |  suc|att   prob dBm |  suc|att   prob dBm ]
CCK    LP  1          1.0M  120   10548     0.0       0.0      27.6      0.0       0     0 1             2   7                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2
CCK    LP  1          2.0M  121    5476     0.0       0.0     100.0      0.0       0     0 0             1   1                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2
CCK    LP  1          5.5M  122    2411     2.4       2.4     100.0      0.0       0     0 0             1   1                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2
CCK    LP  1         11.0M  123    1535     4.8       4.8     100.0      0.0       0     1 1             2   2                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2
HT20  LGI  1         MCS0     0    1477     4.8       4.8     100.0      0.0       3     0 0             8   8                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2
HT20  LGI  1         MCS1     1     739     9.7       9.7     100.0      0.0       4     0 0             2   2                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2
HT20  LGI  1         MCS2     2     493    14.6      14.6     100.0      0.0       5     0 0             2   2                0 0      0.0   0      0 0      0.0   0      0 0      0.0   2

--]]

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

RcLast = { retry = nil
         , suc = nil
         , att = nil
         }

function RcLast:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcLast:create ( retry, suc, att )
    local o = RcLast:new( { retry = retry
                          , suc = suc
                          , att = att
                          } )
    return o
end

function RcLast:__tostring() 
    local out = ""
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


RcTpc = { sp_succ = nil -- sample power
        , sp_att = nil
        , sp_prob = nil
        , sp_dbm = nil
        , rp_succ = nil -- reference power
        , rp_att = nil
        , rp_prob = nil
        , rp_dbm = nil
        , dp_succ = nil -- data power
        , dp_att = nil
        , dp_prob = nil
        , db_dbm = nil
        }

function RcTpc:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcTpc:create ( sp_succ, sp_att, sp_prob, sp_dbm
                      , rp_succ, rp_att, rp_prob, rp_dbm
                      , dp_succ, dp_att, dp_prob, dp_dbm
                      )

    local o = RcTpc:new( { sp_succ = sp_succ
                         , sp_att = sp_att
                         , sp_prob = sp_prob
                         , sp_dbm = sp_dbm
                         , rp_succ = rp_succ
                         , rp_att = rp_att
                         , rp_prob = rp_prob
                         , rp_dbm = rp_dbm
                         , dp_succ = dp_succ
                         , dp_att = dp_att
                         , dp_prob = dp_prob
                         , dp_dbm = db_dbm
                         } )
    return o
end

function RcTpc:__tostring() 
    local out = ""
    out = out .. "sp succ: " .. ( self.sp_succ or "" ) .. " "
    out = out .. "sp_att: " .. ( self.sp_att or "" ) .. " "
    out = out .. "sp_prob: " .. ( self.sp_prob or "" ) .. " "
    out = out .. "sp_dbm: " .. ( self.sp_dbm or "" ) .. " "

    out = out .. "rp succ: " .. ( self.rp_succ or "" ) .. " "
    out = out .. "rp_att: " .. ( self.rp_att or "" ) .. " "
    out = out .. "rp_prob: " .. ( self.rp_prob or "" ) .. " "
    out = out .. "rp_dbm: " .. ( self.rp_dbm or "" ) .. " "

    out = out .. "dp succ: " .. ( self.dp_succ or "" ) .. " "
    out = out .. "dp_att: " .. ( self.dp_att or "" ) .. " "
    out = out .. "dp_prob: " .. ( self.dp_prob or "" ) .. " "
    out = out .. "dp_dbm: " .. ( self.dp_dbm or "" ) .. " "

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
             , tpc = nil
             }

function RcStatsCsv:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RcStatsCsv:create ( ts, mode, guard, count, best_rate, rate, stats, last, sum_of, tpc )
    local o = RcStatsCsv:new( { ts = ts
                              , mode = mode
                              , guard = guard
                              , count = count
                              , best_rate = best_rate 
                              , rate = rate
                              , stats = stats
                              , last = last
                              , sum_of = sum_of
                              , tpc = tpc
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
    out = out .. "[sum of] " .. sum_of .. "\n"
    out = out .. "[tpc]" .. tpc
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
    stats.last.retry = fields [ 13 ]
    stats.last.suc = fields [ 14 ]
    stats.last.att = fields [ 15 ]
    
    stats.sum_of = RcSumOf:create()
    stats.sum_of.num_success = fields [ 16 ]
    stats.sum_of.num_attemps = fields [ 17 ]

    stats.tpc = RcTpc:create()
    stats.tpc.sp_succ = fields [ 18 ]
    stats.tpc.sp_att = fields [ 19 ]
    stats.tpc.sp_prob = fields [ 20 ]
    stats.tpc.sp_dbm = fields [ 21 ]
    stats.tpc.rp_succ = fields [ 22 ]
    stats.tpc.rp_att = fields [ 23 ]
    stats.tpc.rp_prob = fields [ 24 ]
    stats.tpc.rp_dbm = fields [ 25 ]
    stats.tpc.dp_succ = fields [ 26 ]
    stats.tpc.dp_att = fields [ 27 ]
    stats.tpc.dp_prob = fields [ 28 ]
    stats.tpc.dp_dbm = fields [ 29 ]

    return stats
end
