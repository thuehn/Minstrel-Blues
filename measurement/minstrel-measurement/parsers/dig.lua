require ('parsers/parsers')
local misc = require ('misc')

-- single line comment starts with ';'
-- resolved address for 'apfel' starts with 'apfel.'
-- unresolved address for 'apfel' starts with '.' followed by authority

Dig = { name = nil, addr = nil }

function Dig:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Dig:create ()
    local o = Dig:new()
    return o
end

function Dig:__tostring() 
    local name = "nil"
    if (self.name ~= nil) then name = self.name end
    local addr = "nil"
    if (self.addr ~= nil) then addr = self.addr end
    return "name: " .. name .. " addr: " .. addr
end


function parse_dig ( lines )
    local state
    local rest = lines

    function parse_dig_line ( line )
        local state
        local rest = line
        local name
        local addr
        local num
        
        local add_chars = {}
        add_chars[1] = "."
        add_chars[2] = "-"
        name, rest = parse_ide ( rest, add_chars )
        rest = skip_layout( rest )
        num, rest = parse_num ( rest )
        rest = skip_layout( rest )
        state, rest = parse_str ( rest, "IN" )
        rest = skip_layout( rest )
        state, rest = parse_str ( rest, "A" )
        rest = skip_layout( rest )
        addr, rest = parse_ipv4 ( rest )

        return name, addr, rest
    end

    local dig = Dig:create()
    dig.addr = {}
    repeat
        local c = shead ( rest )
        if ( c == ";" ) then
            state, rest = skip_line_comment ( rest, ";" )
        elseif ( c == "." ) then
            break
        elseif ( c == '\n' ) then
            rest = stail ( rest )
        else
            name, addr, rest = parse_dig_line ( rest )
            dig.name = name
            dig.addr [ #dig.addr + 1 ] = addr
        end
    until rest == nil or rest == ""
    
    return dig
end
