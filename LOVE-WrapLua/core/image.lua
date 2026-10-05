-- Shared Image object.
--
-- Every SDK here hands back a bare texture handle: an integer on lpp-vita and
-- lpp-3ds (lua_pushinteger of a C pointer), userdata on OneLua, a tiny3D table
-- on the PS3. Games call LOVE's Image methods on whatever newImage returns
-- (anim8 and desAnim8 ask for getWidth; filters and wraps are set per image),
-- and a method call on a number or a bare handle raises. So each backend wraps
-- its handle here and its draw unwraps it again with lv1lua.core.texture().
--
-- Optional native hooks, on lv1lua.gfx.imageHooks:
--   setFilter(tex, min, mag)   push LOVE filter names to the native texture
--   release(tex)               free the native texture
--
-- Wrap modes and mipmap settings are tracked only: no SDK here samples outside
-- a quad or builds mipmaps.

lv1lua.core = lv1lua.core or {}
lv1lua.gfx  = lv1lua.gfx or {}

local Image = {}
Image.__index = Image
lv1lua.core.Image = Image

local function hooks() return lv1lua.gfx.imageHooks or {} end

local TYPES = { Image = true, Texture = true, Drawable = true, Object = true }

function Image:type()      return "Image" end
function Image:typeOf(t)   return TYPES[t] == true end

function Image:getWidth()       return self._w end
function Image:getHeight()      return self._h end
function Image:getDimensions()  return self:getWidth(), self:getHeight() end
function Image:getPixelWidth()  return self:getWidth() end
function Image:getPixelHeight() return self:getHeight() end
function Image:getPixelDimensions() return self:getDimensions() end
function Image:getDPIScale()    return 1 end

function Image:getTextureType() return "2d" end
function Image:getFormat()      return "rgba8" end
function Image:isCompressed()   return false end
function Image:isReadable()     return true end
function Image:isFormatLinear() return false end
function Image:getMipmapCount() return 1 end
function Image:getDepth()       return 1 end
function Image:getLayerCount()  return 1 end

function Image:getFilter()
    return self._min, self._mag, self._anisotropy
end

function Image:setFilter(min, mag, anisotropy)
    self._min = min or "linear"
    self._mag = mag or self._min
    self._anisotropy = anisotropy or 1
    local fn = hooks().setFilter
    if fn and self._tex ~= nil then fn(self._tex, self._min, self._mag) end
end

function Image:getWrap()
    return self._wrapH, self._wrapV, self._wrapD
end

function Image:setWrap(horiz, vert, depth)
    self._wrapH = horiz or "clamp"
    self._wrapV = vert or self._wrapH
    self._wrapD = depth or self._wrapH
end

-- LOVE returns nothing for an image without mipmaps.
function Image:getMipmapFilter() return nil end
function Image:setMipmapFilter() end

function Image:replacePixels() end

function Image:release()
    if self._tex == nil then return false end
    local fn = hooks().release
    if fn then fn(self._tex) end
    self._tex = nil
    return true
end

-- Wraps a native handle of the given pixel size. The new image takes the
-- default filter, as in LOVE, and pushes it to the texture where a hook can.
function lv1lua.core.wrapImage(tex, w, h)
    local f = lv1lua.gfx.filter or {}
    local img = setmetatable({
        _tex   = tex,
        _w     = w or 0,
        _h     = h or 0,
        _wrapH = "clamp", _wrapV = "clamp", _wrapD = "clamp",
    }, Image)
    img:setFilter(f.minName or "linear", f.magName, f.anisotropy)
    return img
end

function lv1lua.core.isImage(obj)
    return type(obj) == "table" and getmetatable(obj) == Image
end

-- The native handle behind a drawable: an Image's texture, or the value
-- itself for a handle a game or library passed in directly.
function lv1lua.core.texture(drawable)
    if lv1lua.core.isImage(drawable) then return drawable._tex end
    return drawable
end
