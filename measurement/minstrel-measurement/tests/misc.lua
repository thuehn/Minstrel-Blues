
require ('misc')

local list = {}
list [1] = "ABCD"
list [2] = "BCDE"
list [3] = "CDEF"
list [4] = "DEFG"

local str = table_tostring ( list )
print ( str )
local str = table_tostring ( list, 10 )
print ( str )
