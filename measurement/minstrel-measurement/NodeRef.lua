
local posix = require ('posix') -- sleep
local net = require ('Net')

require ('NetIfRef')
require ('Measurements')
require ('LogNodeRef')

NodeRef = { name = nil
          , lua_bin = nil
          , ctrl_net_ref = nil
          , rsa_key = nil
          , rpc = nil
          , radios = nil
          , wifi_cur = nil
          , stats = nil
          , output_dir = nil
          , is_passive = nil
          , passive_mac = nil
          , log_addr = nil
          , log_port = nil
          , log_ref = nil
          , retries = nil
          , pids = nil
          }

function NodeRef:new (o)
    local o = o or {}
    o.radios = {}
    o.macs = {}
    o.refs = {}
    setmetatable (o, self)
    self.__index = self
    o.log_ref = LogNodeRef:create ( o.log_addr, o.log_port, o.retries )
    o.pids = {}
    return o
end

function NodeRef:connect ( ctrl_port, msg_fun )
    if ( self.is_passive == nil or self.is_passive == false ) then
        local slave = net.connect ( self.ctrl_net_ref.addr, ctrl_port, self.retries, self.name, msg_fun )
        if ( slave == nil ) then
            return false
        else
            msg_fun ( "Connected to " .. self.name )
            self:init ( slave )
        end
    end
    return true
end

function NodeRef:disconnect ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        net.disconnect ( self.rpc )
    end
end

-- pre: connected to node
-- post: phys set, macs set, addrs.set
function NodeRef:init ( rpc )
    self.rpc = rpc
    if ( self.rpc ~= nil) then
        local phys = self.rpc.phy_devices ()
        for _, phy in ipairs ( phys ) do
            local radio = NetIfRef:create ( nil, nil, nil, phy )
            self.radios [ phy ] = radio
            radio.phy = phy
            radio.iface = self.rpc.get_iface ( phy )
            radio.addr = self.rpc.get_addr ( phy )
            radio.mac = self.rpc.get_mac ( phy )
            radio.mon = self.rpc.get_mon ( phy )
        end
    end
end

function NodeRef:set_phy ( phy )
    self.wifi_cur = phy
end

function NodeRef:get_addr ()
    return self.radios [ self.wifi_cur ].addr
end

function NodeRef:get_mac ()
    return self.radios [ self.wifi_cur ].mac
end

function NodeRef:get_mac_br ()
    return self.rpc.get_mac ( self.wifi_cur, true )
end

function NodeRef:__tostring ()
    local out = ""
    out = out .. self.name .. " :: " 
          .. "ctrl: " .. tostring ( self.ctrl_net_ref ) .. "\n\t"
    if ( self.rpc ~= nil ) then
        out = out .. "rpc connected\n\t"
    else
        out = out .. "rpc not connected\n\t"
    end
    out = out .. "radios:"
    for phy, radio in pairs ( self.radios ) do
        out = out .. "\n\t\t" .. tostring ( radio )
    end
    if ( self.is_passive == true ) then
        out = out .. "passive"
    end
    return out
end

function NodeRef:is_exp_running ()
    local running = false
    for i, pid in ipairs ( self.pids ) do
        running = running or self.rpc.is_pid_running ( pid )
    end
    self:send_debug ( "NodeRef::is_exp_running : " .. tostring ( running ) )
    return running
end

-- wait for station is linked to ssid
function NodeRef:wait_linked ()
    local connected = false
    local retries = tonumber ( self.retries )
    if ( self.is_passive ~= nil and self.is_passive == true ) then
        return true
    end

    repeat
        local ssid = self.rpc.get_linked_ssid ( self.wifi_cur )
        if ( ssid == nil ) then 
            posix.sleep (1)
        else
            connected = true
        end
        retries = retries - 1
    until ( connected or retries == 0 )
    return ( retries ~= 0 )
end

function NodeRef:create_measurement ( online )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.stats = Measurements:create ( self.name, self:get_mac (), self:get_opposite_macs ()
                                        , self.rpc, self.output_dir, online )
        self.stats:set_node_mac_br ( self:get_mac_br () )
        self.stats:set_opposite_macs_br ( self:get_opposite_macs_br () )
    end
end


-- fixme: should be done on node to implement i.e. usb-storage on backbone less nodes
--function NodeRef:write_measurement ( online, finish, key )
--    self.stats:write ( online, finish, key )
--end

function NodeRef:restart_wifi ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.restart_wifi ( self.wifi_cur )
    end
end

function NodeRef:add_monitor ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.add_monitor ( self.wifi_cur )
    end
end

function NodeRef:remove_monitor ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.remove_monitor ( self.wifi_cur )
    end
end

function NodeRef:start_measurement ( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        local succ, res = self.stats:start ( self.wifi_cur, key )
        if ( succ == false ) then
            self:send_error ( "NodeRef::start_measurement: " .. ( res or "unknown" ) )
        end
    end
end

function NodeRef:stop_measurement ( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.stats:stop ( self.wifi_cur, key )
    end
end

-- collect traces
function NodeRef:fetch_measurement ( key )
    self:send_debug ( "NodeRef::fetch_measurement for key" .. ( key or "unset" ) )
    if ( self.is_passive == nil or self.is_passive == false ) then
        local stas = "none"
        if ( self.stats.stations ~= nil ) then
            stas = table_tostring ( self.stats.stations )
        end
        self:send_debug ( "stations: " .. stas )
        local succ, res = self.stats:fetch ( self.wifi_cur, key, self )
        if ( succ == false ) then
            self:send_error ( "NodeRef::fetch_measurement: " .. ( res or "unknown" ) )
        end
        self:send_debug ( self.stats:__tostring () )
        return succ, res
    end
    return true, false
end

function NodeRef:get_tcpdump_pcap ( key, from, to)
    -- lua rpc seg faults when transfering more than 10MiB data
    -- split into parts as a workaround
    if ( key == nil ) then
        return false, "NodeRef:get_tcpdump_pcap failed: key is not set"
    end
    local out
    if ( self.is_passive == nil or self.is_passive == false ) then
        self:send_debug ( "NodeRef::get_tcpdump_pcap: pcaps "
                          .. string.len ( self.stats.tcpdump_meas [ key ].stats ) .. " bytes present" )
        if ( from ~= nil and to ~= nil ) then
            out = string.sub ( self.stats.tcpdump_meas [ key ].stats, from, to ) 
            if ( to >= string.len ( out ) ) then
                self.stats.tcpdump_meas [ key ].stats = ""
            end
        else
            out = self.stats.tcpdump_meas [ key ].stats
            self.stats.tcpdump_meas [ key ].stats = ""
        end
        self:send_debug ( "NodeRef::get_tcpdump_pcap: send " .. string.len ( out ) .. " bytes for key " .. key )
        return true, out
    end
    self:send_debug ( "NodeRef::get_tcpdump_pcap: send 0 bytes" )
    return true, nil
end

function NodeRef:cleanup_measurement ( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
      return self.stats:cleanup ( self.wifi_cur, key )
    end
    return false
end

function NodeRef:start_tcp_iperf_s ( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        local phy_num = tonumber ( string.sub ( self.wifi_cur, 4 ) )
        local proc = self.rpc.start_tcp_iperf_s ( self.wifi_cur, 12000 + phy_num)
    end
end

function NodeRef:start_udp_iperf_s ( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        local phy_num = tonumber ( string.sub ( self.wifi_cur, 4 ) )
        local proc = self.rpc.start_udp_iperf_s ( self.wifi_cur, 12000 + phy_num )
    end
end

function NodeRef:stop_iperf_server ( key )
    if ( self.is_passive == nil or self.is_passive == false ) then
        local _, out = self.rpc.stop_iperf_server ( self.wifi_cur )
        self.stats.iperf_s_outs [ key ] = out
    end
end

function NodeRef:get_board ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.get_board ()
    end
end

function NodeRef:get_os_release ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.get_os_release ()
    end
end

function NodeRef:enable_wifi ( enabled )
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.enable_wifi ( enabled, self.wifi_cur )
    end
end

function NodeRef:link_to_ssid ( ssid, phy )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.link_to_ssid ( ssid, phy )
    end
end

function NodeRef:set_nameserver ( nameserver )
    if ( self.is_passive == nil or self.is_passive == false ) then
        self.rpc.set_nameserver ( nameserver )
    end
end

function NodeRef:set_date ( year, month, day, hour, minute, second )
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.set_date ( year, month, day, hour, minute, second )
    end
end

function NodeRef:check_bridge ( phy )
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.check_bridge ( phy )
    end
end

function NodeRef:get_free_mem ()
    if ( self.is_passive == nil or self.is_passive == false ) then
        return self.rpc.get_free_mem()
    end
end

-- -------------------------
-- Logging
-- -------------------------

function NodeRef:set_cut ()
    if ( self.log_ref ~= nil ) then
        self.log_ref:set_cut ()
    end
end

function NodeRef:send_error ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_error ( self.name .. "-Ref", msg )
    end
end

function NodeRef:send_info ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_info ( self.name .. "-Ref", msg )
    end
end

function NodeRef:send_warning ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_warning ( self.name .. "-Ref", msg )
    end
end

function NodeRef:send_debug ( msg )
    if ( self.log_ref ~= nil ) then
        self.log_ref:send_debug ( self.name .. "-Ref", msg )
    end
end
