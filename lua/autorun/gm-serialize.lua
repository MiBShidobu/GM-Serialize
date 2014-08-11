--[[
    GM-Serialize Library By MiBShidobu

    Description:
        This addon provides an API to serialize data into a small scale transferable format.
        Mainly for use by GM-Networking, opped to give it its own GitHub to be improved and modified easily.

    Credits:
        MiBShidobu - Main Developer
]]--

serialize = {
    VERSION = "1.0.0"
}

local FORMAT_APPENDAGE_START = string.char(1)
local FORMAT_APPENDAGE_INSERT = string.char(16)
local FORMAT_APPENDAGE_TERM = string.char(29)
local FORMAT_APPENDAGE_UNIT = string.char(31)

local FORMAT_TYPES_HANDLERS = {}
local FORMAT_TYPES_LOOKUP = {}

FORMAT_TYPES_HANDLERS["ANGLE"] = {
    Store = "a",
    Serialize = function (value)
        return value.pitch..FORMAT_APPENDAGE_UNIT..value.yaw..FORMAT_APPENDAGE_UNIT..value.roll
    end,

    Deserialize = function (value)
        local values = string.Explode(FORMAT_APPENDAGE_UNIT, value)
        return Angle(tonumber(values[1]), tonumber(values[2]), tonumber(values[3]))
    end
}

FORMAT_TYPES_HANDLERS["BOOLEAN"] = {
    Store = "b",
    Serialize = function (value)
        return value and "1" or "0"
    end,

    Deserialize = function (value)
        return value == "1"
    end
}

FORMAT_TYPES_HANDLERS["COLOR"] = {
    Store = "c",
    Serialize = function (value)
        if value.a then
            return string.upper(string.format("%02x%02x%02x%02x", value.r, value.g, value.b, value.a))

        else
            return string.upper(string.format("%02x%02x%02x", value.r, value.g, value.b))
        end
    end,

    Deserialize = function (value)
        local red = tonumber(string.sub(value, 1, 2), 16)
        local green = tonumber(string.sub(value, 3, 4), 16)
        local blue = tonumber(string.sub(value, 5, 6), 16)
        local alpha = nil
        if #value == 8 then
            alpha = tonumber(string.sub(value, 7, 8), 16)
        end

        return Color(red, green, blue, alpha)
    end
}

FORMAT_TYPES_HANDLERS["ENTITY"] = {
    Store = "e",
    Serialize = function (value)
        return IsValid(value) and tostring(value:EntIndex()) or "-1"
    end,

    Deserialize = function (value)
        return Entity(value) 
    end
}

FORMAT_TYPES_HANDLERS["NUMBER"] = {
    Store = "n",
    Serialize = function (value)
        return tostring(value)
    end,

    Deserialize = function (value)
        return tonumber(value)
    end
}

FORMAT_TYPES_HANDLERS["NIL"] = {
    Store = string.char(0),
    Serialize = function (value) return "" end,
    Deserialize = function (value) return nil end
}

FORMAT_TYPES_HANDLERS["STRING"] = {
    Store = "s",
    Serialize = function (value)
        return value
    end,

    Deserialize = function (value)
        return value
    end
}

local function ParseString(value)
    local ret = {}
    local offset = 1
    for entry in string.gmatch(value, "["..FORMAT_APPENDAGE_START..FORMAT_APPENDAGE_INSERT.."]+".."([%w%s%p"..FORMAT_APPENDAGE_UNIT.."]+)") do
        local start, last = string.find(value, entry, offset)
        offset = last + 1

        local term = string.sub(value, offset, offset) == FORMAT_APPENDAGE_TERM
        if term then
            offset = offset + 1
        end

        local position = start - 1
        table.insert(ret, {
            Entry = entry,
            Insert = string.sub(value, position, position) == FORMAT_APPENDAGE_INSERT,
            Terminator = term
        })
    end

    return ret
end

local function GetData(str)
    local stype = string.sub(str, 1, 1)
    local data = FORMAT_TYPES_LOOKUP[stype]
    if data then
        return data, stype
    end

    error("GM-Serialize: Encoded type not supported")
end

FORMAT_TYPES_HANDLERS["TABLE"] = {
    Store = "t",
    Terminator = true,
    Serialize = function (value)
        local built = ""
        local last = 0
        for key, vvalue in pairs(value) do
            if type(key) == "number" then
                local nex = last + 1
                if key == nex then
                    built = built..string.gsub(serialize.Encode(vvalue), FORMAT_APPENDAGE_START, FORMAT_APPENDAGE_INSERT, 1)
                    last = nex

                else
                    built = built..serialize.Encode(key)..serialize.Encode(vvalue)
                end

            else
                built = built..serialize.Encode(key)..serialize.Encode(vvalue)
            end
        end

        return built
    end,

    Deserialize = function (value, tbl)
        local ret = {}
        local tbl = tbl or ParseString(value)
        local size = #tbl

        while size > 0 do
            local key = table.remove(tbl, 1)
            size = size - 1

            local kdat, ktype = GetData(key.Entry)
            local kraw = string.sub(key.Entry, 2, #key.Entry)
            if key.Insert then
                if ktype == "t" then
                    ret[#ret + 1] = kdat.Deserialize(nil, tbl)
                    size = #tbl

                else
                    ret[#ret + 1] = kdat.Deserialize(kraw)
                end

                if key.Terminator then
                    break
                end

                continue
            end

            local value = table.remove(tbl, 1)
            size = size + 1

            local vdat, vtype = GetData(value.Entry)
            local vraw = string.sub(value.Entry, 2, #value.Entry)
            if vtype == "t" then
                ret[kdat.Deserialize(kraw)] = vdat.Deserialize(nil, tbl)
                size = #tbl

            else
                ret[kdat.Deserialize(kraw)] = vdat.Deserialize(vraw)
            end

            if value.Terminator then
                break
            end
        end

        return ret
    end
}

FORMAT_TYPES_HANDLERS["VECTOR"] = {
    Store = "v",
    Serialize = function (value)
        return value.x..FORMAT_APPENDAGE_UNIT..value.y..FORMAT_APPENDAGE_UNIT..value.z
    end,

    Deserialize = function (value)
        local values = string.Explode(FORMAT_APPENDAGE_UNIT, value)
        return Vector(tonumber(values[1]), tonumber(values[2]), tonumber(values[3]))
    end
}

local ENTITY = FORMAT_TYPES_HANDLERS["ENTITY"]
FORMAT_TYPES_HANDLERS["VEHICLE"] = ENTITY
FORMAT_TYPES_HANDLERS["WEAPON"] = ENTITY
FORMAT_TYPES_HANDLERS["NPC"] = ENTITY
FORMAT_TYPES_HANDLERS["PLAYER"] = ENTITY
FORMAT_TYPES_HANDLERS["NEXTBOT"] = ENTITY

for _, tbl in pairs(FORMAT_TYPES_HANDLERS) do
    FORMAT_TYPES_LOOKUP[tbl.Store] = tbl
end

function serialize.Encode(value)
    local vtype = type(value)
    local data = nil
    if vtype == "table" then
        if IsColor(value) then
            data = FORMAT_TYPES_HANDLERS.COLOR

        else
            data = FORMAT_TYPES_HANDLERS.TABLE
        end
    end

    data = data or FORMAT_TYPES_HANDLERS[string.upper(vtype)]
    if data then
        return FORMAT_APPENDAGE_START..data.Store..data.Serialize(value)..(data.Terminator and FORMAT_APPENDAGE_TERM or "")
    end

    error("GM-Serialize: Variable type not supported")
end

function serialize.Decode(str)
    if string.sub(str, 1, 1) == FORMAT_APPENDAGE_START then
        local data = FORMAT_TYPES_LOOKUP[string.sub(str, 2, 2)]
        if data then
            return data.Deserialize(string.sub(str, 3, #str))
        end

        error("GM-Serialize: Encoded type not supported")
    end

    error("GM-Serialize: Invalid data format")
end