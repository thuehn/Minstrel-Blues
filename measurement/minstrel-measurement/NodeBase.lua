
require ('rpc')
local ps = require ('posix.signal') --kill
local unistd = require ('posix.unistd') -- getpid
local misc = require ('misc')
local net = require ('Net')
local uci = require ('Uci')

local pprint = require ('pprint')

require ('parsers/proc_version')
require ('parsers/free')
local json = require ('cjson')

require ('LogNodeRef')

NodeBase = { name = nil
           , lua_bin = nil
           , ctrl = nil
           , port = nil
           , log_port = nil
           , log_addr = nil
           , proc_version = nil
           , log_ref = nil
           }

function NodeBase:new ( o )
    local o = o or {}
    setmetatable (o, self)
    self.__index = self
    o.log_ref = LogNodeRef:create ( o.log_addr, o.log_port )
    return o
end

function NodeBase:get_proc_version ()
    if ( self.proc_version == nil ) then
        local fname = "/proc/version"
        local file = io.open ( fname )
        local line = file:read ( "*l" )
        self.proc_version = parse_proc_version ( line )
        file:close()
    end
end

function NodeBase:run ()
    self:get_proc_version ()
    self:send_info ( self.proc_version:__tostring() )
    self:set_cut ()
    local os_release = self.get_os_release ()
    if ( os_release ~= nil ) then
        self:send_info ( os_release )
    end
    return net.run ( self.port
                   , self.name
                   , function ( msg ) self:send_info ( msg ) end
                   )
end

function NodeBase:set_nameserver (  nameserver )
    set_resolvconf ( nameserver )
end

-- -------------------------
-- known_host file
-- -------------------------

function NodeBase:host_known ( host )
    local dig, _ = net.lookup ( host )
    local fname = os.getenv ( "HOME" ) .. "/.ssh/known_hosts"
    if ( isFile ( fname ) == true ) then
        local file = io.open ( fname, "r" )
        if ( file ~= nil ) then
            local content = file:read ( "*a" )
            for _, line in ipairs ( split ( content, "\n" ) ) do
                if ( string.sub ( line, 1, string.len ( host ) ) == host
                    or ( dig ~= nil and ( ( dig.addr ~= nil and string.sub ( line, 1, string.len ( dig.addr ) ) == dig.addr ) ) ) ) then
                    return true
                end
            end
        end
    end
    return false
end

-- -------------------------
-- hardware
-- -------------------------

function NodeBase:get_board ()
    if ( self.proc_version.system == "LEDE" ) then
        local fname = "/etc/board.json"
        if ( isFile ( fname ) ) then
            local file = io.open ( fname, "r" )
            local content = file:read ( "*a" )
            local tab = json.decode( content )
            file:close ()
            return tab [ 'model' ] [ 'id' ]
                .. " " .. tab [ 'model' ] [ 'name' ]
        end
    else
        local fname = "/sys/devices/virtual/dmi/id/product_version"
        if ( isFile ( fname ) ) then
            local file = io.open ( fname, "r" )
            local content = file:read ( "*a" )
            file:close ()
            return content
        end
    end
    return nil
end

-- -------------------------
-- software
-- -------------------------

function NodeBase:get_os_release()
    local fname = "/etc/os-release"
    if ( isFile ( fname ) ) then
        local file = io.open ( fname, "r" )
        local content = file:read ( "*a" )
        file:close ()
        return content
    end
    return nil
end

-- -------------------------
-- memory consumption
-- -------------------------

function NodeBase:get_free_mem ()
    local content = misc.execute ( "free" )
    if ( content ~= nil ) then
        local free = parse_free ( content )
        return free.free, nil
    else
        return nil, free_str
    end
end

-- -------------------------
-- timezone / date
-- -------------------------

function NodeBase:set_timezone ( timezone )
    local var = "system.@system[0].zonename"
    if ( timezone ~= nil ) then return uci.set_var ( var, timezone ) end
    return false
end

function NodeBase:set_date ( year, month, day, hour, min, second )
    if ( self.proc_version.system == "LEDE" ) then
        -- use busybox date
        return set_date_bb ( year, month, day, hour, min, second )
    else
        -- use coreutile date
        return set_date_core ( year, month, day, hour, min, second )
    end
end

-- -------------------------
-- posix
-- -------------------------

function NodeBase.parent_pid ( pid )
    local file = io.open ( "/proc/" .. pid .. "/status" )

    if ( file ~= nil ) then
        repeat
            local line = file:read ("*line")
            if ( line ~= nil and string.sub ( line, 1, 5 ) == "PPid:" ) then
                return tonumber ( string.sub ( line, 6 ) )
            end
        until not line
        file:close ()
    end
    return nil
end

function NodeBase:get_pid()
    local lua_pid = unistd.getpid()
    return lua_pid
end

-- kill child process of lua by pid
-- if process with pid is not a child of lua
-- then return nil
-- otherwise the exit code of kill is returned
function NodeBase:kill ( pid, signal )
    local lua_pid = unistd.getpid()
    if ( self.parent_pid ( pid ) == lua_pid ) then
        if ( signal ~= nil ) then
            ps.kill ( pid, signal )
            ps.kill ( pid, signal )
        else
            ps.kill ( pid )
            ps.kill ( pid )
        end
        return true
    else 
        self:send_warning ( "try to kill pid " .. pid )
        return false
    end
end

-- -------------------------
-- Logging
-- -------------------------

function NodeBase:set_cut ()
    if ( self.log_ref ~= nil ) then
        self.log_ref:set_cut ()
    end
end

function NodeBase:send_error ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_error ( self.name, msg )
    end
end

function NodeBase:send_info ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_info ( self.name, msg )
    end
end

function NodeBase:send_warning ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_warning ( self.name, msg )
    end
end

function NodeBase:send_debug ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_debug ( self.name, msg )
    end
end
