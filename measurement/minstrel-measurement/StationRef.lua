require ('NodeRef')

StationRef = NodeRef:new()

function StationRef:create ( name, ctrl, rsa_key, output_dir, mac )
    local o = StationRef:new { name = name
                             , ctrl = ctrl
                             , rsa_key = rsa_key
                             , output_dir = output_dir
                             , ap_ref = nil
                             , is_passive = mac ~= nil
                             }
    -- stations with configured mac doesn't run lua measurment node
    -- is_passive for later diffrentiation
    if ( mac ~= nil ) then
        o.macs [ "phy0" ] = mac
        o.phys = { "phy0" }
    else
        o.ctrl:get_addr()
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
        macs [ 1 ] = self.ap_ref:get_mac()
    end
    return macs
end
