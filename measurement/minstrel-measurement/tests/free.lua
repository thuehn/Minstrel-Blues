
require ('parsers/free')


local free_m_str = "             total       used       free     shared    buffers     cached\nMem:        125392      40172      85220        768       4472      13632\n-/+ buffers/cache:      22068     103324\nSwap:            0          0          0"

local free_m = parse_free ( free_m_str )
assert ( free_m.total == 125392 )
assert ( free_m.used == 40172 )
assert ( free_m.free == 85220 )
assert ( free_m.shared == 768 )
assert ( free_m.buffers == 4472 )
assert ( free_m.cached == 13632 )
