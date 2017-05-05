require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl_if, rsa_key, output_dir, mac, log_addr, log_port )
    local ctrl_net_ref = NetIfRef:create ( ctrl_if )

    local o = StationRef:new { name = name
                             , ctrl_net_ref = ctrl_net_ref
                             , rsa_key = rsa_key
                             , output_dir = output_dir
                             , ap_ref = nil
                             , is_passive = mac ~= nil
                             , passive_mac = mac
                             , log_addr = log_addr
                             , log_port = log_port
                             }
    ctrl_net_ref:set_addr ( name )

    -- stations with configured mac doesn't run lua measurment node
    -- is_passive for later diffrentiation
    if ( mac ~= nil ) then
        o.radios [ "phy0" ] = NetIfRef:create ( nil, nil, nil, "phy0" )
        o.phys = { "phy0" }
    end
    return o
end

function StationRef:set_ap_ref ( ap_ref )
    self.ap_ref = ap_ref
end

-- on station the mac of the access point is returned
-- on access points all macs of linked stations are returned
function StationRef:get_opposite_macs ()
    local macs = {}
    if ( self.ap_ref ~= nil ) then
        macs [ 1 ] = self.ap_ref:get_mac ()
    end
    return macs
end

function StationRef:get_opposite_macs_br ()
    local macs = {}
    if ( self.ap_ref ~= nil ) then
        macs [ 1 ] = self.ap_ref:get_mac_br ()
    end
    return macs
end
