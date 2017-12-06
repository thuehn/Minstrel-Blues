
local net = require ('Net')
require ('parsers/parsers')
require ('parsers/argparse_con')
local pprint = require ('pprint')

-- globals
ctrl = nil -- var in config file
nodes = {} -- table in config file
connections = {} -- table in config file

Config = {}

Config.find_node = function ( name, nodes ) 
    for _, node in ipairs ( nodes ) do
        if ( node.name == name ) then
            return node
        else
            local addr, rest = parse_ipv4 ( name )
            if ( addr ~= nil ) then
                local dig, _ = net.lookup ( node.name )
                if ( dig ~= nil and dig.addr ~= nil ) then
                    for _, addr2 in ipairs ( dig.addr ) do
                        if ( addr2 == addr ) then
                            return node
                        end
                    end
                end
            end
        end 
    end
    return nil
end

Config.cnode_to_string = function ( config )
    if ( config == nil ) then return "none" end
    return ( config.name or "none")
        .. "\t" .. ( config.radio or "none" )
        .. "\t" .. ( config.ctrl_if or "none" )
        .. "\t" .. ( config.mac or "none" )
end

Config.connections_tostring = function ( connections )
    local str = ""
    for ap, stas in pairs ( connections ) do
        str = str .. ap .. ": "
        for i, sta in pairs ( stas ) do
            if ( i ~= 1 ) then str = str .. ", " end
            str = str .. sta
        end
    end
    return str
end

Config.show_choice_error = function ( parser, args, missing )
    local str = ""
    for i, arg in ipairs ( args ) do
        if ( i ~= 1 ) then str = str .. " or " end
        str = str .. "<".. arg .. ">"
    end
    if ( missing ) then
        str = str .. " missing"
    end
    print ( str )
    parser:error (str)
end

Config.show_config_error = function ( parser, arg, option )
    local str
    if ( option == true) then
        str = "option '--" .. arg .. "' missing or no config file specified"
    else
        str = "<".. arg .. "> missing"
    end
    parser:error (str)
    --print ( parser:get_usage() )
    --print ( )
    --print ( "Error: " .. str )
    --os.exit()
end

Config.create_config = function ( name, ctrl_if, radio )
    return { name  = name
           , ctrl_if = ctrl_if
           , radio = radio
           }
end

Config.create_configs = function ( cmd_lines )
    local configs = {}
    for i, cmd_line in ipairs ( cmd_lines ) do
        local parts = split ( cmd_line, "," )
        configs [i] = Config.create_config ( parts [ 1 ], parts [ 3 ], ( parts [ 2 ] or "radio0" ) )
    end
    return configs
end

Config.copy_config_nodes = function ( src, dest )
    for _,v in ipairs( src ) do dest [ #dest + 1 ] = v end
end

Config.get_config_fname = function ( fname )
    local rc_fname = os.getenv("HOME") .. "/.minstrelmrc"
    local has_rcfile = isFile ( rc_fname )
    local has_config_arg = fname ~= nil
    
    if ( has_config_arg == true ) then
        return fname
    else
        return rc_fname
    end
end

Config.load_config = function ( fname )
    local rc_fname = os.getenv("HOME") .. "/.minstrelmrc"
    local has_rcfile = isFile ( rc_fname )
    local has_config_arg = fname ~= nil

    -- load config from a file
    if ( has_config_arg or has_rcfile ) then

        if ( ( has_config_arg == false or not isFile ( fname ) ) and not has_rcfile ) then
            print ( fname .. " does not exists.")
            return false
        end

        -- (loadfile, dofile, loadstring)  
        if ( has_config_arg == true ) then
            require ( string.sub ( fname, 1, #fname - 4 ) )
        else
            dofile ( rc_fname )
        end
        
        return true
    end

    return false
end

Config.set_config_from_arg = function ( config, key, arg )
    if ( arg ~= nil ) then config [ key ] = arg end 
end

Config.set_configs_from_arg = function ( configs, key, arg )
    for _, config in ipairs ( configs ) do
        Config.set_config_from_arg ( config, key, arg )
    end
end

Config.set_configs_from_args = function ( configs, args )
    for _, config in ipairs ( configs ) do
        for _, arg in ipairs ( args ) do
            local parts = split ( arg, "," )
            if ( config.name == parts [ 1 ] ) then
                if ( parts [ 2 ] ~= nil and parts [ 2 ] ~= "" ) then
                    Config.set_config_from_arg ( config, "radio", parts [ 2 ] )
                end
                if ( parts [ 3 ] ~= nil and parts [ 3 ] ~= "" ) then
                    Config.set_config_from_arg ( config, "ctrl_if", parts [ 3 ] )
                end
                if ( parts [ 4 ] ~= nil and parts [ 4 ] ~= "" ) then
                    Config.set_config_from_arg ( config, "rsa_key", parts [ 4 ] )
                end
                if ( parts [ 5 ] ~= nil and parts [ 5 ] ~= "" ) then
                    Config.set_config_from_arg ( config, "mac", parts [ 5 ] )
                end
            end
        end
    end
end

Config.select_config = function ( all_configs, name )
    if ( all_configs == nil ) then  return nil end

    local node = Config.find_node ( name, all_configs )

    if ( node == nil or node.name ~= name ) then
        print ( "Error: select_config: no configuration for node with name '" .. name .. "' found")
        return nil
    end
    return node
end

Config.select_configs = function ( all_configs, names )
    local configs = {}
    if ( table_size ( names ) > 0 ) then
        for _, name in ipairs ( names ) do
            local node = Config.find_node ( name, all_configs )
            if ( node == nil ) then
                print ( "Error: select configs: no configuration for node with name '" .. name .. "' found")
                return {}
            end
            configs [ #configs + 1 ] = node 
        end
    else
        for _, node in ipairs ( all_configs ) do
            configs [ #configs + 1 ] = node 
        end
    end
    return configs
end

Config.list_connections = function ( list )
    local names = {}
    for name, _ in pairs ( list ) do
        names [ #names + 1 ] = name
    end
    return names
end

Config.get_connections = function ( list, name )
    return list [ name ]
end

Config.accesspoints = function ( nodes, connections )
    local names = Config.list_connections ( connections )
    local aps = {}
    for _, name in ipairs ( names ) do
        aps [ #aps + 1] = Config.find_node ( name, nodes )
    end
    return aps
end

Config.stations = function ( nodes, connections )
    local stations = {}
    for _, stas in pairs ( connections ) do
        for _, name in ipairs ( stas ) do
            stations [ #stations  + 1] = Config.find_node ( name, nodes )
        end
    end
    return stations
end

-- TODO: adjacence matix?
Config.meshs = function ( nodes, connections )
    local names = Config.list_connections ( connections )
    local mesh = {}
    for _, name in ipairs ( names ) do
        mesh [ #mesh + 1] = Config.find_node ( name, nodes )
    end
    return mesh
end

-- global var connections
Config.read_connections = function ( cons )
    if ( cons ~= nil and cons ~= {} ) then
        connections = {}
    end

    for _, con in ipairs ( cons ) do
        local node, stas, err = parse_argparse_con ( con )
        if ( err == nil ) then
            connections [ node ] = stas
        else
            print ( err )
        end
    end


end

Config.save = function ( dir, ctrl, aps, stas, meshs )
    -- ctrl
    local fname = dir .. "/control.txt"
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        file:write ( ctrl.name .. "\n" )
        file:close ()
    end
    -- aps
    if ( table_size ( aps ) > 0 ) then
        local fname = dir .. "/accesspoints.txt"
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            for _, ap in ipairs ( aps ) do
                file:write ( ap.name .. "\n" )
            end
            file:close ()
        end
    end
    -- stas
    if ( table_size ( stas ) > 0 ) then
        local fname = dir .. "/stations.txt"
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            for _, sta in ipairs ( stas ) do
                file:write ( sta.name .. "\n" )
            end
            file:close ()
        end
    end
    -- meshs
    if ( table_size ( meshs ) > 0 ) then
        local fname = dir .. "/meshs.txt"
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            for _, mesh in ipairs ( meshs ) do
                file:write ( mesh.name .. "\n" )
            end
            file:close ()
        end
    end
end

Config.read = function ( dir )
    local ctrl = nil
    local aps = {}
    local stas = {}
    -- ctrl
    local fname = dir .. "/control.txt"
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local content = file:read ( "*a" )
        if ( content ~= nil ) then
            ctrl = split ( content, "\n" ) [1]
        end
        file:close ()
    end
    -- aps
    local fname = dir .. "/accesspoints.txt"
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local content = file:read ( "*a" )
        if ( content ~= nil ) then
            aps = split ( content, "\n" )
            table.remove ( aps, #aps )
        end
        file:close ()
    end
    -- stas
    local fname = dir .. "/stations.txt"
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local content = file:read ( "*a" )
        if ( content ~= nil ) then
            stas = split ( content, "\n" )
            table.remove ( stas, #stas )
        end
        file:close ()
    end

    return ctrl, aps, stas
end


return Config
