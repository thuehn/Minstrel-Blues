-- very simple functional parser helper functions
-- without error handling to read command line outputs
-- and without tokenizer (scanner)

local pprint = require ('pprint')

-- returns first char of a string
-- pre: string.len ( str ) > 0
function shead ( str )
    if ( str == nil ) then return nil end
    if ( string.len ( str ) == 0 ) then return nil end
    return string.sub ( str, 1, 1 )
end

-- returns rest of a string ( except first char )
-- pre: string.len ( str ) > 0
function stail ( str )
    if ( str == nil ) then return nil end
    if ( string.len ( str ) == 0 ) then return nil end
    return string.sub ( str, 2 )
end

function cursor ( pos )
    if ( pos == nil ) then return nil else return pos + 1 end
end

-- parse string 'key' from begin of string 'str'
-- return: true, rest when matches else false, str
function parse_str ( str, key, pos )
    function parse ( str, key, ide, pos )
        local rest = str
        if ( string.len ( key ) == 0 ) then return true, rest, pos end
        if ( shead ( rest ) == shead ( key ) ) then
            return parse ( stail ( rest ), stail ( key ), ide .. shead ( rest ), cursor ( pos ) )
        else
            return false, ide .. rest, pos
        end
    end
    return parse ( str, key, "", pos )
end

-- checks whether string 'num' is a number
-- return: true or false
function is_num ( num )
    return tonumber ( num ) ~= nil
end

-- parse n digits from begin of string 'str'
-- return: num, rest or "", rest
function parse_num ( str, pos )
    function parse ( str, num, pos )
        local parsed = str
        local ft = shead ( parsed )
        if ( is_num ( ft ) or ( string.len ( num ) == 0 and ft == '-' ) ) then
            return parse ( stail ( parsed ), num .. ft, cursor ( pos ) )
        else
            if ( num == "" ) then
                return nil, str, pos
            end
            return num, parsed, pos
        end
     end
     return parse ( str, "", pos )
end

function parse_hex_num ( str, pos )
    function parse ( str, num, pos )
        local rest = str
        local ft = shead ( rest )
        if ( is_hexdigit ( ft ) ) then
            return parse ( stail ( rest ), num .. ft, cursor ( pos ) )
        else
            return num, rest, pos
        end
     end
     return parse ( str, "", pos )
end

-- parse real number from begin of str
-- return: real, rest
function parse_real ( str, pos )
    local rest = str
    local num1; local num2
    local state
    num1, rest, pos = parse_num ( rest, pos )
    state, rest, pos = parse_str ( rest, ".", pos )
    if ( state == true ) then
        num2, rest, pos = parse_num ( rest, pos )
        return tonumber ( num1 .. "." .. num2 ), rest, pos
    else
        return tonumber ( num1 ), rest, pos
    end
end

-- return: str without leading whitespaces ('\n', ' ', '\t')
function skip_layout ( str, pos )
    local state = false
    local rest = str
    repeat
        local c = shead( rest )
        if ( c ~= '\n' and c ~= " " and c ~= '\t') then
            state = true
        else
            rest = stail ( rest )
            pos = cursor ( pos )
        end
    until state
    return rest, pos
end

function skip_until ( str, char, pos )
    local state = false
    local rest = str
    repeat
        local c = shead ( rest )
        if ( c == char ) then
            state = true
        else
            rest = stail ( rest )
            pos = cursor ( pos )
        end
    until state
    return rest, pos
end

function parse_until ( str, char, pos )
    local state = false
    local rest = str
    local out = ""
    repeat
        local c = shead( rest )
        if ( c == char ) then
            state = true
        else
            out = out .. c
            rest = stail ( rest )
            pos = cursor ( pos )
        end
    until state
    return out, rest, pos
end

function skip_line_comment ( str, cc, pos )
    local state = false
    local rest = str
    local rest_cc = cc
    repeat
        local c1 = shead ( rest )
        local c2 = shead ( rest_cc )
        rest = stail ( rest )
        pos = cursor ( pos )
        rest_cc = stail ( rest_cc )
        if ( c1 ~= c2 ) then
            return false, str, pos
        end
    until string.len ( rest_cc ) == 0
    local c
    repeat
        c = shead ( rest )
        rest = stail ( rest )
        pos = cursor ( pos )
    until c == '\n'
    return true, rest, pos
end

-- check whether char c is a hexadecimal digit
function is_hexdigit ( c )
    return c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f'
        or c == 'A' or c == 'B' or c == 'C' or c == 'D' or c == 'E' or c == 'F'
        or is_digit ( c )
end

-- check whether char c is a decimal digit
function is_digit ( c )
    return c == '0' or c == '1' or c == '2' or c == '3' or c == '4' 
        or c == '5' or c == '6' or c == '7' or c == '8' or c == '9'
end

-- check whether char c is a letter
-- todo: maybe ascii magic fits too
function is_char ( c )
    return c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f'
        or c == 'g' or c == 'h' or c == 'i' or c == 'j' or c == 'k' or c == 'l'
        or c == 'm' or c == 'n' or c == 'o' or c == 'p' or c == 'q' or c == 'r'
        or c == 's' or c == 't' or c == 'u' or c == 'v' or c == 'w' or c == 'x'
        or c == 'y' or c == 'z'
        or c == 'A' or c == 'B' or c == 'C' or c == 'D' or c == 'E' or c == 'F'
        or c == 'G' or c == 'H' or c == 'I' or c == 'J' or c == 'K' or c == 'L'
        or c == 'M' or c == 'N' or c == 'O' or c == 'P' or c == 'Q' or c == 'R'
        or c == 'S' or c == 'T' or c == 'U' or c == 'V' or c == 'W' or c == 'X'
        or c == 'Y' or c == 'Z'
end

-- parse string of digits and letters from begin of 'str'
-- return ide, rest
-- todo: maybe first char should never be a digit
function parse_ide ( str, additional_chars, pos )
    function is_in ( l, c )
        if ( l == nil) then return false end
        for _, c2 in ipairs ( l ) do
            if ( c == c2) then return true end
        end
        return false
    end
    local state = false
    local rest = str
    local ide = nil 
    repeat
        local c = shead ( rest )
        if ( is_digit ( c ) == false and is_char ( c ) == false and not is_in ( additional_chars, c ) ) then
            state = true
        else
            rest = stail ( rest )
            pos = cursor ( pos )
            if ( ide == nil) then ide = "" end
            ide = ide .. c
        end
    until state
    return ide, rest, pos
end

-- parse two hexadecimal digits from begin of 'str'
function parse_hexbyte ( str, pos )
    local state = false
    local rest = str
    local num = "" 

    local c = shead ( rest )
    if ( is_hexdigit (c) ) then
        num = num .. c
        rest = stail ( rest )
        pos = cursor ( pos )
    else
        return nil, rest, cursor ( pos)
    end

    local c = shead ( rest )
    if ( is_hexdigit (c) ) then
        num = num .. c
        rest = stail ( rest )
        pos = cursor ( pos )
        return num, rest, pos
    else
        return nil, rest, pos
    end
end

-- parse six hexadecimal tuples seperated by colons from begin of 'str'
function parse_mac ( str, pos )
    local rest = str
    local mac = {} 
    local state
    local num
    for i = 1, 6 do
        if ( i ~= 1 ) then
            state, rest, pos = parse_str ( rest, ":", pos )
            if ( state == false ) then return {}, rest, pos end
        end
        num, rest, pos = parse_hexbyte ( rest, pos )
        if ( num ~= nil ) then 
            mac[i] = num
        else
            return nil, str, pos
        end
    end

    local out = ""
    for _, byte in ipairs ( mac ) do
        if ( string.len ( out ) > 0) then out = out .. ":" end
        out = out .. byte
    end
    return out, rest, pos
end

-- parse four decimals seperated by dot from begin of 'str'
function parse_ipv4 ( str, pos )
    local num1 = nil; local num2 = nil 
    local num3 = nil; local num4 = nil
    local rest = str
    local state
    num1, rest, pos = parse_num ( rest, pos )
    state, rest, pos = parse_str ( rest, ".", pos )
    num2, rest, pos = parse_num ( rest, pos )
    state, rest, pos = parse_str ( rest, ".", pos )
    num3, rest , pos= parse_num ( rest, pos )
    state, rest, pos = parse_str ( rest, ".", pos )
    num4, rest, pos = parse_num ( rest, pos )
    if ( num1 == nil or num2 == nil or num3 == nil or num4 == nil ) then
        return nil, str, pos
    end
    return num1 .. "." .. num2 .. "." .. num3 .. "." .. num4, rest, pos
end

function parse_ipv6 ( str, pos )
    local rest = str
    local num
    local state
    local result = ""
    repeat
        num, rest, pos = parse_hex_num ( rest, pos )
        result = result .. num
        state, rest, pos = parse_str ( rest, ":", pos )
        if ( state == true ) then 
            result = result .. ":"
        end
    until state == false
    return result, rest, pos
end
