require ('parsers/parsers')

print (assert(shead("abc") == "a"))
print (assert(stail("abc") == "bc"))
state, rest = parse_str ("abc", "ab")
print (assert(state == true))
print (assert(rest == "c"))
state, rest = parse_str ("aebc", "ab")
print (assert(state == false))
print (assert(rest == "aebc"))

