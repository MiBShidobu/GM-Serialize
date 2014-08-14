--[[
    GM-Serialize Library By MiBShidobu

    Description:
        This addon provides an API to serialize data into a small scale transferable format.
        Mainly for use by GM-Networking, opped to give it its own GitHub to be improved and modified easily.

    Credits:
        MiBShidobu - Main Developer
]]--

serialize = {
    VERSION = "2.3.3"
}

local FORMAT_APPENDAGE_START	= string.char(1)
local FORMAT_APPENDAGE_INSERT	= string.char(16)
local FORMAT_APPENDAGE_TERM		= string.char(29)
local FORMAT_APPENDAGE_UNIT		= string.char(31)

local FORMAT_TYPE_ANGLE		= "a"
local FORMAT_TYPE_COLOR		= "c"
local FORMAT_TYPE_ENTITY	= "e"
local FORMAT_TYPE_FALSE		= "f"
local FORMAT_TYPE_NIL		= string.char(0)
local FORMAT_TYPE_STRING	= "s"
local FORMAT_TYPE_TABLE		= "t"
local FORMAT_TYPE_TRUE		= "r"
local FORMAT_TYPE_VECTOR	= "v"

local EncodeType = nil
function EncodeType(value)
    local vtype = type(value)
    if vtype == "Angle" then
        return FORMAT_TYPE_ANGLE..value.pitch..FORMAT_APPENDAGE_UNIT..value.yaw..FORMAT_APPENDAGE_UNIT..value.roll

    elseif vtype == "boolean" then
        return value and FORMAT_TYPE_TRUE or FORMAT_TYPE_FALSE

    elseif vtype == "table" and value.r and value.g and value.b then
        if value.a then
            return FORMAT_TYPE_COLOR..string.format("%02x%02x%02x%02x", value.r, value.g, value.b, value.a)

        else
            return FORMAT_TYPE_COLOR..string.format("%02x%02x%02x", value.r, value.g, value.b)
        end

    elseif vtype == "Entity" or vtype == "Vehicle" or vtype == "Weapon" or vtype == "NPC" or vtype == "Player" or vtype == "NextBot" then
        return FORMAT_TYPE_ENTITY..(IsValid(value) and value:EntIndex() or "-1")

    elseif vtype == "nil" then
        return FORMAT_TYPE_NIL

    elseif vtype == "number" then
        return value

    elseif vtype == "string" then
        return FORMAT_TYPE_STRING..value

    elseif vtype == "table" then
        local built = ""
        local last = 0

        for key, vvalue in pairs(value) do
            if type(key) == "number" then
                local nex = last + 1
                if key == nex then
                    built = built..FORMAT_APPENDAGE_INSERT..EncodeType(vvalue)
                    last = nex

                    continue
                end
            end

            built = built..FORMAT_APPENDAGE_START..EncodeType(key)..FORMAT_APPENDAGE_START..EncodeType(vvalue)
        end

        return FORMAT_TYPE_TABLE..built..FORMAT_APPENDAGE_TERM

    elseif vtype == "Vector" then
        return FORMAT_TYPE_VECTOR..value.x..FORMAT_APPENDAGE_UNIT..value.y..FORMAT_APPENDAGE_UNIT..value.z
    end

    error("GM-Serialize: Variable type not supported")
end

function serialize.Encode(value)
    return FORMAT_APPENDAGE_START..EncodeType(value)
end

function ParseString(str)
    local ret = {}
    local built = ""
    local built_size = 0
    local position = 1
    local size = #str
    local inserted = false
    local index = 1

    while position <= size do
        local chr = str[position]
        local insert = chr == FORMAT_APPENDAGE_INSERT
        if chr == FORMAT_APPENDAGE_START or insert then
            if built_size > 0 then
                ret[index] = {
                    built,
                    inserted,
                    false
                }

                index = index + 1
            end

            built = ""
            built_size = 0
            inserted = insert

        else
            local term = chr == FORMAT_APPENDAGE_TERM
            if size == position or term then
                if built_size > 0 then
                    ret[index] = {
                        built,
                        inserted,
                        term
                    }

                    index = index + 1

                    built = ""
                    built_size = 0
                end

            else
                built = built..chr
                built_size = built_size + 1
            end
        end

        position = position + 1
    end

    return ret
end

local DecodeType = nil
local tindex = nil
function DecodeType(str, var, var2)
    local etype = str[1]
    local enumber = tonumber(str)
    if etype == FORMAT_TYPE_ANGLE then
        local value = string.sub(str, 2, #str)
        local values = string.Explode(FORMAT_APPENDAGE_UNIT, value)
        return Angle(tonumber(values[1]), tonumber(values[2]), tonumber(values[3]))

    elseif etype == FORMAT_TYPE_COLOR then
        local value = string.sub(str, 2, #str)

        local red = tonumber(string.sub(value, 1, 2), 16)
        local green = tonumber(string.sub(value, 3, 4), 16)
        local blue = tonumber(string.sub(value, 5, 6), 16)

        local alpha = nil
        if #value == 8 then
            alpha = tonumber(string.sub(value, 7, 8), 16)
        end

        return Color(red, green, blue, alpha)

    elseif etype == FORMAT_TYPE_ENTITY then
        local value = tonumber(string.sub(str, 2, #str))
        return Entity(value)

    elseif etype == FORMAT_TYPE_FALSE then 
        return false

    elseif etype == FORMAT_TYPE_NIL then
        return nil

    elseif etype == FORMAT_TYPE_STRING then
        return string.sub(str, 2, #str)

    elseif etype == FORMAT_TYPE_TABLE then
        local ret = {}
        local tbl = var or ParseString(string.sub(str, 2, #str))
        local size = var2 or #tbl

        while tindex < size do
            local key = tbl[tindex]
            tindex = tindex + 1

            local kentry = key[1]
            local kvalue = nil

            if kentry[1] == "t" then
                kvalue = DecodeType("t", tbl, size)

            else
                kvalue = DecodeType(kentry)
            end

            if key[2] then
                ret[#ret + 1] = kvalue

                if key[3] then
                    break
                end

            else
                local value = tbl[tindex]
                tindex = tindex + 1

                local ventry = value[1]
                if ventry[1] == "t" then
                    ret[kvalue] = DecodeType("t", tbl, size)

                else
                    ret[kvalue] = DecodeType(ventry)
                end

                if value[3] then
                    break
                end
            end
        end

        return ret

    elseif etype == FORMAT_TYPE_TRUE then 
        return true

    elseif etype == FORMAT_TYPE_VECTOR then
        local value = string.sub(str, 2, #str)
        local values = string.Explode(FORMAT_APPENDAGE_UNIT, value)
        return Vector(tonumber(values[1]), tonumber(values[2]), tonumber(values[3]))

    elseif enumber ~= nil then
        return enumber
    end

    error("GM-Serialize: Encoded type not supported")
end

function serialize.Decode(str)
    if string.sub(str, 1, 1) == FORMAT_APPENDAGE_START then
        tindex = 1
        return DecodeType(string.sub(str, 2, #str))
    end

    error("GM-Serialize: Invalid data format")
end