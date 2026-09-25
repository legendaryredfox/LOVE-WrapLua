-- OneLua graphics: Mesh stub.
--
-- Meshes need arbitrary vertex submission, which OneLua does not expose. The
-- object answers the API so games load, but draws nothing; see Implemented.md.

function love.graphics.newMesh(vertices, mode, usage)
    local mesh = { _verts=vertices, _mode=mode, _tex=nil }
    function mesh:setTexture(t) self._tex=t end
    function mesh:getTexture()  return self._tex end
    function mesh:setVertex(i,...) end
    function mesh:getVertex(i) return 0,0,0,0,1,1,1,1 end
    function mesh:getVertexCount()
        return type(self._verts)=="number" and self._verts or #(self._verts or {})
    end
    function mesh:setDrawMode(m) self._mode=m end
    function mesh:getDrawMode()  return self._mode or "fan" end
    function mesh:setDrawRange(min,max) end
    function mesh:getDrawRange()  return 1, self:getVertexCount() end
    function mesh:attachAttribute() end
    function mesh:detachAttribute() end
    function mesh:flush() end
    function mesh:_draw(x,y,r,sx,sy) end
    return lv1lua.util.registerDrawObject(mesh)
end
