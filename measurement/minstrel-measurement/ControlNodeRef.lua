
local posix = require ('posix') -- sleep
require ("rpc")
require ("lpc")
local misc = require 'misc'
local net = require ('Net')
require ('NetIF')
local pprint = require ('pprint')

ControlNodeRef = { name = nil
                 , ctrl = nil
                 , rpc = nil
                 , output_dir = nil
                 , stats = nil   -- maps node name to statistics
                 }

function ControlNodeRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ControlNodeRef:create( name, ctrl_if, ctrl_ip, output_dir )
    -- ctrl node iface, ctrl node (name) lookup
    local ctrl_net = NetIF:create ( ctrl_if )
    ctrl_net.addr = ctrl_ip
    if ( ctrl_net.addr == nil) then
        local ip_addr = net.lookup ( name )
        if ( ip_addr ~= nil ) then
            ctrl_net.addr = ip_addr
        end 
    end

    local o = ControlNodeRef:new { name = name, ctrl = ctrl_net, output_dir = output_dir, stats = {}  }
    return o
end

function ControlNodeRef:restart_wifi_debug ()
    self.rpc.restart_wifi_debug()
end

function ControlNodeRef:init ( rpc )
    self.rpc = rpc
end

function ControlNodeRef:get_board ()
    return self.rpc.get_board ()
end

function ControlNodeRef:get_boards ()
    return self.rpc.get_boards ()
end

function ControlNodeRef:start ( ctrl_port, log_file, log_port )
    local cmd = {}
    cmd [1] = "lua"
    cmd [2] = "/usr/bin/runControl"
    cmd [3] = "--port "
    cmd [4] = ctrl_port 
    cmd [5] = "--ctrl_if"
    cmd [6] = self.ctrl.iface
    cmd [7] = "--output"
    cmd [8] = self.output_dir
    if ( log_file ~= nil and log_port ~= nil ) then
        cmd [9] = "--log_file"
        cmd [10] = log_file
        cmd [11] = "--log_port"
        cmd [12] = log_port 
    end

    print ( cmd )
    local pid, _, _ = misc.spawn ( unpack ( cmd ) )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:start_remote ( ctrl_port, log_file, log_port )
    local remote_cmd = "lua /usr/bin/runControl"
                 .. " --port " .. ctrl_port 
                 .. " --ctrl_if " .. self.ctrl.iface
                 .. " --output " .. self.output_dir

    if ( log_file ~= nil and log_port ~= nil ) then
        remote_cmd = remote_cmd .. " --log_file " .. log_file 
                       .. " --log_port " .. log_port 
    end
    print ( remote_cmd )
    -- fixme:  "-i", node_ref.rsa_key, 
    local pid, _, _ = misc.spawn ( "ssh", "root@" .. self.ctrl.addr, remote_cmd )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:connect ( ctrl_port )
    return net.connect ( self.ctrl.addr, ctrl_port, 10, self.name, 
                         function ( msg ) print ( msg ) end )
end

function ControlNodeRef:disconnect ( slave )
    net.disconnect ( slave )
end

function ControlNodeRef:stop ( pid )
    ps.kill ( pid, ps.SIGINT )
    ps.kill ( pid, ps.SIGINT )
    lpc.wait ( pid )
end

function ControlNodeRef:stop_remote ( addr, pid )
    local remote_cmd = "/usr/bin/kill_remote " .. pid .. " --INT -n 2"
    local ssh, exit_code = misc.execute ( "ssh", "root@" .. addr, remote_cmd )
    if ( exit_code == 0 ) then
        return true, nil
    else
        return false, ssh
    end
end

function ControlNodeRef:init_experiments ( command, args, ap_names, is_fixed )
    print ( "Init Experiments" )

    local ret = self.rpc.init_experiment ( command, args, ap_names, is_fixed )

    local all_rates = copy_map ( self.rpc.get_txrates () )
    for name, rates in pairs ( all_rates ) do 
        local rate_indices_fname = self.output_dir .. "/" .. name .. "/txrate_indices.txt"
        misc.write_table ( rates, rate_indices_fname )
    end

    local all_powers = copy_map ( self.rpc.get_txpowers () )
    for ap_name, powers in pairs ( all_powers ) do
        local power_indices_fname = self.output_dir .. "/" .. ap_name .. "/txpower_indices.txt"
        misc.write_table ( powers, power_indices_fname )
    end

    return ret
end

function ControlNodeRef:run_experiments ( command, args, ap_names, is_fixed )

    function check_mem ( mem, name )
        -- local warn_threshold = 40960
        local warn_threshold = 10240
        local error_threshold = 8192
        -- local error_threshold = 20280
        if ( mem < error_threshold ) then
            print ( name .. " is running out of memory. stop here" )
            return false
        elseif ( mem < warn_threshold ) then
            print ( name .. " has low memory." )
        end
        return true
    end

    print ()

    self.stats = {}

        --[[
        for _, ap_ref in ipairs ( self.ap_refs ) do
            local free_m = ap_ref:get_free_mem ()
            if ( check_mem ( free_m, ap_ref.name ) == false ) then
                return false
            end
            for _, sta_ref in ipairs ( ap_ref.refs ) do
                local free_m = sta_ref:get_free_mem ()
                if ( check_mem ( free_m, sta_ref.name ) == false ) then
                    return false
                end
            end
        end
        --]]

    -- choose smallest set of keys
    -- fixme: still differs over all APs maybe
    -- better each ap should run its own set of keys

    local keys = self.rpc.get_keys ()
    pprint ( self.rpc.get_keys () )
    local min_len = # ( keys [ 1 ] )
    local key_index = 1
    for i, key_list in ipairs ( keys ) do
        if ( #key_list < min_len ) then
            min_len = #key_list
            key_index = i
        end
    end

    local stop = false
    local counter = 1

    -- randomize keys
    -- TODO: randomize ap and station order
    -- TODO: save ordering
    local keys_random = {}
    math.randomseed ( os.time() )
    local set = {}
    while table_size ( keys_random ) < table_size ( keys [ key_index ] ) do

        local nxt = math.random (1, table_size ( keys [ key_index ] ) )
        if ( set [ nxt ] ~= true ) then
            set [ nxt ] = true
            keys_random [ #keys_random + 1 ] = keys [ key_index ] [ nxt ]
        end

    end

    local ret = true
    -- run expriments
    print ( "Run " .. min_len .. " experiments." )

    for _, key in ipairs ( keys_random ) do 
        local exp_header = "* Start experiment " .. counter .. " of " .. min_len
                            .. " with key " .. ( key or "none" ) .. " *"
        print ( exp_header )

        ret = self.rpc.run_experiment ( command, args, ap_names, is_fixed, key, counter, min_len )

        print ("* Transfer Measurement Result *")
        local stats = self.rpc.get_stats ()
        for ref_name, stats in pairs ( stats ) do
            if ( self.stats [ ref_name ] == nil ) then
                self.stats [ ref_name ] = {}
                self.stats [ ref_name ] [ 'cpusage_stats' ] = {}
                self.stats [ ref_name ] [ 'rc_stats' ] = {}
                self.stats [ ref_name ] [ 'regmon_stats' ] = {}
                self.stats [ ref_name ] [ 'tcpdump_pcaps' ] = {}
            end
            merge_map ( stats [ 'cpusage_stats' ] , self.stats [ ref_name ] [ 'cpusage_stats' ] )
            merge_map ( stats [ 'rc_stats' ] , self.stats [ ref_name ] [ 'rc_stats' ] )
            merge_map ( stats [ 'regmon_stats' ] , self.stats [ ref_name ] [ 'regmon_stats' ] )
            merge_map ( stats [ 'tcpdump_pcaps' ] , self.stats [ ref_name ] [ 'tcpdump_pcaps' ] )
        end

        counter = counter + 1
    end

    return ret

end
