require ('misc')
require ('parsers/radiotap')

local pprint = require ('pprint')
local misc = require ('misc')

FXsnrAnalyser = { aps = nil
                , stas = nil
                }

function FXsnrAnalyser:new (o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function FXsnrAnalyser:create ( aps, stas )
    local o = FXsnrAnalyser:new( { aps = aps, stas = stas } )
    return o
end

-- duplicate of experiment:get_rate
function FXsnrAnalyser:get_rate( key )
    return split ( key, "-" ) [1]
end

-- duplicate of experiment:get_rate
function FXsnrAnalyser:get_power( key )
    return split ( key, "-" ) [2]
end

function FXsnrAnalyser:min ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local min = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v < min ) then min = v end
    end
    return min
end

function FXsnrAnalyser:max ( t )
    if ( t == nil ) then return nil end
    if ( table_size ( t ) == 0 ) then return nil end
    if ( table_size ( t ) == 1 ) then return t [1] end
    local max = t[1]
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' and v > max ) then max = v end
    end
    return max
end

function FXsnrAnalyser:avg ( t )
    local sum = 0
    local count = 0
    
    for _, v in ipairs ( t ) do
        if ( v ~= nil and type ( v ) == 'number' ) then
            sum = sum + v
            count = count + 1
        end
    end
    return ( sum / count )
end

function FXsnrAnalyser:read_ssid ( dir, name )
    local ssid = nil
    local fname = dir .. "/" .. name .. "/ssid.txt"
    local file = io.open ( fname )
    if ( file ~= nil ) then
        local content = file:read ( "*a" )
        if ( content ~= nil ) then
            ssid = string.sub ( content, 1, #content - 1 )
        end
        file:close()
    end
    return ssid
end

function FXsnrAnalyser:write_snrs ( fname, snrs )
    local file = io.open ( fname, "w" )
    if ( file ~= nil ) then
        for i, snr in ipairs ( snrs ) do
            if ( i ~= 1 ) then file:write( "," ) end
            file:write ( snr )
        end
        file:close ()
    end
end

function FXsnrAnalyser:read_snrs ( fname )
    local snrs = {}
    local file = io.open ( fname, "r" )
    if ( file ~= nil ) then
        local snrs_str = split ( file:read ( "*a" ), "," )
        for _, snr in ipairs ( snrs_str ) do
            snrs [ #snrs + 1 ] = tonumber ( snr )
        end
        file:close ()
    end
    return snrs
end

function FXsnrAnalyser:calc_snrs_stats ( snrs, power, rate )
    local ret = {}
    if ( table_size ( snrs ) > 0 ) then
        local unique_snrs = misc.Set_count ( snrs )
        for snr, count in pairs ( unique_snrs ) do
            print ( "antenna signal: " .. snr, count )
        end

        ret [ power .. "-" .. rate .. "-MIN" ] = self:min ( snrs )
        ret [ power .. "-" .. rate .. "-MAX" ] = self:max ( snrs )
        ret [ power .. "-" .. rate .. "-AVG" ] = misc.round ( self:avg ( snrs ) )
    end
    return ret
end

-- Filter for all data frames:              wlan.fc.type == 2
-- Filter for Data:                         wlan.fc.type_subtype == 32
-- Filter for QoS Data:                     wlan.fc.type_subtype == 40
-- Filter by the source address (SA):       wlan.sa == MAC_address
-- Filter by the destination address (DA):  wlan.da == MAC_address
-- TODO: filter port, i.e udp 12000
-- radiotap.dbm_antsignal

function FXsnrAnalyser:snrs_tshark ( measurement )
    local ret = {}

    local base_dir = measurement.output_dir .. "/" .. measurement.node_name
    local tshark_bin = "/usr/bin/tshark"

    for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        local snrs_fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-snrs.txt"
        local snrs = {}
        if ( isFile ( snrs_fname ) == false ) then
            if ( table_size ( split ( key, "-" ) ) < 3 ) then
                print ( "ERROR: unsupported key encoding" )
                break
            end
            local fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            print ( fname )
            -- run tshark
            -- measurement.node_mac
            -- measurement.opposite_macs
            -- note: for tshark the mac of the bridge is used for wlan.sa and wlan.da and not the
            --       mac address of the interface
            --       use wlan.ta and wlan.ra instead or use bridge mac
            local filter = "\""
            filter = filter .. "wlan.fc.type==2 and ( ( "
            if ( measurement.opposite_macs ~= nil and measurement.opposite_macs ~= {} ) then
                filter = filter .. " ( "
            end
            for i, mac in ipairs ( measurement.opposite_macs ) do
                if ( i ~= 1 ) then filter = filter .. " or " end
                filter = filter .. "wlan.ra==" .. mac
            end
            if ( measurement.opposite_macs ~= nil and measurement.opposite_macs ~= {} ) then
                filter = filter .. " ) "
            end
            filter = filter .. "and wlan.ta==" .. measurement.node_mac
            filter = filter .. " ) or ( "
            filter = filter .. "wlan.ra==" .. measurement.node_mac
            if ( measurement.opposite_macs ~= nil and measurement.opposite_macs ~= {} ) then
                filter = filter .. " and ( "
            end
            for i, mac in ipairs ( measurement.opposite_macs ) do
                if ( i ~= 1 ) then filter = filter .. " or " end
                filter = filter .. "wlan.ta==" .. mac
            end
            if ( measurement.opposite_macs ~= nil and measurement.opposite_macs ~= {} ) then
                filter = filter .. " ) ) )"
            end
            --filter = filter .. "and radiotap.length==62"
            filter = filter .. "\""
            local content, exit_code = Misc.execute ( tshark_bin, "-r", fname, "-Y", filter, "-T",  "fields"
                                                    , "-e", "radiotap.dbm_antsignal" )
            print ( tshark_bin .. " -r " .. fname .. " -Y " .. filter .. " -T " .. "fields" .. " -e " .. "radiotap.dbm_antsignal" )
            if ( exit_code ~= 0 ) then
                print ("tshark error: " .. exit_code )
            else
                print ("tshark:" .. content )
            end
        else
            print ( snrs_fname )
            snrs = self:read_snrs ( snrs_fname )
        end

        local rate = self:get_rate ( key )
        local power = self:get_power ( key )
        local snrs_stats = self:calc_snrs_stats ( snrs, power, rate )
        merge_map ( snrs_stats, ret )
    end

    return ret
end

-- returns list of SNRs stats (MIN/MAX/AVG) for each measurement
-- stored in map indexed by a string concatenated by power and rate 
-- and MIN/MAX/AVG seperated by "-"
function FXsnrAnalyser:snrs ( measurement )
    local ret = {}
    
    local frame_type_data = PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_DATA" ] - 1
    local frame_subtype_data = PCAP.radiotap_data_frametype [ "DATA" ] - 1
    local frame_subtype_qos = PCAP.radiotap_data_frametype [ "QOS_DATA" ] - 1
    local frame_type_ctrl = PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_CTRL" ] - 1
    local frmae_subtype_blockack = PCAP.radiotap_ctrl_frametype [ "80211_BLOCK_ACK" ] - 1

    local base_dir = measurement.output_dir .. "/" .. measurement.node_name

    for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        local snrs_fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-snrs.txt"
        local snrs = {}
        if ( isFile ( snrs_fname ) == false ) then
            if ( table_size ( split ( key, "-" ) ) < 3 ) then
                print ( "ERROR: unsupported key encoding" )
                break
            end
            local fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            print ( fname )
            --local ssid_m = self:read_ssid ( measurement.output_dir, measurement.node_name )

            local rest
            local pos
            local file

            file, rest, pos = PCAP.open ( fname )

            if ( file ~= nil ) then
                print ( os.time() )
                while ( string.len ( rest ) > 0 ) do
                
                    local packet_length
                    local radiotap_header
                    local radiotap_data

                    packet_length, rest, pos = PCAP.parse_packet_header ( rest, pos )
                    radiotap_header, rest, pos = PCAP.parse_radiotap_header ( rest, pos )
                    radiotap_data, rest, pos = PCAP.parse_radiotap_data ( rest, pos, packet_length, radiotap_header [ 'it_len' ] )

                    --local ssid = radiotap_data [ 'ssid' ]
                    local frame_type = radiotap_data [ 'type' ]
                    local frame_subtype = radiotap_data [ 'subtype' ]
                    local sa = PCAP.mac_tostring ( radiotap_data [ 'sa' ] )
                    local da = PCAP.mac_tostring ( radiotap_data [ 'da' ] )

                    if ( ( ( da == measurement.node_mac and misc.index_of ( sa, measurement.opposite_macs ) ~= nil )
                            or ( misc.index_of ( da, measurement.opposite_macs ) ~= nil and sa == measurement.node_mac ) )
                        and ( ( frame_type == frame_type_data
                             and ( frame_subtype == frame_subtype_data or frame_subtype == frame_subtype_qos ) )
                          or ( frame_type == frame_type_ctrl and ( frame_subtype == frame_subtype_blockack ) ) ) ) then

                        local antenna_signal = radiotap_header ['antenna_signal']
                        if ( antenna_signal ~= nil ) then
                            snrs [ #snrs + 1 ] = antenna_signal
                        end
                    end
                end
                print ( os.time() )
                print ( #snrs .. " read" )
                file:close()
            else
                print ("FXsnrAnalyser: pcap open failed: " .. fname)
            end
            self:write_snrs ( snrs_fname, snrs )
            print ( os.time () )
        else
            print ( snrs_fname )
            snrs = self:read_snrs ( snrs_fname )
        end

        local rate = self:get_rate ( key )
        local power = self:get_power ( key )
        local snrs_stats = self:calc_snrs_stats ( snrs, power, rate )
        merge_map ( snrs_stats, ret )
    end

    return ret
end
