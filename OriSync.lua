-- Cache frequently used _G[*], string.* & table.* functions for performance
local require, error, pairs, ipairs, getfenv, pcall, getmetatable, setmetatable, vtable_bind, vtable_thunk, tostring, tonumber, toticks = require, error, pairs, ipairs, getfenv, pcall, getmetatable, setmetatable, vtable_bind, vtable_thunk, tostring, tonumber, toticks

-- Cache frequently used string.* functions for performance
local string_byte, string_char, string_find, string_format, string_gmatch, string_gsub, string_len, string_lower, string_match, string_rep, string_reverse, string_sub, string_upper =string.byte, string.char, string.find, string.format, string.gmatch, string.gsub, string.len, string.lower, string.match, string.rep, string.reverse, string.sub, string.upper

-- Cache frequently used table.* functions for performance
local table_clear, table_concat, table_foreach, table_foreachi, table_getn, table_insert, table_maxn, table_move, table_pack, table_remove, table_sort, table_unpack = table.clear, table.concat, table.foreach, table.foreachi, table.getn, table.insert, table.maxn, table.move, table.pack, table.remove, table.sort, table.unpack

-- Cache frequently used math.* functions for performance
local math_abs, math_acos, math_asin, math_atan, math_atan2, math_ceil, math_cos, math_cosh, math_deg, math_exp, math_floor, math_fmod, math_frexp, math_ldexp, math_log, math_log10, math_max, math_min, math_modf, math_pow, math_rad, math_random, math_randomseed, math_sin, math_sinh, math_sqrt, math_tan, math_tanh = math.abs, math.acos, math.asin, math.atan, math.atan2, math.ceil, math.cos, math.cosh, math.deg, math.exp, math.floor, math.fmod, math.frexp, math.ldexp, math.log, math.log10, math.max, math.min, math.modf, math.pow, math.rad, math.random, math.randomseed, math.sin, math.sinh, math.sqrt, math.tan, math.tan

-- Dependencies
local ffi = require "ffi"
local vector = require "vector" -- The holy vector library

local _ENV, dependencies = getfenv(), {
    { "gamesense/pui", "pui", "https://gamesense.pub/forums/viewtopic.php?id=41761" }, --  pui — ui library by enQ (https://gamesense.pub/forums/profile.php?id=14919)
    { "gamesense/msgpack", "msgpack", "https://gamesense.pub/forums/viewtopic.php?id=42280" }, -- mshpack by enQ (https://gamesense.pub/forums/profile.php?id=14919)
    { "gamesense/base64", "base64", "https://gamesense.pub/forums/viewtopic.php?id=21619" }, -- Base64 encode / decode library by sapphyrus (https://gamesense.pub/forums/profile.php?id=561)
    { "gamesense/clipboard", "clipboard", "https://gamesense.pub/forums/viewtopic.php?id=28678" } -- Clipboard API by sapphyrus (https://gamesense.pub/forums/profile.php?id=561)
} do
    for k, v in ipairs(dependencies) do
        local success, result = pcall(require, v[1])
        if success then _ENV[v[2]] = result else error(v[3]) end
    end
end

-- Cache frequently used ffi.* functions for performance
local ffi_abi, ffi_alignof, ffi_cast, ffi_cdef, ffi_copy, ffi_errno, ffi_fill, ffi_gc, ffi_istype, ffi_metatype, ffi_new, ffi_offsetof, ffi_sizeof, ffi_string, ffi_typeinfo, ffi_typeof = ffi.abi, ffi.alignof, ffi.cast, ffi.cdef, ffi.copy, ffi.errno, ffi.fill, ffi.gc, ffi.istype, ffi.metatype, ffi.new, ffi.offsetof, ffi.sizeof, ffi.string, ffi.typeinfo, ffi.typeof

-- Define playerinfo_t: replica of the struct from https://gitlab.com/KittenPopo/csgo-2018-source/-/blob/main/public/cdll_int.h#L161
local playerinfo_t, playerinfo_mt = ffi_typeof([[
    struct {
        uint64_t version;
        uint64_t __xuid;
        char __name[128];
        int userID;
        char __guid[33];
        unsigned int friendsID;
        char __friendsName[128];
        bool fakeplayer;
        bool ishltv;
        unsigned int customFiles[4];
        unsigned char filesDownloaded;
    }
]]), {}

-- Define animationlayer_t: replica of the struct from https://gitlab.com/KittenPopo/csgo-2018-source/-/blob/main/game/client/animationlayer.h#L71
local animationlayer_t = ffi_typeof([[
    struct {
        char pad_0x0000[0x18];
        uint32_t sequence;
        float prev_cycle;
        float weight;
        float weight_delta_rate;
        float playback_rate;
        float cycle;
        void* entity;
        char pad_0x0038[0x4];
    }**
]])

-- Initialize virtual functions
local native_GetPlayerInfo = vtable_bind("engine.dll", "VEngineClient014", 8, "bool(__thiscall*)(void*, int, $*)", playerinfo_t)
local native_GetClientEntity = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

-- @class 'config'
local config = {} do
    -- Metatable properties
    config.__index = config
    config.__metatable = "config"

    -- @constructor 'config.new'
    -- @param preset: table
    -- @return config: metatable
    config.new = function(preset)
        return setmetatable({ [1] = pui.setup(preset) }, config)
    end

    -- @function 'config:import'
    -- @param preset: table
    function config:import()
        local preset = clipbaord.get()
        self[1]:load(preset)
    end
    
    -- @function 'config:export'
    function config:export()
        local data = self[1]:save()
        clipboard.set(data)
    end
end

-- @class 'menu'
local menu = {} do
end

-- @class 'globalvars'
local globalvars = {} do
    -- @Metatable properties
    globalvars.__index = globalvars
    globalvars.__metatable = "globalvars"

    -- @private
    local client_latency, client_real_latency, globals_absoluteframetime, globals_chokedcommands, globals_commandack, globals_curtime, globals_framecount, globals_frametime, globals_lastoutgoingcommand, globals_mapname, globals_maxplayers, globals_oldcommandack, globals_realtime, globals_servertickcount, globals_tickcount, globals_tickinterval = client.latency, client.real_latency, globals.absoluteframetime, globals.chokedcommands, globals.commandack, globals.curtime, globals.framecount, globals.frametime, globals.lastoutgoingcommand, globals.mapname, globals.maxplayers, globals.oldcommandack, globals.realtime, globals.servertickcount, globals.tickcount, globals.tickinterval

    local gv = {
        latency = client_latency,
        real_latency = client_real_latency,
        absoluteframetime = globals_absoluteframetime,
        chokedcommands = globals_chokedcommands,
        commandack = globals_commandack,
        curtime = globals_curtime,
        framecount = globals_framecount,
        frametime = globals_frametime,
        lastoutgoingcommand = globals_lastoutgoingcommand,
        mapname = globals_mapname,
        maxplayers = globals_maxplayers,
        oldcommandack = globals_oldcommandack,
        realtime = globals_realtime,
        servertickcount = globals_servertickcount,
        tickcount = globals_tickcount,
        tickinterval = globals_tickinterval
    }

    -- 'globalsvars:_index metamethod'
    function globalvars:__index(index)
        return gv[index]()
    end

    -- @constructor 'globalvars.new'
    -- @return globalvars: metatable
    globalvars.new = function()
        return setmetatable(globalvars, globalvars)
    end
end

local gv = globalvars.new()

-- @class 'player'
local player = {} do
    -- @Metatable properties
    player.__index = player
    player.__tostring = function(self) return string_format("%d", self[1]) end
    player.__eq = function(a, b) return a[1] == b[1] end
    player.__metatable = "player"

    -- @private
    local entity_get_all, entity_get_bounding_box, entity_get_classname, entity_get_esp_data, entity_get_game_rules, entity_get_local_player, entity_get_origin, entity_get_player_name, entity_get_player_resource, entity_get_player_weapon, entity_get_players, entity_get_prop, entity_get_steam64, entity_hitbox_position, entity_is_alive, entity_is_dormant, entity_is_enemy, entity_new_prop, entity_set_prop = entity.get_all, entity.get_bounding_box, entity.get_classname, entity.get_esp_data, entity.get_game_rules, entity.get_local_player, entity.get_origin, entity.get_player_name, entity.get_player_resource, entity.get_player_weapon, entity.get_players, entity.get_prop, entity.get_steam64, entity.hitbox_position, entity.is_alive, entity.is_dormant, entity.is_enemy, entity.new_prop, entity.set_prop

    local player_info = {
        xuid = function(self) return string_match(tostring(self.__xuid), "%d+") end,
        name = function(self) return ffi_string(self.__name, 128) end,
        uid = function(self) return string_match(tostring(self.userID), "%d+") end,
        guid = function(self) return ffi_string(self.__guid, 33) end,
        friends_id = function(self) return string_match(tostring(self.friendsID), "%d+") end,
        friends_name = function(self) return ffi_string(self.__friendsName, 128) end,
        is_fake_player = function(self) return tostring(self.fakeplayer) end,
        is_hltv = function(self) return tostring(self.ishltv) end,

        custom_files = function(self)
            local files = self.customFiles
            return { files[0], files[1], files[2], files[3] }
        end
    }

    function playerinfo_mt:__index(index)
        return player_info[index](self)
    end

    ffi_metatype(playerinfo_t, playerinfo_mt)

    -- @constructor 'new_player'
    -- @param entindex: number
    -- @return player: metatable
    local new_player = function(entindex)
        return entindex and setmetatable({ [1] = entindex }, player)
    end

    -- @deconstructor 'player:get_entindex'
    -- @return entindex: number
    function player:get_entindex()
        return self[1]
    end

    -- @function 'get_wrapper'
    -- @param func: function
    -- @return wrapper: function
    local get_wrapper = function(func)
        return function(...) return new_player(func()) end
    end

    -- @function 'player.get_all'
    -- @return classname entities: table
    player.get_all = function(classname)
        local ret = {}

        local entities = classname and entity_get_all(classname) or entity_get_all()

        for i = 1, #entities do
            ret[i] = new_player(entities[i])
        end

        return ret
    end

    -- @function 'player.get_players'
    -- @return players: table
    player.get_players = function(enemies_only, include_dormant)
        local ret = {}
        local player_resource = entity_get_player_resource()

        for i = 1, gv.maxplayers do
            if (not enemies_only or entity_is_enemy(i)) and (include_dormant or not entity_is_dormant(i)) and entity_get_prop(player_resource, "m_bAlive", i) == 1 then ret[#ret + 1] = new_player(i) end
        end

        return ret
    end

    -- @function 'player.get_local_player'
    -- @return player: metatable
    player.get_local_player = get_wrapper(entity_get_local_player)
    
    -- @function 'player.get_player_resource'
    -- @return player: metatable
    player.get_player_resource = get_wrapper(entity_get_player_resource)

    -- @function 'player.get_game_rules'
    -- @return player: metatable
    player.get_game_rules = get_wrapper(entity_get_game_rules)

    -- @function 'player:is_alive'
    -- @return is_alive: boolean
    function player:is_alive()
        return entity_is_alive(self[1])
    end

    -- @function 'player:is_enemy'
    -- @return is_enemy: boolean
    function player:is_enemy()
        return entity_is_enemy(self[1])
    end

    -- @function 'player:is_dormant'
    -- @return is_dormant: boolean
    function player:is_dormant()
        return entity_is_dormant(self[1])
    end

    -- @function 'player:get_prop'
    -- @param propname: string
    -- @param array_index: number / player
    -- @return prop: number / vector
    function player:get_prop(propname, array_index)
        if array_index then
            array_index = getmetatable(array_index) == "player" and array_index[1] or array_index
            return entity_get_prop(self[1], propname, array_index)
        else
            return entity_get_prop(self[1], propname)
        end
    end

    -- @function 'player:set_prop'
    -- @param propname: string
    -- @param value: number
    -- @param array_index: number / player
    function player:set_prop(propname, value, array_index)
        if getmetatable(array_index) == "player" then
            array_index = array_index[1]
        end

        return array_index and entity_set_prop(self[1], propname, value, array_index) or entity_set_prop(self[1], propname, value)
    end

    -- @function 'player:get_steam64'
    -- @return steamid: number
    function player:get_steam64()
        return entity_get_steam64(self[1])
    end

    -- @function 'player:get_classname'
    -- @return classname: string
    function player:get_classname()
        return entity_get_classname(self[1])
    end

    -- @function 'player:get_player_name'
    -- @return playername: string
    function player:get_player_name()
        return entity_get_player_name(self[1])
    end

    -- @function 'player:get_player_weapon'
    -- @return player: metatable
    function player:get_player_weapon()
        return new_player(entity_get_player_weapon(self[1]))
    end

    -- @function 'player:get_esp_data'
    -- @return esp_data: table
    function player:get_esp_data()
        return entity_get_esp_data(self[1])
    end

    -- @function 'player:get_flags'
    -- @return flags: table
    function player:get_flags()
        return entity_get_prop(self[1], "m_fFlags")
    end

    -- @function 'player:get_duck_amount'
    function player:get_duck_amount()
        return entity_get_prop(self[1], "m_flDuckAmount")
    end

    -- @function 'player:get_origin'
    -- @param interpolated: boolean
    -- @return origin: vector
    function player:get_origin(interpolated)
        return interpolated and vector(entity_get_origin(self[1])) or vector(entity_get_prop(self[1], "m_vecOrigin"))
    end

    -- @function 'player:hitbox_position'
    -- @param hitbox: number
    -- @return hitbox_position: vector
    function player:hitbox_position(hitbox)
        return vector(entity_hitbox_position(self[1], hitbox))
    end

    -- @function 'player:get_velocity'
    -- @param td: boolean / nil
    -- @return velocity: [nil: vector, false: 2d, true: 3d]
    function player:get_velocity(td)
        local velocity = vector(entity_get_prop(self[1], "m_vecVelocity"))
        return velocity == nil and velocity or (td and velocity:length() or velocity:length2d())
    end

    -- @function 'player:get_eye_pos'
    -- @return origin: vector
    function player:get_eye_pos()
        local origin = vector(entity_get_prop(self[1], "m_vecOrigin"))
        origin.z = origin.z + entity_get_prop(self[1], "m_vecViewOffset[2]")

        return origin
    end

    -- @function 'player:get_bounding_box'
    -- @return: pos1, pos2, alpha_multiplier: vector, vector, number
    function player:get_bounding_box()
        local x1, y1, x2, y2, alpha_multiplier = entity_get_bounding_box(self[1])
        return vector(x1, y1), vector(x2, y2), alpha_multiplier
    end
    
    -- @function 'player:get_client_entity'
    function player:get_client_entity()
        return native_GetClientEntity(self[1])
    end

    -- @function 'player:get_player_info'
    -- @return playerinfo: table
    function player:get_player_info()
        local out = playerinfo_t(0xFFFFFFFFFFFFF002ULL)
        if native_GetPlayerInfo(self[1], out) then return out end
    end

    -- @function 'player:get_previous_simtime'
    -- @return previous simulation time: number
    function player:get_previous_simtime()
        local ent_ptr = ffi_cast("void***", native_GetClientEntity(self[1]))
        return ffi_cast("float*", ent_ptr + 0x26C)[0]
    end

    -- @function 'player:get_defensive_state'
    -- @return defensive state: boolean
    function player:get_defensive_state()
        local tickcount = gv.tickcount

        local simtime = toticks(entity_get_prop(self[1], "m_flSimulationTime"))
        local diff = simtime - toticks(self:get_previous_simtime())

        if diff < 0 then
            return (tickcount + math_abs(diff) - toticks(gv.latency)) > tickcount
        end

        return false
    end

    -- @function 'player:get_animation_layer'
    -- @param layer: number
    -- @return animation layer: animationlayer_t
    function player:get_animation_layer(layer)
        local ent_ptr = ffi_cast("void***", native_GetClientEntity(self[1]))
        return ffi_cast(animationlayer_t, ffi_cast("char*", ent_ptr) + 0x2980)[0][layer]
    end
end

-- @class 'rage_bot'
local rage_bot = {} do
end

-- @class 'anti_aim'
local anti_aim = {} do
end

-- @class 'render'
local render = {} do
    -- @Metatable properties
    render.__index = render
    render.__metatable = "render"

    -- @private
    local client_screen_size, renderer_blur, renderer_circle, renderer_circle_outline, renderer_gradient, renderer_indicator, renderer_line, renderer_load_jpg, renderer_load_png, renderer_load_svg, renderer_measure_text, renderer_rectangle, renderer_text, renderer_texture, renderer_triangle, renderer_world_to_screen = client.screen_size, renderer.blur, renderer.circle, renderer.circle_outline, renderer.gradient, renderer.indicator, renderer.line, renderer.load_jpg, renderer.load_png, renderer.load_svg, renderer.measure_text, renderer.rectangle, renderer.text, renderer.texture, renderer.triangle, renderer.world_to_screen

    local render_text = function(x, y, r, g, b, a, flags, text)
        local w, h = renderer_measure_text(flags, text)
        renderer_text(x, y, r, g, b, a, flags, w * h, text)
    end

    -- @constructor 'render.get_screen_size'
    -- @return render: metatable
    render.get_screen_size = function()
        local screen_size = vector(client_screen_size()) * 0.5
        return setmetatable({ [1] = screen_size }, render)
    end

    render.text2 = function(x, y, r, g, b, a, flags, text)
        render_text(x, y, r, g, b, a, flags, text)
    end

    function render:text(r, g, b, a, flags, text)
        local x, y = self[1]:unpack()        
        render_text(x, y, r, g, b, a, flags, text)
    end
end

-- @class 'callbacks'
local callbacks = {} do
end
