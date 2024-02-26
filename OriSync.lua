/*
    OriSync v2 for GameSense (Counter-Strike: Global Offensive), by Ori (https://gamesense.pub/forums/profile.php?id=12351)
    
    -- TODO:
        -- Finish the implemention of the player class
        -- Implement the rage_bot class
        -- Implement the anti_aim class
        -- Implement the render class
        -- Implement the menu and config classes
        -- Handle callbacks

    -- Known bugs:
*/

-- Cache frequently used _G[*], string.* & table.* functions for performance
local require, error, pairs, ipairs, getfenv, pcall, getmetatable, setmetatable, vtable_bind, vtable_thunk, toticks = require, error, pairs, ipairs, getfenv, pcall, getmetatable, setmetatable, vtable_bind, vtable_thunk, toticks

-- Cache frequently used string.* functions for performance
local string_byte, string_char, string_find, string_format, string_gmatch, string_gsub, string_len, string_lower, string_match, string_rep, string_reverse, string_sub, string_upper =string.byte, string.char, string.find, string.format, string.gmatch, string.gsub, string.len, string.lower, string.match, string.rep, string.reverse, string.sub, string.upper

-- Cache frequently used table.* functions for performance
local table_remove = table.remove

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
        local success, result = pcall(result, v[1])
        if success then _ENV[v[2]] = result else error(v[3]) end
    end
end

-- Cache frequently used ffi.* functions for performance
local ffi_typeof, ffi_cast = ffi.typeof, ffi.cast

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
    };
]])

-- Initialize virtual functions
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
    local globals_absoluteframetime, globals_chokedcommands, globals_commandack, globals_curtime, globals_framecount, globals_frametime, globals_lastoutgoingcommand, globals_mapname, globals_maxplayers, globals_oldcommandack, globals_realtime, globals_servertickcount, globals_tickcount, globals_tickinterval = globals.absoluteframetime, globals.chokedcommands, globals.commandack, globals.curtime, globals.framecount, globals.frametime, globals.lastoutgoingcommand, globals.mapname, globals.maxplayers, globals.oldcommandack, globals.realtime, globals.servertickcount, globals.tickcount, globals.tickinterval

    local gv = {
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

    -- @constructor 'new_entity'
    -- @param entindex: number
    -- @return player: metatable
    local new_entity = function(entindex)
        return entindex and setmetatable({ [1] = entindex }, entity)
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
        return function(...) return entity_new(func()) end
    end



    -- @function 'player.get_local_player'
    -- @return player: metatable
    player.get_local_player = get_wrapper(entity_get_local_player)
    
    -- @function 'player.get_player_resource'
    -- @return player: metatable
    player.get_player_resource = get_wrapper(entity_get_player_resource)

    -- @function 'player:is_alive'
    -- @return is_alive: boolean
    function player:is_alive()
        return entity_is_alive(self[1])
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
        if getmetatable(array_index) then
            array_index = array_index[1]
        end

        return array_index and entity_set_prop(self[1], propname, value, array_index) or entity_set_prop(self[1], propname, value)
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
    
    -- @function 'player:get_client_entity'
    function player:get_client_entity()
        return native_GetClientEntity(self[1])
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
        
    end

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
    local screen_size = vector()
end

-- @class 'callbacks'
local callbacks = {} do
end
