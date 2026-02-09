addon.name      = 'bgm'
addon.author    = 'Apples_mmmmmmmm'
addon.version   = '1.0'
addon.desc      = [[/bgm to open a GUI to manage music]]
addon.link    = '';

require('common');
local ffxi_time = require('ffxi.time');
local imgui = require('imgui');
local chat = require('chat');
local ffi = require('ffi');
local bgm_data = require('bgm_data');
local manager_settings = require('settings');
local manager_packet = AshitaCore:GetPacketManager();
local manager_party = AshitaCore:GetMemoryManager():GetParty();

local startedInMoghouse = nil;
local startIsDaytime = nil;

---@class settings_default
---@field music_0_day             number Music ID during day, non-combat, non-mounted
---@field music_1_night           number Music ID during night, non-combat, non-mounted
---@field music_2_solo            number Music ID during combat, solo
---@field music_3_party           number Music ID during combat, party
---@field music_4_mount           number Music ID while mounted
---@field music_5_dead            number Music ID while dead.
---@field music_6_mog_house       number Music ID while in mog house.
---@field music_7_fishing         number Music ID while fishing.
---@field volume_bgm_config     number Config setting of BGM Volume (0-100)
---@field volume_sfx_config     number Config setting of SFX Volume (0-100)
local settings_default = T{
    music_0_day       = -1,
    music_1_night     = -1,
    music_2_solo      = -1,
    music_3_party     = -1,
    music_4_mount     = -1,
    music_5_dead      = -1,
    music_6_mog_house = -1,
    music_7_fishing   = -1,

    overrideMoghouse = false,
    overrideDeath = false,
    overrideFishing = false,
    overrideNight = false,

    volume_bgm_config = 50,
    volume_sfx_config = 50,
};

---@class settings_current: settings_default
local settings_current = T{
};

--region config_volume_functions
    local config = T{
        get     = nil,
        set     = nil,
    };

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
    } GP_SERV_LOGIN;
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

ashita.events.register('packet_in', 'packet_in_cb', function(e)

    if(e.id == 0x000A) then --GP_SERV_COMMAND_LOGIN
        local packet = ffi.cast('GP_SERV_COMMAND_LOGIN*', e.data_modified_raw);
        packet.MusicNum[0] = settings_current.music_0_day;
        packet.MusicNum[1] = settings_current.music_1_night;
        packet.MusicNum[2] = settings_current.music_2_solo;
        packet.MusicNum[3] = settings_current.music_3_party;
        packet.MusicNum[4] = settings_current.music_4_mount;
        if(packet.LoginState == packet.SAVE_LOGIN_STATE_MYROOM) then
            print("moghouse")
        end

    elseif (e.id == 0x001D) then --GP_SERV_COMMAND_ITEM_SAME (Inventory Update)

    elseif (e.id == 0x005F) then --GP_SERV_COMMAND_MUSIC
        local packet = ffi.cast('GP_SERV_COMMAND_MUSIC*', e.data_modified_raw);
        if     packet.Slot == 0 then packet.MusicNum = settings_current.music_0_day;
        elseif packet.Slot == 1 then packet.MusicNum = settings_current.music_1_night;
        elseif packet.Slot == 2 then packet.MusicNum = settings_current.music_2_solo;
        elseif packet.Slot == 3 then packet.MusicNum = settings_current.music_3_party;
        elseif packet.Slot == 4 then packet.MusicNum = settings_current.music_4_mount;
        elseif packet.Slot == 5 then packet.MusicNum = settings_current.music_5_dead;
        elseif packet.Slot == 6 then packet.MusicNum = settings_current.music_6_mog_house;
        elseif packet.Slot == 7 then packet.MusicNum = settings_current.music_7_fishing;
        end
    elseif(e.id == 0x0060) then --GP_SERV_MUSICVOLUME
        local packet = ffi.cast('GP_SERV_MUSICVOLUME*', e.data_modified_raw);
        packet.time = 0;
    end
end);

ashita.events.register('load', 'load_cb', function ()
    settings_current = manager_settings.load(settings_default, "ver_1+");
    InitConfigFunctions();
end);


ashita.events.register('d3d_present', 'present_cb', function ()
    --TODO: IMGUI

    --TODO: Check time the initial time the player enters a zone, so we can send zoneDay/zoneNight music for those who want it instead of moghouse.
    --ffxi_time.get_game_hours()
end);