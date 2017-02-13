
function find_node( name, nodes ) 
    for _, node in ipairs ( nodes ) do 
        if ( node.name == name ) then return node end 
    end
    return nil
end

function cnode_to_string ( config )
    return config.name .. "\t" .. config.radio .. "\t" .. config.ctrl_if
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


