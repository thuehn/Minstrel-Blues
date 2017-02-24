
require ("rpc")
require ("spawn_pipe")
require ("parsers/ex_process")
require ('net')
require ('NetIF')

ControlNodeRef = { name
                 , ctrl
                 }

function ControlNodeRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ControlNodeRef:create( name, ctrl_if, ctrl_ip )
    -- ctrl node iface, ctrl node (name) lookup
    local ctrl_net = NetIF:create ( ctrl_if )
    ctrl_net.addr = ctrl_ip
    if ( ctrl_net.addr == nil) then
        local ip_addr = Net.lookup ( name )
        if ( ip_addr ~= nil ) then
            ctrl_net.addr = ip_addr
        end 
    end

    local o = ControlNodeRef:new ( { name = name, ctrl = ctrl_net } )
    return o
end

function ControlNodeRef:start ( log_net, ctrl_port, log_port )
    local ctrl = spawn_pipe ( "lua", "bin/runControl.lua"
                            , "--port", ctrl_port
                            , "--ctrl_if", self.ctrl.iface
                            , "--log_if", log_net.iface
                            , "--log_ip", log_net.addr
                            , "--log_port", log_port 
                            )
    if ( ctrl ['err_msg'] ~= nil ) then
        self:send_warning("Control not started" .. ctrl ['err_msg'] )
    end
    close_proc_pipes ( ctrl )
    local str = ctrl['proc']:__tostring()
    local proc = parse_process ( str ) 
    print ( "Control: " .. str )
    return proc
end

function ControlNodeRef:start_remote ( log_net, ctrl_port, log_port )
     local remote_cmd = "lua bin/runControl.lua"
                 .. " --port " .. ctrl_port 
                 .. " --ctrl_if " .. self.ctrl.iface
     if ( log_net.iface ~= nil ) then
        remote_cmd = remote_cmd .. " --log_if " .. log_net.iface
     end

     if ( log_net.addr ~= nil and log_port ~= nil ) then
        remote_cmd = remote_cmd .. " --log_ip " .. log_net.addr 
                 .. " --log_port " .. log_port 
     end
     print ( remote_cmd )
     local ssh = spawn_pipe("ssh", "root@" .. self.ctrl.addr, remote_cmd)
     close_proc_pipes ( ssh )
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
    kill = spawn_pipe("kill", "-2", pid)
    close_proc_pipes ( kill )
end

function ControlNodeRef:stop_remote ( addr, pid )
    local ssh = spawn_pipe("ssh", "root@" .. addr, "kill " .. pid )
    local exit_code = ssh['proc']:wait()
    close_proc_pipes ( ssh )
end
