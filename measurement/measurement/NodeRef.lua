require ('NetIF')

NodeRef = { name = nil
          , ctrl = nil
          , rpc = nil
          , wifis = nil
          , stations = nil
          }

function NodeRef:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function NodeRef:create ( name, ctrl )
local o = NodeRef:new({ name = name, ctrl = ctrl, wifis = {} })
    return o
end

function NodeRef:add_wifi ( phy )
    self.wifis [ #self.wifis + 1 ] = phy
end

function NodeRef:add_station ( mac )
    self.stations [ #self.stations + 1 ] = mac
end

function NodeRef:__tostring() 
    local out = ""
    out = out .. self.name .. " :: " 
          .. "ctrl: " .. tostring ( self.ctrl ) .. "\n\t"
          .. "wifis: "
    if ( self.wifis == {} ) then
        out = out .. " none"
    else
        for i, wifi in ipairs ( self.wifis ) do
            if ( i ~= 1 ) then out = out .. ", " end
            out = out .. wifi
        end
    end
    return out        
end
