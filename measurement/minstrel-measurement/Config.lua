
function find_node( name, nodes ) 
    for _, node in ipairs ( nodes ) do 
        if ( node.name == name ) then return node end 
    end
    return nil
end

function cnode_to_string ( config )
    if ( config == nil ) then return "none" end
    return ( config.name or "none") .. "\t" .. ( config.radio or "none" ) .. "\t" .. ( config.ctrl_if or "none" )
end


function show_config_error( parser, arg, option )
    local str
    if ( option == true) then
        str = "option '--" .. arg .. "' missing or no config file specified"
    else
        str = "<".. arg .. "> missing"
    end
    print ( parser:get_usage() )
    print ( )
    print ( "Error: " .. str )
    os.exit()
end

stations = {} -- table in config file
aps = {} -- table in config file
nodes = {}

function create_config ( name, ctrl, radio )
    return { name = name
           , ctrl = ctrl
           , radio= radio
           }
end

function create_configs ( names, ctrl, radio )
    local configs = {}
    for i, name in ipairs ( names ) do
        configs [i] = create_config ( name, ctrl, radio )
    end
    return configs
end

function copy_config_nodes()
    for _,v in ipairs(stations) do nodes [ #nodes + 1 ] = v end
    for _,v in ipairs(aps) do nodes [ #nodes + 1 ] = v end
end

function get_config_fname ( fname )
    local rc_fname = os.getenv("HOME") .. "/.minstrelmrc"
    local has_rcfile = isFile ( rc_fname )
    local has_config_arg = fname ~= nil
    
    if ( has_config_arg == true ) then
        return fname
    else
        return rc_fname
    end
end

function load_config ( fname )
    local rc_fname = os.getenv("HOME") .. "/.minstrelmrc"
    local has_rcfile = isFile ( rc_fname )
    local has_config_arg = fname ~= nil

    -- load config from a file
    if ( has_config_arg or has_rcfile ) then

        if ( not isFile ( fname ) and not has_rcfile ) then
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

function set_config_from_arg ( config, key, arg )
    if ( arg ~= nil ) then config [ key ] = arg end 
end

function set_configs_from_arg ( configs, key, arg )
    for _, config in ipairs ( configs ) do
        set_config_from_arg ( config, key, arg )
    end
end

function select_config ( config, arg )
    if ( config == nil ) then
        return nil
    elseif ( arg == nil ) then
        return nil
    else
        if ( config.name ~= arg ) then
            print ( "Error: no configuration for node with name '" .. arg .. "' found")
            return nil
        end
        return config
    end
end

function select_configs ( all_configs, args )
    local configs = {}
    if ( table_size ( args ) > 0 ) then
        for _, name in ipairs ( args ) do
            local node = find_node ( name, all_configs )
            if ( node == nil ) then
                print ( "Error: no configuration for node with name '" .. name .. "' found")
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