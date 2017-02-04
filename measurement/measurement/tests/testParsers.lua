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
print (assert(stail("abc") == "bc"))
state, rest = parse_str ("abc", "ab")
print (assert(state == true))
print (assert(rest == "c"))
state, rest = parse_str ("aebc", "ab")
print (assert(state == false))
print (assert(rest == "aebc"))

