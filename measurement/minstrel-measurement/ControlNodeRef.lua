
local posix = require ('posix') -- sleep
require ("rpc")
require ("lpc")
local misc = require 'misc'
local net = require ('Net')
require ('NetIF')

ControlNodeRef = { name = nil
                 , ctrl = nil
                 , rpc = nil
                 , output_dir = nil
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

    local o = ControlNodeRef:new { name = name, ctrl = ctrl_net, output_dir = output_dir }
    return o
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
                         function ( msg ) self:send_error ( msg ) end )
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
