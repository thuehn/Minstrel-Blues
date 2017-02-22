require ('parsers/parsers')

-- parse command line option 'con' value
-- --con hostname=hostname
-- --con hostname=hostname,hostname

function parse_argparse_con ( str )
    local rest = str
    local state
    local ap
    local stas = {}
    
    local add_chars = {}
    add_chars[1] = '-'
    add_chars[2] = '.'

    ap, rest = parse_ide ( rest, add_chars )
    if ( ap == nil ) then return nil, {}, "Error: --con argument have to start with a hostname: '" .. rest .. "'" end
    state, rest = parse_str( rest, '=' )
    if (state ==  false ) then return nil, {}, "Error: --con missing '=' after hostname " .. ap .. ": '" .. rest .. "'" end
    local sep = '='
    repeat
        local sta
        sta, rest = parse_ide ( rest, add_chars )
        if ( sta == nil ) then return nil, {}, "Error: --con missing hostname after '" .. sep .. "': '" .. rest .. "'" end
        stas [ #stas + 1 ] = sta
        local c = shead (rest)
        if ( c == ',') then rest = stail ( rest )
        elseif ( c ~= nil ) then return nil, {}, "Error: --con missing ',' between stations: '" .. rest .. "'" end 
        sep = ','
    until c == nil
    
    return ap, stas, nil
end
