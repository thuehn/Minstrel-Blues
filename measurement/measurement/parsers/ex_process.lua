require ('parsers/parsers')

function parse_process( procstr )
    local state, rest = parse_str( procstr, "process (" )
    local num, rest = parse_num( rest )
    local state, rest = parse_str( rest, ", " )
    local is_running = true
    local state, rest = parse_str( rest, "running" )
    if (state ~= true) then
        state, rest = parse_str( rest, "terminated" )
        if (state == true) then 
            is_running = false
        end
    end
    state, rest = parse_str( rest, ")" )
    local ret = {}
    ret["pid"] = tonumber(num)
    ret["is_running"] = is_running
    return ret
end
