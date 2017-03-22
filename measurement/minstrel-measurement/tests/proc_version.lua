
require ('parsers/proc_version')


local gentoo_sys = parse_proc_version ("Linux version 4.9.5-gentoo (root@sinope) (gcc version 4.9.4 (Gentoo 4.9.4 p1.0, pie-0.6.4) ) #4 SMP Mon Feb 20 16:49:22 CET 2017")

assert ( gentoo_sys.lx_version == "4.9.5-gentoo" )
assert ( gentoo_sys.lx_build_user == "root@sinope" )
assert ( gentoo_sys.gcc_version == "4.9.4" )
assert ( gentoo_sys.system == "Gentoo" )
assert ( gentoo_sys.num_cpu == 4 )
assert ( gentoo_sys.smp_enabled == true )
assert ( gentoo_sys.date == "Mon Feb 20 16:49:22 CET 2017" )

local lede_sys = parse_proc_version ("Linux version 4.4.49 (denis@sinope) (gcc version 5.4.0 (LEDE GCC 5.4.0 r3517-d6baeb5) ) #0 Fri Feb 17 09:30:48 2017")

assert ( lede_sys.lx_version == "4.4.49" )
assert ( lede_sys.lx_build_user == "denis@sinope" )
assert ( lede_sys.gcc_version == "5.4.0" )
assert ( lede_sys.system == "LEDE" )
assert ( lede_sys.num_cpu == 0 ) --?
assert ( lede_sys.smp_enabled == false )
assert ( lede_sys.date == "Fri Feb 17 09:30:48 2017" )

local gentoo_sys2 = parse_proc_version ("Linux version 4.9.6-gentoo-r1 (root@sinope) (gcc version 4.9.4 (Gentoo 4.9.4 p1.0, pie-0.6.4) ) #1 SMP Fri Mar 10 06:05:17 CET 2017")

print ( gentoo_sys2 )

assert ( gentoo_sys2.lx_version == "4.9.6-gentoo-r1" )
assert ( gentoo_sys2.lx_build_user == "root@sinope" )
assert ( gentoo_sys2.gcc_version == "4.9.4" )
assert ( gentoo_sys2.system == "Gentoo" )
assert ( gentoo_sys2.num_cpu == 1 )
assert ( gentoo_sys2.smp_enabled == true )
assert ( gentoo_sys2.date == "Fri Mar 10 06:05:17 CET 2017" )
