require ('misc')
require ('parsers/radiotap')

local pprint = require ('pprint')
local misc = require ('misc')

require ('Analyser')

FXAnalyser = Analyser:new()

function FXAnalyser:create ( aps, stas )
    local o = FXAnalyser:new( { aps = aps, stas = stas } )
    return o
end

-- Filter for all data frames:              wlan.fc.type == 2
-- Filter for Data:                         wlan.fc.type_subtype == 32
-- Filter for QoS Data:                     wlan.fc.type_subtype == 40
-- Filter by the source address (SA):       wlan.sa == MAC_address
-- Filter by the destination address (DA):  wlan.da == MAC_address
-- TODO: filter port, i.e udp 12000
-- radiotap.dbm_antsignal

function FXAnalyser:snrs_tshark ( measurement, border, field, suffix )
    if ( border == nil ) then border = 0 end
    local ret = {}

    local base_dir = measurement.output_dir .. "/" .. measurement.node_name
    local tshark_bin = "/usr/bin/tshark"

    for key, _ in pairs ( measurement.tcpdump_meas ) do
    --for key, stats in pairs ( measurement.tcpdump_pcaps ) do
        local snrs_fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-" .. suffix .. ".txt"
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
            local filter = ""
            filter = filter .. "( ( wlan.fc.type==2 and wlan.fc.type_subtype==40 )"
            filter = filter .. " or ( wlan.fc.type==0 and wlan.fc.type_subtype==8 )"
            filter = filter .. " or ( wlan.fc.type==1 and wlan.fc.type_subtype==8 )"
            filter = filter .. " or ( wlan.fc.type==2 and wlan.fc.type_subtype==8 )"
            filter = filter .. " or ( wlan.fc.type==1 and wlan.fc.type_subtype==24 )"
            filter = filter .. " or ( wlan.fc.type==1 and wlan.fc.type_subtype==25 )"
            filter = filter .. " or ( wlan.fc.type==1 and wlan.fc.type_subtype==29 ) )"
            if ( measurement.opposite_macs ~= nil and measurement.opposite_macs ~= {} ) then
                filter = filter .. " and ( ( ( "
                for i, mac in ipairs ( measurement.opposite_macs ) do
                    if ( i ~= 1 ) then filter = filter .. " or " end
                    filter = filter .. "wlan.ra==" .. mac
                end
                filter = filter .. " ) "
            end
            if ( measurement.node_mac ~= nil ) then
                filter = filter .. "and wlan.ta==" .. measurement.node_mac
                --filter = filter .. "and wlan.ta==" .. measurement.node_mac
                filter = filter .. " ) or ( "
                filter = filter .. "wlan.ra==" .. measurement.node_mac
            end
            if ( measurement.opposite_macs ~= nil and measurement.opposite_macs ~= {} ) then
                filter = filter .. " and ( "
                --filter = filter .. " and ( "
                for i, mac in ipairs ( measurement.opposite_macs ) do
                    if ( i ~= 1 ) then filter = filter .. " or " end
                    filter = filter .. "wlan.ta==" .. mac
                end
                filter = filter .. " ) ) )"
            end
            --filter = filter .. "and radiotap.length==62"
            local content, exit_code = Misc.execute_nonblock ( nil, nil
                                                            , tshark_bin, "-r", fname, "-Y", filter
                                                            , "-T", "fields"
                                                            , "-e", field )
            --print ( tshark_bin .. " -r " .. fname .. " -Y " .. filter .. " -T " .. "fields"
            --        .. " -e " .. "radiotap.dbm_antsignal" )
            if ( exit_code ~= 0 ) then
                print ( "tshark error: " .. exit_code )
            else
                --print ("tshark:" .. content )
                local lines = split ( content, "\n" )
                local begin_interval = 1 + border
                local end_interval = table_size ( lines ) - border
                for i, line in ipairs ( lines ) do
                    if ( i >= begin_interval and i <= end_interval ) then
                        local antsignals = split ( line, "," )
                        pprint ( antsignals )
                        if ( antsignals ~= nil and #antsignals > 0
                             and antsignals [1] ~= nil and antsignals [1] ~= "" ) then
                            snrs [ #snrs + 1 ] = tonumber ( antsignals [1] )
                        end
                    end
                end
            end
            self:write ( snrs_fname, snrs )
        else
            --print ( snrs_fname )
            snrs = self:read ( snrs_fname )
        end

        local rate = self:get_rate ( key )
        local power = self:get_power ( key )
        local snrs_stats = self:calc_stats ( snrs, power, rate )
        merge_map ( snrs_stats, ret )
    end

    return ret
end

-- returns list of SNRs stats (MIN/MAX/AVG) for each measurement
-- stored in map indexed by a string concatenated by power and rate 
-- and MIN/MAX/AVG seperated by "-"
function FXAnalyser:snrs ( measurement, border )
    if ( border == nil ) then border = 0 end
    local ret = {}
    
    local frame_type_data = PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_DATA" ] - 1
    local frame_subtype_data = PCAP.radiotap_data_frametype [ "DATA" ] - 1
    local frame_subtype_qos = PCAP.radiotap_data_frametype [ "QOS_DATA" ] - 1
    local frame_type_ctrl = PCAP.radiotap_frametype [ "IEEE80211_FRAMETYPE_CTRL" ] - 1
    local frmae_subtype_blockack = PCAP.radiotap_ctrl_frametype [ "80211_BLOCK_ACK" ] - 1

    local base_dir = measurement.output_dir .. "/" .. measurement.node_name

    --for key, stats in pairs ( measurement.tcpdump_pcaps ) do
    for key, _ in pairs ( measurement.tcpdump_meas ) do
        local snrs_fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. "-snrs.txt"
        local snrs = {}
        if ( isFile ( snrs_fname ) == false ) then
            if ( table_size ( split ( key, "-" ) ) < 3 ) then
                print ( "ERROR: unsupported key encoding" )
                break
            end
            local fname = base_dir .. "/" .. measurement.node_name .. "-" .. key .. ".pcap"
            print ( fname )

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
                print ("FXAnalyser: pcap open failed: " .. fname)
            end
            self:write ( snrs_fname, snrs )
            print ( os.time () )
        else
            print ( snrs_fname )
            snrs = self:read ( snrs_fname )
        end

        local rate = self:get_rate ( key )
        local power = self:get_power ( key )
        local snrs_stats = self:calc_stats ( snrs, power, rate )
        merge_map ( snrs_stats, ret )
    end

    return ret
end
