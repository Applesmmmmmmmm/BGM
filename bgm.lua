addon.name      = 'bgm'
addon.author    = 'Apples_mmmmmmmm'
addon.version   = '1.0'
addon.desc      = [[/bgm to open a GUI to manage music]]
addon.link    = '';

require('common');
local imgui = require('imgui');
local chat = require('chat');
local ffi = require('ffi');
local bgm_data = require('bgm_data');
local manager_settings = require('settings');
local manager_packet = AshitaCore:GetPacketManager();
local manager_party = AshitaCore:GetMemoryManager():GetParty();

local loggedIn = nil;

--region packet_in_structs (s->c)
--0x000A GP_SERV_COMMAND_LOGIN
ffi.cdef[[
    // PS2: GP_SERV_POS_HEAD
    typedef struct
    {
        uint32_t            UniqueNo;           // PS2: UniqueNo
        uint16_t            ActIndex;           // PS2: ActIndex
        uint8_t             padding06;          // PS2: (Removed; was SendFlg.)
        int8_t              dir;                // PS2: dir
        float               x;                  // PS2: x
        float               z;                  // PS2: y
        float               y;                  // PS2: z
        uint32_t            flags1;             // PS2: (Multiple fields; bits.)
        uint8_t             Speed;              // PS2: Speed
        uint8_t             SpeedBase;          // PS2: SpeedBase
        uint8_t             HpMax;              // PS2: HpMax
        uint8_t             server_status;      // PS2: server_status
        uint32_t            flags2;             // PS2: (Multiple fields; bits.)
        uint32_t            flags3;             // PS2: (Multiple fields; bits.)
        uint32_t            flags4;             // PS2: (Multiple fields; bits.)
        uint32_t            BtTargetID;         // PS2: BtTargetID
    } GP_SERV_POS_HEAD;

    // PS2: SAVE_LOGIN_STATE
    typedef enum
    {
        SAVE_LOGIN_STATE_NONE           = 0,
        SAVE_LOGIN_STATE_MYROOM         = 1,
        SAVE_LOGIN_STATE_GAME           = 2,
        SAVE_LOGIN_STATE_POLEXIT        = 3,
        SAVE_LOGIN_STATE_JOBEXIT        = 4,
        SAVE_LOGIN_STATE_POLEXIT_MYROOM = 5,
        SAVE_LOGIN_STATE_END            = 6
    } SAVE_LOGIN_STATE;

    // PS2: GP_MYROOM_DANCER
    typedef struct
    {
        uint16_t            mon_no;             // PS2: mon_no
        uint16_t            face_no;            // PS2: face_no
        uint8_t             mjob_no;            // PS2: mjob_no
        uint8_t             hair_no;            // PS2: hair_no
        uint8_t             size;               // PS2: size
        uint8_t             sjob_no;            // PS2: sjob_no
        uint32_t            get_job_flag;       // PS2: get_job_flag
        int8_t              job_lev[16];        // PS2: job_lev
        uint16_t            bp_base[7];         // PS2: bp_base
        int16_t             bp_adj[7];          // PS2: bp_adj
        int32_t             hpmax;              // PS2: hpmax
        int32_t             mpmax;              // PS2: mpmax
        uint8_t             sjobflg;            // PS2: sjobflg
        uint8_t             unknown41[3];       // PS2: (New; did not exist.)
    } GP_MYROOM_DANCER_PKT;

    // PS2: SAVE_CONF
    typedef struct
    {
        uint32_t            unknown00[3];       // PS2: (Multiple fields; bits.)
    } SAVE_CONF_PKT;

    // PS2: GP_SERV_LOGIN
    typedef struct
    {
        uint16_t                id: 9;
        uint16_t                size: 7;
        uint16_t                sync;

        GP_SERV_POS_HEAD        PosHead;            // PS2: PosHead
        uint32_t                ZoneNo;             // PS2: ZoneNo
        uint32_t                ntTime;             // PS2: ntTime
        uint32_t                ntTimeSec;          // PS2: ntTimeSec
        uint32_t                GameTime;           // PS2: GameTime
        uint16_t                EventNo;            // PS2: EventNo
        uint16_t                MapNumber;          // PS2: MapNumber
        uint16_t                GrapIDTbl[9];       // PS2: GrapIDTbl
        uint16_t                MusicNum[5];        // PS2: MusicNum
        uint16_t                SubMapNumber;       // PS2: SubMapNumber
        uint16_t                EventNum;           // PS2: EventNum
        uint16_t                EventPara;          // PS2: EventPara
        uint16_t                EventMode;          // PS2: EventMode
        uint16_t                WeatherNumber;      // PS2: WeatherNumber
        uint16_t                WeatherNumber2;     // PS2: WeatherNumber2
        uint32_t                WeatherTime;        // PS2: WeatherTime
        uint32_t                WeatherTime2;       // PS2: WeatherTime2
        uint32_t                WeatherOffsetTime;  // PS2: WeatherOffsetTime
        uint32_t                ShipStart;          // PS2: ShipStart
        uint16_t                ShipEnd;            // PS2: ShipEnd
        uint16_t                IsMonstrosity;      // PS2: (New; did not exist.)
        SAVE_LOGIN_STATE        LoginState;         // PS2: LoginState
        char                    name[16];           // PS2: name
        int32_t                 certificate[2];     // PS2: certificate
        uint16_t                unknown9C;          // PS2: (New; did not exist.)
        uint16_t                ZoneSubNo;          // PS2: (New; did not exist.)
        uint32_t                PlayTime;           // PS2: PlayTime
        uint32_t                DeadCounter;        // PS2: DeadCounter
        uint8_t                 MyroomSubMapNumber; // PS2: (New; did not exist.)
        uint8_t                 unknownA9;          // PS2: (New; did not exist.)
        uint16_t                MyroomMapNumber;    // PS2: MyroomMapNumber
        uint16_t                SendCount;          // PS2: SendCount
        uint8_t                 MyRoomExitBit;      // PS2: MyRoomExitBit
        uint8_t                 MogZoneFlag;        // PS2: MogZoneFlag
        GP_MYROOM_DANCER_PKT    Dancer;             // PS2: Dancer
        SAVE_CONF_PKT           ConfData;           // PS2: ConfData
        uint32_t                Ex;                 // PS2: (New; did not exist.)
    } GP_SERV_COMMAND_LOGIN;
]];

--0x001D GP_SERV_COMMAND_ITEM_SAME (Inventory Update)
ffi.cdef[[
    typedef struct
    {
        uint16_t    id: 9;
        uint16_t    size: 7;
        uint16_t    sync;

        uint8_t     State;          // PS2: State
        uint8_t     padding05[3];   // PS2: (New; did not exist.)
        uint32_t    Flags;          // PS2: (New; did not exist.)
    } GP_SERV_ITEM_SAME;
]];

--0x005F GP_SERV_COMMAND_MUSIC
ffi.cdef[[
    // PS2: GP_SERV_COMMAND_MUSIC
    typedef struct
    {
        uint16_t    id: 9;
        uint16_t    size: 7;
        uint16_t    sync;

        uint16_t    Slot;       // PS2: Slot
        uint16_t    MusicNum;   // PS2: MusicNum
    } GP_SERV_COMMAND_MUSIC;
]];

--0x0060 GP_SERV_MUSICVOLUME
ffi.cdef[[
    // PS2: GP_SERV_MUSICVOLUME
    typedef struct
    {
        uint16_t    id: 9;
        uint16_t    size: 7;
        uint16_t    sync;

        uint16_t    time;   // PS2: (New; did not exist.)
        uint16_t    volume; // PS2: (New; did not exist.)
    } GP_SERV_MUSICVOLUME;
]];
--endregion



---@class settings_default
---@field music_ID_at_slot_type     table   music_type -> {name, music_id, is_overridden}
---@field music_zone_overrides      table   ZoneID -> MusicTypeID -> MusicID. Stores specific overrides that have been created.
---@field is_override_all_loop      boolean Whether the music set to overrideAll others should loop.
---@field is_override_all_random    boolean Whether the music set to overrideAll others should move to a random selection when finished.
---@field volume_bgm_config         number  Config setting of BGM Volume (0-100)
---@field volume_sfx_config         number  Config setting of SFX Volume (0-100)
---@field imgui_is_open             boolean Determines whether the imgui window should show.
---@field imgui_is_hidden           boolean Determines if the imgui window should be hidden, in situations like the map being open, even if [imgui_is_open](lua://settings_default.imgui_is_open) is true.
local settings_default = T{
    ---0 Music ID during day, non-combat, non-mounted
    ---1 Music ID during night, non-combat, non-mounted
    ---2 Music ID during combat, solo
    ---3 Music ID during combat, party
    ---4 Music ID while mounted
    ---5 Music ID while dead.
    ---6 Music ID while in mog house.
    ---7 Music ID while fishing.
    ---8 Music ID to override all other music IDs with.
    music_ID_at_slot_type = T{[0] = {name = 'Zone - Day',        music_ID = -1, is_overridden = false},
                             [1] = {name = 'Zone - Night',      music_ID = -1, is_overridden = false},
                             [2] = {name = 'Battle - Solo',     music_ID = -1, is_overridden = false},
                             [3] = {name = 'Battle - Party',    music_ID = -1, is_overridden = false},
                             [4] = {name = 'Mount',             music_ID = -1, is_overridden = false},
                             [5] = {name = 'Dead',              music_ID = -1, is_overridden = false},
                             [6] = {name = 'Mog House',         music_ID = -1, is_overridden = false},
                             [7] = {name = 'Fishing',           music_ID = -1, is_overridden = false},
                             [8] = {name = 'Override All',      music_ID = -1, is_overridden = false},
                        };
    music_zone_overrides    = T{},

    is_override_all_oop     = false,    --TODO: implement, implement imgui
    is_override_all_random  = false,    --TODO: implement, implement imgui

    volume_bgm_config = 50,         --TODO: implement
    volume_sfx_config = 50,         --TODO: implement

    imgui_is_open = false,
    imgui_is_hidden = false,
};

---@class settings_current: settings_default
local settings_current = T{
};

local function SetZoneSpecificMusicOverrideForMusicType(music_id, music_type)
    local zoneID = manager_party:GetMemberZone(0)
    if(settings_current.music_zone_overrides[zoneID] and settings_current.music_zone_overrides[zoneID]) then
        settings_current.music_zone_overrides[zoneID][music_type] = music_id;
    else
        settings_current.music_zone_overrides[zoneID] = T{};
        settings_current.music_zone_overrides[zoneID][music_type] = music_id;
    end
end

local function UpdateZoneSpecificMusicOverrides()
    local zoneID = manager_party:GetMemberZone(0)
    for i = 0, 3 do
        local zone_override = settings_current.music_zone_overrides[zoneID] and settings_current.music_zone_overrides[zoneID][0] or nil;
        if(zone_override) then
            settings_current.music_ID_at_slot_type[i].music_id = zone_override;
            settings_current.music_ID_at_slot_type[i].is_overridden = true;
        else
            settings_current.music_ID_at_slot_type[i].is_overridden = false;
        end
    end
end

---Sets a specific music types override flag to true, and sets the song ID for that type.
---@param music_id number The music ID you want to override the current music with.
---@param music_type number The music type you want to override with a specific song.
local function SetMusicIDOverrideForMusicType(music_id, music_type)
    local packet = ffi.cast('GP_SERV_COMMAND_MUSIC*', {});
    local op_code = 0x05F;
    packet.id = op_code;
    packet.size = 0x08;
    packet.sync = 0x0000;
    packet.MusicNum = music_id;
    packet.Slot = music_type;

    settings_current.music_ID_at_slot_type[music_type].is_overridden = true;
    settings_current.music_ID_at_slot_type[music_type].music_id = music_id;
    manager_packet:AddIncomingPacket(op_code, packet);
    if (music_type >= 1 and music_type <= 3) then
        SetZoneSpecificMusicOverrideForMusicType(music_id, music_type);
    end
    --TODO: Check if we're currently playing the music_type that was requested to change, and if so then send the packet to update our current song. Otherwise, don't since we don't want to force the music_type to something different unless it's the global override.
    --  We need is_in_combat, is_fishing, is_dead, is_battle, is_party, is_day to properly handle which music is playing already.
    --  We'll also want to check the positives first, like fishing, mounted, dead, party, battle, before the negatives not party and battle, not battle is_day
    --manager_packet:AddIncomingPacket(op_code, packet);
end

--region config_volume_functions
    local config = T{
        get     = nil,
        set     = nil,
    };

    --Getters/Setters typedef
    ffi.cdef[[
        typedef int32_t (__cdecl* get_config_value_t)(int32_t);
        typedef int32_t (__cdecl* set_config_value_t)(int32_t, int32_t);
    ]];

    local function GetVolumeSFX()
        if(not config.get) then
            print("Failed to get volume, get function invalid pointer");
            return;
        end
        return tonumber(config.get(9));
    end

    local function GetVolumeBGM()
        if(not config.get) then
            print("Failed to get volume, get function invalid pointer");
            return;
        end

        return tonumber(config.get(10));
    end

    --min:0, max:100, default:100
    local function SetVolumeSFX(newVol)
        if(not config.set) then	print("Failed to set volume, set function invalid pointer"); return; end
        if(not newVol) then print("Failed to set volume, newVol nil"); return; end
        newVol = tonumber(newVol);
        config.set(9, math.clamp(newVol, 0, 100));
    end

    --min:0, max:100, default:100
    local function SetVolumeBGM(newVol)
        if(not config.set) then	print("Failed to set volume, set function invalid pointer"); return; end
        if(not newVol) then print("Failed to set volume, newVol nil"); return; end
        newVol = tonumber(newVol);
        config.set(10, math.clamp(newVol, 0, 100));
    end

    local function InitConfigFunctions()
        -- Obtain the needed function pointers..
        local ptr = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????85C974??8B44240450E8????????C383C8FFC3', 0, 0);
        config.get = ffi.cast('get_config_value_t', ptr);
        config.set = ffi.cast('set_config_value_t', ashita.memory.find('FFXiMain.dll', 0, '85C974??8B4424088B5424045052E8????????C383C8FFC3', -6, 0));
        assert(config.get ~= nil, chat.header('config'):append(chat.error('Error: Failed to locate required \'get\' function pointer.')));
        assert(config.set ~= nil, chat.header('config'):append(chat.error('Error: Failed to locate required \'set\' function pointer.')));
    end
--endregion


ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if(e.id == 0x000A) then --GP_SERV_COMMAND_LOGIN
        UpdateZoneSpecificMusicOverrides();
        local packet = ffi.cast('GP_SERV_COMMAND_LOGIN*', e.data_modified_raw);
        if(settings_current.music_ID_at_slot_type[8].is_overridden) then
            for i = 0, 4 do
                packet.MusicNum[i] = settings_current.music_ID_at_slot_type[8].music_id;
            end
        else
            for i = 0, 4 do
                if(settings_current.music_ID_at_slot_type[i].is_overridden) then
                    packet.MusicNum[i] = settings_current.music_ID_at_slot_type[i].music_id;
                end
            end

            --if(packet.LoginState == ffi.cast('SAVE_LOGIN_STATE', 'SAVE_LOGIN_STATE_MYROOM')) then
            if(packet.LoginState == ffi.C.SAVE_LOGIN_STATE_MYROOM) then
                print("moghouse")
                --SetMusicIDOverrideForMusicType()
            end
        end
    elseif (e.id == 0x001D) then --GP_SERV_COMMAND_ITEM_SAME (Inventory Update)

    elseif (e.id == 0x005F) then --GP_SERV_COMMAND_MUSIC
        local packet = ffi.cast('GP_SERV_COMMAND_MUSIC*', e.data_modified_raw);
        if(settings_current.music_ID_at_slot_type[packet.Slot].is_overridden) then
            print("Music Request ["..settings_current.music_ID_at_slot_type[packet.Slot].name.."] ("..bgm_data.songs_sorted_by_index[settings_current.music_ID_at_slot_type[packet.Slot].music_id]..")");
            packet.MusicNum = settings_current.music_ID_at_slot_type[packet.Slot].music_id;
        end
    elseif(e.id == 0x0060) then --GP_SERV_MUSICVOLUME
        local packet = ffi.cast('GP_SERV_MUSICVOLUME*', e.data_modified_raw);
        packet.time = 0;
    end
end);

ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args();

    if (args[1]:lower() == "/bgm") then
		settings_current.imgui_is_open = not settings_current.imgui_is_open;
        return true;
    else
        return false;
    end;
end);

ashita.events.register('load', 'load_cb', function ()
    InitConfigFunctions();
    local sfx = GetVolumeSFX();
    local bgm = GetVolumeBGM();
    settings_default.imgui_volume_sfx_config = sfx and sfx or 50;
    settings_default.imgui_volume_bgm_config = bgm and bgm or 50;
    settings_current = manager_settings.load(settings_default);
    SetVolumeSFX(settings_current.volume_sfx_config);
    SetVolumeBGM(settings_current.volume_bgm_config);
end);

ashita.events.register('unload', 'unload_cb', function ()
    manager_settings.save();
end);

local save_after_timer_end = false;
local time_until_save_initial = 2;
local time_until_save_current = os.clock();

ashita.events.register('d3d_present', 'present_cb', function ()
    if(save_after_timer_end and os.clock() > time_until_save_current) then
        manager_settings.save();
        save_after_timer_end = false;
    end

    if(not settings_current.imgui_is_open or settings_current.imgui_is_hidden) then
        return;
    end

    --TODO: IMGUI
    local imgui_is_open = {settings_current.imgui_is_open}
    imgui:SetNextWindowSize({0,0}, {500, 500});
    imgui.Begin('BGM', imgui_is_open, 0);
    local settings_current_save_outdated = false;

    --region volume_sliders
    local volume_sfx = {settings_current.volume_sfx_config};
    local volume_bgm = {settings_current.volume_bgm_config};
    imgui.SliderInt('Volume (SFX)', volume_sfx, 0, 100);
    local is_active_slider_volume_sfx = imgui.IsItemActive();
    imgui.SliderInt('Volume (BGM)', volume_bgm, 0, 100);
    local is_active_slider_volume_bgm = imgui.IsItemActive();
    if(volume_sfx[1] ~= settings_current.volume_sfx_config) then
        settings_current.volume_sfx_config = volume_sfx[1]
        SetVolumeSFX(settings_current.volume_sfx_config);
        settings_current_save_outdated = true;
    end
    if(volume_bgm[1] ~= settings_current.volume_bgm_config) then
        settings_current.volume_bgm_config = volume_bgm[1]
        SetVolumeBGM(settings_current.volume_bgm_config)
        settings_current_save_outdated = true;
    end

    --Check if the UI is active at all, and if so keep the save flag dirty.
    if(is_active_slider_volume_bgm or is_active_slider_volume_sfx) then
        settings_current_save_outdated = true;
    end

    if(settings_current_save_outdated) then
        save_after_timer_end = true;
        time_until_save_current = os.clock() + time_until_save_initial;
    end
    --endregion
    imgui.End();
    settings_current.imgui_is_open = imgui_is_open[1];
    --TODO (Maybe): Check time the initial time the player enters a zone, so we can send zoneDay/zoneNight music for those who want it instead of moghouse.
end);