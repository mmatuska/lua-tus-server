-- Local file storage backend for lua-tus-server
--
-- Copyright (C) by Martin Matuska (mmatuska)

local cjson = require "cjson"
local os = require "os"

local _M = {}
local mt = { __index = _M }
local config = {
  storage_path="/tmp",
  lock_zone=ngx.shared.tuslock
}

-- Check if a file is readable
local function file_exists(path)
   local file = io.open(path, "rb")
   if not file then
       return false
   end
   file:close()
   return true
end

-- Delete a file or return true if not existing
local function delete_file(path)
    if file_exists(path) then
        local ret = os.remove(path)
        if not ret then
            return false
        end
    end
    return true
end

function _M.get_path(self, resource)
    return self.config["storage_path"] .. "/" .. resource
end

function _M.get_info_path(self, resource)
    return self.config["storage_path"] .. "/" .. resource .. ".json"
end

function _M.open(self, resource, offset)
    local shmlock = self.config["lock_zone"]
    if shmlock then
        local lock, _ = shmlock:get(resource)
        if lock then
            return false
        end
    end
    if self.file then
        self.file:close()
        self.file = nil
    end
    local file = io.open(self:get_path(resource), "r+b")
    if not file then
        return false
    end
    if shmlock then
        shmlock:set(resource, true)
    end
    if offset and offset > 0 and not file:seek("set", offset) then
        file:close()
        if self.shmlock then
            self.shmlock:delete(resource)
        end
        return false
    end
    self.file = file
    return true
end

function _M.close(self, resource)
    local shmlock = self.config["lock_zone"]
    if self.file then
        self.file:close()
        self.file = nil
    end
    if shmlock then
        shmlock:delete(resource)
    end
    return true
end

function _M.write(self, chunk)
    if not self.file then
        return false
    end
    self.file:write(chunk)
    local _, err = self.file:seek("cur")
    if err then
        return false, err
    end
    return true
end

function _M.get_info(self, resource)
    local file = io.open(self:get_info_path(resource), "r")
    if not file then
      return nil
    end
    local r = cjson.decode(file:read("*all"))
    file:close()
    return r
end

function _M.update_info(self, resource, data)
    local file = io.open(self:get_info_path(resource), "w")
    if not file then
      os.remove(self:get_path(resource))
      return false
    end
    file:write(cjson.encode(data))
    local _, err = file:seek("cur")
    file:close()
    if err then
        return false, err
    end
    return true
end

function _M.create(self, resource, data)
    local file
    file = io.open(self:get_path(resource), "w")
    if not file then
        return nil
    end
    file:close()
    local ret = self:update_info(resource, data)
    if not ret then
        os.remove(self:get_path(resource))
        return false
    end
    return true
end

function _M.delete(self, resource)
    if not delete_file(self:get_path(resource)) then
        return false
    end
    if not delete_file(self:get_info_path(resource)) then
        return false
    end
    return true
end

function _M.new(_)
    return setmetatable({config = config}, mt)
end

return _M
