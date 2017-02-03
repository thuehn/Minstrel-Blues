
require ('parsers/cpusage')

cpu1 = parse_cpusage ( "timestamp: 2017-01-26 16.41.49, user:   0.3%, nice:   0.0%, system:   0.0%, idle:  99.5%, iowait:   0.3%, irq:   0.0%, softirq:   0.0%," )
print ( assert ( cpu1.timestamp == "2017-01-26 16.41.49" ) )
print ( assert ( cpu1.user == 0.3 ) )
print ( assert ( cpu1.nice == 0 ) )
print ( assert ( cpu1.system == 0 ) )
print ( assert ( cpu1.idle == 99.5 ) )
print ( assert ( cpu1.iowait == 0.3 ) )
print ( assert ( cpu1.irq == 0 ) )
print ( assert ( cpu1.softirq == 0 ) )

cpu2 = parse_cpusage ( "timestamp: 2017-01-26 17.37.24, user:   0.0%, nice:   0.0%, system:   0.0%, idle: 100.0%, iowait:   0.0%, irq:   0.0%, softirq:   0.0%," )

print ( assert ( cpu2.timestamp == "2017-01-26 17.37.24" ) )
print ( assert ( cpu2.user == 0 ) )
print ( assert ( cpu2.nice == 0 ) )
print ( assert ( cpu2.system == 0 ) )
print ( assert ( cpu2.idle == 100 ) )
print ( assert ( cpu2.iowait == 0 ) )
print ( assert ( cpu2.irq == 0 ) )
print ( assert ( cpu2.softirq == 0 ) )
