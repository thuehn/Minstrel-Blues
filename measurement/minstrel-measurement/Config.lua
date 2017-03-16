
-- globals
ctrl = nil -- var in config file
nodes = {} -- table in config file
connections = {} -- table in config file

Config = {}

Config.find_node = function ( name, nodes ) 
    for _, node in ipairs ( nodes ) do 
        if ( node.name == name ) then return node end 
    end
    return nil
end

Config.cnode_to_string = function ( config )
    if ( config == nil ) then return "none" end
    return ( config.name or "none") .. "\t" .. ( config.radio or "none" ) .. "\t" .. ( config.ctrl_if or "none" )
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

Config.create_configs = function ( names, ctrl, radio )
    local configs = {}
    for i, name in ipairs ( names ) do
        configs [i] = Config.create_config ( name, ctrl, radio )
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

Config.select_config = function ( all_configs, name )
    if ( all_configs == nil ) then  return nil end

    local node = Config.find_node ( name, all_configs )

    if ( node == nil ) then return nil end
    if ( node.name ~= name ) then
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
        aps [ #aps  + 1] = Config.find_node ( name, nodes )
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

return Config
