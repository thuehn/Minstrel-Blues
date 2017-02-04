-- very simple functional parser helper functions
-- without error handling to read command line outputs
-- and without tokenizer (scanner)

require ('functional')

-- returns first char of a string
-- pre: string.len ( str ) > 0
function shead ( str )
    if ( string.len ( str ) == 0 ) then return nil end
    return string.sub(str, 1, 1)
end

-- returns rest of a string ( except first char )
-- pre: string.len ( str ) > 0
function stail ( str )
    if ( string.len ( str ) == 0 ) then return nil end
    return string.sub(str, 2)
end

-- parse string 'key' from begin of string 'str'
-- return: true, rest when matches else false, str
-- fixme: eats 'str' when not matching key completely
function parse_str ( str, key )
    local parsed = str
    if ( key == "" ) then return true, parsed end
    if ( shead ( parsed ) == shead ( key ) ) then
        return parse_str ( stail ( parsed ), stail ( key ) )
    else
        return false, str
    end
end

-- checks whether string 'num' is a number
-- return: true or false
function is_num( num ) 
    return tonumber( num ) ~= nil
end

-- parse n digits from begin of string 'str'
-- return: num, rest or "", rest
function parse_num ( str )
    function parse ( str, num )
        local parsed = str
        local ft = shead ( parsed )
        if ( is_num ( ft ) ) then
            return parse ( stail ( parsed ), num .. ft )
        else
            return num, parsed
        end
     end
     return parse ( str, "")
end

-- parse real number from begin of str
-- return: real, rest
function parse_real ( str )
    local rest = str
    local num1; local num2
    local state
    num1, rest = parse_num( rest )
    state, rest = parse_str( rest, "." )
    num2, rest = parse_num( rest )
    return tonumber(num1 .. "." .. num2), rest
end

-- return: str without leading whitespaces ('\n', ' ', '\t')
function skip_layout ( str )
    local state = false
    local rest = str
    repeat
        local c = shead( rest )
        if ( c ~= '\n' and c ~= " " and c ~= '\t') then
            state = true
        else
            rest = stail ( rest )
        end
    until state
    return rest
end

function skip_line_comment ( str, cc )
    local state = false
    local rest = str
    local rest_cc = cc
    repeat
        local c1 = shead ( rest )
        local c2 = shead ( rest_cc )
        rest = stail ( rest )
        rest_cc = stail ( rest_cc )
        if (c1 ~= c2) then
            return false, str
        end
    until string.len( rest_cc ) == 0
    repeat
        local c = shead ( rest )
        rest = stail ( rest )
    until c == '\n'
    return true, rest
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
        or c == 'H' or c == 'H' or c == 'I' or c == 'J' or c == 'K' or c == 'L'
        or c == 'M' or c == 'N' or c == 'O' or c == 'P' or c == 'Q' or c == 'R'
        or c == 'S' or c == 'T' or c == 'U' or c == 'V' or c == 'W' or c == 'X'
        or c == 'Y' or c == 'Z'
end

-- parse string of digits and letters from begin of 'str'
-- return ide, rest
-- todo: maybe first char should never be a digit
function parse_ide ( str, additional_char )
    local state = false
    local rest = str
    local ide = nil 
    repeat
        local c = shead ( rest )
        if ( is_digit(c) == false and is_char(c) == false and (additional_char == nil or c ~= additional_char) ) then
            state = true
        else
            rest = stail ( rest )
            if ( ide == nil) then ide = "" end
            ide = ide .. c
        end
    until state
    return ide, rest
end

-- parse two hexadecimal digits from begin of 'str'
function parse_hexbyte ( str )
    local state = false
    local rest = str
    local num = "" 

    local c = shead ( rest )
    if ( is_hexdigit (c) ) then
        num = num .. c
        rest = stail ( rest )
    else
        return nil, rest
    end

    local c = shead ( rest )
    if ( is_hexdigit (c) ) then
        num = num .. c
        rest = stail ( rest )
        return num, rest
    else
        return nil, rest
    end
end

-- parse six hexadecimal tuples seperated by colons from begin of 'str'
function parse_mac ( str )
    local rest = str
    local mac = {} 
    local state
    local num
    for i = 1, 6 do
        if ( i ~= 1 ) then
            state, rest = parse_str ( rest, ":" )
            if (state == false) then return {}, rest end
        end
        num, rest = parse_hexbyte ( rest )
        if (num ~= nil) then 
            mac[i] = num
        else
            return nil, str
        end
    end

    local out = ""
    for _, byte in ipairs ( mac ) do
        if (out ~= "") then out = out .. ":" end
        out = out .. byte
    end
    return out, rest
end

-- parse four decimals seperated by dot from begin of 'str'
function parse_ipv4 ( str )
    local num1 = nil; local num2 = nil 
    local num3 = nil; local num4 = nil
    local rest = str
    local state
    num1, rest = parse_num( rest )
    state, rest = parse_str( rest, "." )
    num2, rest = parse_num( rest )
    state, rest = parse_str( rest, "." )
    num3, rest = parse_num( rest )
    state, rest = parse_str( rest, "." )
    num4, rest = parse_num( rest )
    return num1 .. "." .. num2 .. "." .. num3 .. "." .. num4, rest
end
