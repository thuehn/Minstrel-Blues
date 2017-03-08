
require ("rpc")
require ("lpc")
require ('Net')
require ('NetIF')

ControlNodeRef = { name
                 , ctrl
                 , output_dir
                 }

function ControlNodeRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ControlNodeRef:create( name, ctrl_if, ctrl_ip, output_dir, is_fixed )
    -- ctrl node iface, ctrl node (name) lookup
    local ctrl_net = NetIF:create ( ctrl_if )
    ctrl_net.addr = ctrl_ip
    if ( ctrl_net.addr == nil) then
        local ip_addr = Net.lookup ( name )
        if ( ip_addr ~= nil ) then
            ctrl_net.addr = ip_addr
        end 
    end

    local o = ControlNodeRef:new { name = name, ctrl = ctrl_net, output_dir = output_dir, is_fixed = is_fixed }
    return o
end

function ControlNodeRef:start ( log_net, ctrl_port, log_port )
    local cmd = "lua bin/runControl.lua"
                 .. " --port " .. ctrl_port 
                 .. " --ctrl_if " .. self.ctrl.iface
                 .. " --output " .. self.output_dir
                 .. " --enable_fixed " .. self.is_fixed
    if ( log_net.iface ~= nil ) then
        cmd = cmd .. " --log_if " .. log_net.iface
    end

    if ( log_net.addr ~= nil and log_port ~= nil ) then
        cmd = cmd .. " --log_ip " .. log_net.addr 
                  .. " --log_port " .. log_port 
    end
    print ( remote_cmd )
    local pid, _, _ = lpc.run ( cmd )
    print ( "Control: " .. pid )
    return pid
end

function ControlNodeRef:start_remote ( log_net, ctrl_port, log_port )
    local remote_cmd = "lua bin/runControl.lua"
                 .. " --port " .. ctrl_port 
                 .. " --ctrl_if " .. self.ctrl.iface
                 .. " --output " .. self.output_dir
                 .. " --enable_fixed " .. self.is_fixed
    if ( log_net.iface ~= nil ) then
        remote_cmd = remote_cmd .. " --log_if " .. log_net.iface
    end

    if ( log_net.addr ~= nil and log_port ~= nil ) then
        remote_cmd = remote_cmd .. " --log_ip " .. log_net.addr 
                 .. " --log_port " .. log_port 
    end
    print ( remote_cmd )
    local pid, _, _ = lpc.run ( "ssh root@" .. self.ctrl.addr .. remote_cmd)
    return pid
end

function ControlNodeRef:connect ( ctrl_port )

    function connect_control_rpc ()
        local l, e = rpc.connect ( self.ctrl.addr, ctrl_port )
        return l, e
    end

    if rpc.mode ~= "tcpip" then
        print ( "Err: rpc mode tcp/ip is supported only" )
        return nil
    end

    local status
    local err
    local slave
    local retrys = 5
    repeat
        status, slave, err = pcall ( connect_control_rpc )
        retrys = retrys -1
        if ( status == false ) then os.sleep (1) end
    until status == true or retrys == 0
    if (status == false) then
        print ( "Err: Connection to control node failed" )
        print ( "Err: no node at address: " .. self.ctrl.addr .. " on port: " .. ctrl_port )
        return nil
    end
    return slave
end

function ControlNodeRef:stop ( pid )
    ps.kill ( pid, ps.SIGINT )
end

function ControlNodeRef:stop_remote ( addr, pid )
    local ssh, exit_code = os.execute ( "ssh root@" .. addr .. " kill " .. pid )
    if ( exit_code == 0 ) then
        return true, nil
    else
        return false, ssh
    end
end
