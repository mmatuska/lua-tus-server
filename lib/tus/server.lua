-- Tus server for OpenResty or NGINX with mod_lua
--
-- Copyright (C) by Martin Matuska (mmatuska)

local string = require "string"
local rstring = require "resty.string"
local random = require "resty.random"
local tus_version = "1.0.0"

local _M = {}
_M.config = {
  resource_url_prefix="",
  max_size=0,
  chunk_size=65536,
  socket_timeout=30000,
  expire_timeout=0,
  storage_backend="tus.storage_file",
  storage_backend_config={},
  extension = {
    checksum=true,
    creation=true,
    creation_defer_length=true,
    expiration=true,
    termination=true
  }
}
_M.resource = {
  name=nil,
  info=nil,
  state=nil
}
_M.err = nil
_M.sb = nil

local function split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

local function decode_base64_pair(text)
    if not text then
        return nil
    end
    local p = split(text, " ")
    if p[1] == nil or p[2] == nil or p[3] ~= nil then
        return nil
    end
    local key = p[1]
    local val = ngx.decode_base64(p[2])
    if val == nil then
        return nil
    end
    return {key=key,val=val}
end

local function decode_metadata(metadata)
    if metadata == nil then
        return nil
    end
    local ret = {}
    local q = split(metadata, ",")
    if not q then
      q = {}
      table.insert(q, metadata)
    end
    for _, v in pairs(q) do
        local p = decode_base64_pair(v)
	if not p then
	    return nil
	end
	ret[p.key] = p.val
    end
    return ret
end

local function encode_metadata(mtable)
    local first = true
    local ret = ""
    for key, val in pairs(mtable) do
        if not first then
             ret = ret .. ","
        else
             first = false
        end
        ret = ret .. key .. " " .. ngx.encode_base64(val)
    end
    return ret
end

local function get_extensions_string(extensions)
    if not extensions then
	return false
    end

    local e = {}
    for k in pairs(extensions) do
        table.insert(e, k)
    end
    table.sort(e)
    local exstr = ""
    for _,key in ipairs(e) do
        if extensions[key] then
	    if exstr ~= "" then
		    exstr = exstr .. ","
            end
	    exstr = exstr .. key
	end
    end
    if exstr == "" then
        return nil
    end
    return exstr:gsub("_", "-")
end

local function interr(self, str)
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    self.err = str
    return false
end

local function exit_status(status)
   ngx.status = status
   ngx.header["Content-Length"] = 0
end

function _M.process_request(self)
    -- All responses include the Tus-Resumable header
    ngx.header["Tus-Resumable"] = tus_version

    if not self.config then
        return interr(self, "configuration missing")
    end
    -- Store extension support
    local extensions = self.config.extension
    -- Autodisable creation-defer-length if creation is disabled
    if not extensions.creation then
        extensions.creation_defer_length = false
    end

    -- Read storage backend
    local sb = require(self.config.storage_backend)
    if not sb then
       return interr(self, "could not load storage backend")
    end
    sb.config = self.config.storage_backend_config

    self.sb = sb

    local headers = ngx.req.get_headers()
    local method

    if headers["x-http-method-override"] then
        method = headers["x-http-method-override"]
    else
        method = ngx.req.get_method()
    end

    self.method = method

    if method == "OPTIONS" then
	local extstr = get_extensions_string(extensions)
        ngx.header["Tus-Version"] = tus_version
	if extstr then
            ngx.header["Tus-Extension"] = extstr
	end
	if extensions.checksum then
	    ngx.header["Tus-Checksum-Algorithm"] = "md5,sha1,sha256"
	end
	if self.config["max_size"] > 0 then
	    ngx.header["Tus-Max-Size"] = self.config["max_size"]
	end
        ngx.status = ngx.HTTP_NO_CONTENT
        return true
    end

    if (method ~= "HEAD" and method ~= "PATCH"
      and method ~= "POST" and method ~= "DELETE") or
      (method == "POST" and not extensions.creation) or
      (method == "DELETE" and not extensions.termination) then
        exit_status(ngx.HTTP_NOT_ALLOWED)
	return true
    end

    if not headers["tus-resumable"] or
      headers["tus-resumable"] ~= tus_version then
        exit_status(412) -- Precondition Failed
	return true
    end

    if method == "POST" then
        local ulen = tonumber(headers["upload-length"])
	local udefer
	-- Ignore Upload-Defer-Length if not supported
	if extensions.creation_defer_length then
            udefer = tonumber(headers["upload-defer-length"])
	else
	    udefer = nil
	end
	local umeta = headers["upload-metadata"]
	local metadata = nil
	local newresource
	local rnd
        if (udefer ~= nil and udefer ~= 1) or
          (not ulen and not udefer) or
          (ulen and udefer) or
          (ulen and ulen < 0) then
            exit_status(ngx.HTTP_BAD_REQUEST)
            return true
        end
	if self.config["max_size"] > 0 and ulen and
	  ulen > self.config["max_size"] then
	    exit_status(413) -- Request Entity Too Large
	    return true
	end
	if umeta and umeta ~= "" then
            metadata = decode_metadata(umeta)
	    if not metadata then
	        exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	end
	while true do
            rnd = random.bytes(16,true)
            newresource = rstring.to_hex(rnd)
	    if not sb:get_info(newresource) then break end
	end
	local info = {}
	info["Upload-Length"] = ulen
	info["Upload-Defer-Length"] = udefer
	info["Upload-Metadata"] = metadata
	if extensions.expiration and self.config.expire_timeout > 0 then
	    local secs = ngx.time() + self.config.expire_timeout
	    info["Upload-Expires"] = ngx.http_time(secs)
	end
	local ret = sb:create(newresource, info)
	if not ret then
	    return interr(self, "Unable to create resource: " .. newresource)
	else
	    ngx.header["Location"] = self.config.resource_url_prefix .. "/" .. newresource
	    if extensions.expiration and info["Upload-Expires"] then
                ngx.header["Upload-Expires"] = info["Upload-Expires"]
	    end
	    if info["Upload-Defer-Length"] then
	        ngx.header["Upload-Defer-Length"] = info["Upload-Defer-Length"]
	    end
            self.resource.name = newresource
	    self.resource.state = "created"
	    exit_status(ngx.HTTP_CREATED)
	    return true
	end
    end

    -- At the moment we support only hex resources
    local resource = string.match(ngx.var.uri,"^.*/([0-9a-f]+)$")
    if not resource then
        exit_status(ngx.HTTP_NOT_FOUND)
        return true
    end
    self.resource.name = resource

    -- For all following requests the resource must exist
    self.resource.info = sb:get_info(resource)
    if not self.resource.info or not self.resource.info["Upload-Offset"] then
       exit_status(ngx.HTTP_NOT_FOUND)
       return true
    end

    if self.resource.info["Upload-Offset"] == 0 then
        self.resource.state = "empty"
    elseif self.resource.info["Upload-Length"] == self.resource.info["Upload-Offset"] then
        self.resource.state = "completed"
    else
        self.resource.state = "partial"
    end

    if method == "HEAD" then
	-- If creation-defer-length is disabled, ignore such resources
	if not extensions.creation_defer_length and
	  self.resource.info["Upload-Defer-Length"] then
	    exit_status(ngx.HTTP_FORBIDDEN)
	    return true
	end
        ngx.header["Cache-Control"] = "no_store"
	if extensions.expiration and self.resource.info["Upload-Expires"] then
	    local secs = ngx.parse_http_time(self.resource.info["Upload-Expires"])
	    ngx.update_time()
	    if secs and ngx.now() > secs then
	        self.resource.state = "expired"
	        exit_status(ngx.HTTP_GONE)
		return true
	    end
	end
        ngx.header["Upload-Offset"] = self.resource.info["Upload-Offset"]
        if self.resource.info["Upload-Defer-Length"] then
            ngx.header["Upload-Defer-Length"] = 1
        end
        if self.resource.info["Upload-Length"] then
            ngx.header["Upload-Length"] = self.resource.info["Upload-Length"]
        end
        if self.resource.info["Upload-Metadata"] then
            local metadata = encode_metadata(self.resource.info["Upload-Metadata"])
            if metadata then
              ngx.header["Upload-Metadata"] = metadata
            end
        end
	if extensions.expiration and self.resource.info["Upload-Expires"] then
	    ngx.header["Upload-Expires"] = self.resource.info["Upload-Expires"]
	end
        exit_status(ngx.HTTP_NO_CONTENT)
        return true
    end

    if method == "DELETE" then
        local ret = sb:delete(resource)
	if ret then
	    exit_status(ngx.HTTP_NO_CONTENT)
	else
	    return interr(self, "Error deleting resource: " .. resource)
	end
	self.resource.state = "deleted"
	return true
    end

    if method == "PATCH" then
        if headers["content-type"] ~= "application/offset+octet-stream" then
	    exit_status(415) -- Unsupported Media Type
	    return true
	end
	local upload_offset = tonumber(headers["upload-offset"])
	if not upload_offset or upload_offset ~= self.resource.info["Upload-Offset"] then
	    exit_status(ngx.HTTP_CONFLICT)
	    return true
	end
	local upload_length
	if self.resource.info["Upload-Defer-Length"] then
	    if not extensions.creation_defer_length then
                exit_status(ngx.HTTP_FORBIDDEN)
		return true
            end
	    upload_length = tonumber(headers["upload-length"])
	    if not upload_length then
	        exit_status(ngx.HTTP_CONFLICT)
		return true
            end
	    if self.config["max_size"] > 0 and
	      upload_length > self.config["max_size"] then
	        exit_status(413) -- Request Entity Too Large
		return true
	    end
	    self.resource.info["Upload-Defer-Length"] = nil
	    self.resource.info["Upload-Length"] = upload_length
	    if not sb:update_info(resource, self.resource.info) then
	        return interr(self, "Error updating resource metadata: " .. resource)
	    end
        else
	    upload_length = self.resource.info["Upload-Length"]
	end
	local content_length = tonumber(headers["content-length"])
	if not content_length or content_length < 0 then
	    exit_status(ngx.HTTP_BAD_REQUEST)
	    return true
	end

	local resty_hash
	local c_hash -- Client-supplied hash
	local hash_ctx = nil

        if headers["upload-checksum"] then
	    if not extensions.checksum then
                exit_status(ngx.HTTP_BAD_REQUEST)
		return true
            end
            local p = decode_base64_pair(headers["upload-checksum"])
	    if not p then
	        exit_status(ngx.HTTP_BAD_REQUEST)
	        return true
	    end
	    local c_algo = p.key -- Client supplied algo
	    if c_algo ~= "md5" and c_algo ~= "sha1" and c_algo ~= "sha256" then
	        exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	    c_hash = p.val
	    -- In theory we support everything from lua-resty-string
	    resty_hash = require('resty/' .. c_algo)
	    if not resty_hash then
	        exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	    hash_ctx = resty_hash:new()
	end

        if (upload_offset + content_length) > upload_length then
	    exit_status(ngx.HTTP_CONFLICT)
	    return true
	end
	if self.resource.info["Upload-Expires"] then
	    local secs = ngx.parse_http_time(self.resource.info["Upload-Expires"])
	    ngx.update_time()
	    if secs and ngx.now() > secs then
	        self.resource.state = "expired"
	        exit_status(ngx.HTTP_GONE)
		return true
	    end
	end
	if content_length == 0 then
	    exit_status(ngx.HTTP_NO_CONTENT)
	    return true
	end

        local socket, err = ngx.req.socket()
        if not socket then
	    return interr(self, "Socket error: "  .. err)
	end
	socket:settimeout(self.config.socket_timeout)

        local to_receive = content_length
	local cur_offset = upload_offset
	local csize
	if not sb:open(resource, upload_offset) then
            return interr(self, "Error opening resource for writing: " .. resource)
        end
        while true do
	    if to_receive <= 0 then break end
	    if to_receive > self.config.chunk_size then
                csize = self.config.chunk_size
	    else
	        csize = to_receive
	    end
	    local chunk, e = socket:receive(csize)
	    if e then
		sb:close(resource)
	        return interr(self, "Socket receive error: " .. e)
	    end
	    if hash_ctx then
	        hash_ctx:update(chunk)
	    end
            if not sb:write(chunk) then
                sb:close(resource)
	        return interr(self, "Error writing to resource: " .. resource)
            end
	    cur_offset = cur_offset + csize
	    to_receive = to_receive - csize
        end
	sb:close(resource)
	if hash_ctx then
	    local digest = hash_ctx:final()
	    if digest then
	        if c_hash ~= rstring.to_hex(digest) then
		    exit_status(460)
		    return true
		end
            else
	        return interr(self, "Error computing checksum: " .. resource)
	    end
        end
	self.resource.info["Upload-Offset"] = cur_offset
        ngx.header["Upload-Offset"] = cur_offset
	if not sb:update_info(resource, self.resource.info) then
	    return interr(self, "Error updating resource metadata: " .. resource)
        end
	exit_status(ngx.HTTP_NO_CONTENT)
	if cur_offset == self.resource.info["Upload-Length"] then
	    self.resource.state = "completed"
	end
	return true
    end
end

return _M
