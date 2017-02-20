require ('parsers/parsers')

assert ( shead("") == nil )
assert ( shead("a") == "a" )

state, rest = skip_line_comment ( "; comment\ncode" , ";")
assert ( state == true )
assert ( rest == "code")

state, rest = skip_line_comment ( ";; comment\ncode" , ";;")
assert ( state == true )
assert ( rest == "code")

assert(shead("abc") == "a")
assert(stail("abc") == "bc")
state, rest = parse_str ("abc", "ab")
assert(state == true)
assert(rest == "c")

ide, rest = parse_ide ( "G,M" )
assert ( ide == "G" )
assert ( rest == ",M" )

state, rest = parse_str ("aebc", "ab")
assert(state == false)
assert(rest == "aebc")
