
require ('parsers/rc_stats_csv')

local stats_str1 = "CCK,LP,1,, 1.0M,120,10548,0.7,0.7,100.0,0.0,100.0,0,0,0,6,6,7,3,1.0"
local stats1 = parse_rc_stats_csv ( stats_str1 )
print ( stats1 )

assert ( stats1.mode == "CCK" )
assert ( stats1.guard == "LP" )
assert ( stats1.count == "1" )
assert ( stats1.best_rate == "" )

assert ( stats1.rate.name  == "1.0M" )
assert ( stats1.rate.idx  == "120" )
assert ( stats1.rate.airtime  == "10548" )
assert ( stats1.rate.max_tp  == "0.7" )

assert ( stats1.stats.avg_tp  == "0.7" )
assert ( stats1.stats.avg_prob  == "100.0" )
assert ( stats1.stats.sd_prob  == "0.0" )

assert ( stats1.last.prob == "100.0" )
assert ( stats1.last.retry == "0" )
assert ( stats1.last.suc == "0" )
assert ( stats1.last.att == "0" )

assert ( stats1.sum_of.num_success == "6" )
assert ( stats1.sum_of.num_attemps == "6" )

print ( )

local stats_str2 = "HT20,LGI,1,ABCDP,MCS0 ,0,1477,5.6,5.6,100.0,0.0,100.0,3,1,1,10,10,7,3,1.0"
local stats2 = parse_rc_stats_csv ( stats_str2 )
print ( stats2 )

assert ( stats2.mode == "HT20" )
assert ( stats2.guard == "LGI" )
assert ( stats2.count == "1" )
assert ( stats2.best_rate == "ABCDP" )

assert ( stats2.rate.name  == "MCS0" )
assert ( stats2.rate.idx  == "0" )
assert ( stats2.rate.airtime  == "1477" )
assert ( stats2.rate.max_tp  == "5.6" )

assert ( stats2.stats.avg_tp  == "5.6" )
assert ( stats2.stats.avg_prob  == "100.0" )
assert ( stats2.stats.sd_prob  == "0.0" )

assert ( stats2.last.prob == "100.0" )
assert ( stats2.last.retry == "3" )
assert ( stats2.last.suc == "1" )
assert ( stats2.last.att == "1" )

assert ( stats2.sum_of.num_success == "10" )
assert ( stats2.sum_of.num_attemps == "10" )

print ( )

local stats_str3 = "HT20,LGI,1,,MCS1 ,1,739,10.5,0.0,0.0,0.0,0.0,0,0,0,0,0,7,3,1.0"
local stats3 = parse_rc_stats_csv ( stats_str3 )
print ( stats3 )

assert ( stats3.mode == "HT20" )
assert ( stats3.guard == "LGI" )
assert ( stats3.count == "1" )
assert ( stats3.best_rate == "" )

assert ( stats3.rate.name  == "MCS1" )
assert ( stats3.rate.idx  == "1" )
assert ( stats3.rate.airtime  == "739" )
assert ( stats3.rate.max_tp  == "10.5" )

assert ( stats3.stats.avg_tp  == "0.0" )
assert ( stats3.stats.avg_prob  == "0.0" )
assert ( stats3.stats.sd_prob  == "0.0" )

assert ( stats3.last.prob == "0.0" )
assert ( stats3.last.retry == "0" )
assert ( stats3.last.suc == "0" )
assert ( stats3.last.att == "0" )

assert ( stats3.sum_of.num_success == "0" )
assert ( stats3.sum_of.num_attemps == "0" )
