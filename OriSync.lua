/*
    -- OriSync v2 for GameSense (Counter-Strike: Global Offensive), by Ori (https://gamesense.pub/forums/profile.php?id=12351)
    
    -- TODO:
    -- Finish the implemention of the player class
    -- Implement the rage_bot class
    -- Implement the anti_aim class
    -- Implement the render class
    -- Handle callbacks
    -- Implement the menu and config classes

    -- Known bugs:
*/

-- Cache frequently used _G[*], string.* & table.* functions for performance
local require, error, pairs, ipairs, getfenv, pcall, getmetatable, setmetatable, vtable_bind, vtable_thunk, string_format, table_remove = require, error, pairs, ipairs, getfenv, pcall, getmetatable, setmetatable, vtable_bind, vtable_thunk, string.format, table.remove

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
    }
]])

-- Initialize virtual functions
local native_GetClientEntity = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

-- @class 'player'
local player = {} do
    -- @Metatable properties
    player.__index = player
    player.__tostring = function(self) return string_format("%d", self[1]) end
    player.__eq = function(a, b) return a[1] == b[1] end
    player.__metatable = "player"

    -- @private
    local entity_get_local_player, entity_get_player_resource, entity_is_alive, entity_get_prop, entity_set_prop = entity.get_local_player, entity.get_player_resource, entity.is_alive, entity.get_prop, entity.set_prop

    -- @constructor 'new_entity'
    -- @param entindex: number
    -- @return player: metatable
    local new_entity = function(entindex)
        return entindex and setmetatable({ [1] = entindex }, entity)
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
    function player:set_prop(propname, value, array_index)
        if getmetatable(array_index) then
            array_index = array_index[1]
        end

        return array_index and entity_set_prop(self[1], propname, value, array_index) or entity_set_prop(self[1], propname, value)
    end
    
    function player:get_client_entity()
        return native_GetClientEntity(self[1])
    end

    function player:get_previous_simtime()
        local ent_ptr = ffi_cast("void***", native_GetClientEntity(self[1]))
        return ffi_cast("float*", ent_ptr + 0x26C)[0]
    end

    function player:get_defensive_state()
        
    end

    function player:get_animation_layer(layer)
        local ent_ptr = ffi_cast("void***", native_GetClientEntity(self[1]))
        return ffi_cast(animationlayer_t, ffi_cast("char*", ent_ptr) + 0x2980)[0][layer]
    end
end
