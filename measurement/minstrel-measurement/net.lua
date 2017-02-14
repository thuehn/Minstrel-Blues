
require ("spawn_pipe")
require ('parsers/ifconfig')

function get_addr ( iface )
    local ifconfig_proc = spawn_pipe( "ifconfig", iface )
    ifconfig_proc['proc']:wait()
    local lines = ifconfig_proc['out']:read("*a")
    local ifconfig = parse_ifconfig ( lines )
    return ifconfig.addr
end

function lookup ( name ) 
    local dig = spawn_pipe ( "dig", name )
    if ( dig['err_msg'] ~= nil ) then 
        self:send_error ( "dig: " .. dig['err_msg'] )
        return nil
    end
    local exitcode = dig['proc']:wait()
    local content = dig['out']:read("*a")
    local answer = parse_dig ( content )
    close_proc_pipes ( dig )
    return answer.addr
end
