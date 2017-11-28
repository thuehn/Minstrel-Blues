
require ('parsers/proc_pid_stat')

local init_stat = parse_proc_pid_stat ("1 (init) S 0 1 1 0 -1 4194560 14890 546998 17 400 7 230 661 120 20 0 1 0 5 4382720 366 18446744073709551615 1 1 0 0 0 0 0 1475401980 671819267 0 0 0 17 1 0 0 378769 0 0 0 0 0 0 0 0 0 0")

assert ( init_stat.pid == 1 )
assert ( init_stat.program == "init" )
assert ( init_stat.state == "S" )

local redshift_stat = parse_proc_pid_stat ("6244 (redshift) S 6211 6211 6211 0 -1 1077936128 197 0 4 0 194 122 0 0 20 0 1 0 7358 43421696 720 18446744073709551615 4194304 4239756 140735968004320 0 0 0 0 65536 16898 1 0 0 17 3 0 0 11163430 0 0 6340016 6341384 6344704 140735968008347 140735968008387 140735968008387 140735968010214 0")

assert ( redshift_stat.pid == 6244 )
assert ( redshift_stat.program == "redshift" )
assert ( redshift_stat.state == "S" )
