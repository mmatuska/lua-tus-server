-- Tus server for OpenResty or NGINX with mod_lua
--
-- Copyright (C) by Martin Matuska (mmatuska)

local rstring = require "resty.string"
local tus_version = "1.0.0"

local _M = {}
_M.config = {
  server_url=ngx.var.scheme .. "://" .. ngx.var.host,
  upload_url="",
  max_size=0,
  chunk_size=65536,
  socket_timeout=30000,
  expire_timeout=0,
  storage_backend="tus.storage_file",
  storage_backend_config={},
  hard_delete=false,
  resource_name_length=10,
  extension = {
    checksum=true,
    concatenation=true,
    concatenation_unfinished=true,
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
    -- Sort table first
    local s = {}
    for n in pairs(mtable) do table.insert(s, n) end
    table.sort(s)
    local first = true
    local ret = ""
    for _, key in ipairs(s) do
	if not first then
	     ret = ret .. ","
	else
	     first = false
	end
	ret = ret .. key .. " " .. ngx.encode_base64(mtable[key])
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

local function interr()
    ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
    return false
end

local function exit_status(status)
   ngx.status = status
   ngx.header["Content-Length"] = 0
end

local function check_concat_final(self, concat_final)
    local ret = {}
    local size = 0
    local complete = 0
    for _, v in pairs(concat_final) do
	local ri = self:resource_info(v)
	if not ri then
	    ret.err = "Upload-Concat with non-existing resource"
	elseif ri.deleted then
	    ret.err = "Upload-Concat with deleted resource"
	elseif  not ri.concat_partial or ri.concat_partial ~= true then
	    ret.err = "Upload-Concat with non-partial resource"
	end
	if ret.err then
	    return ret
	end
	if size ~= nil and ri.size then
	    size = size + ri.size
	    if ri.size == ri.offset then
		complete = complete + ri.size
	    end
	else
	    complete = nil
	    size = nil
	end
    end
    if size ~= nil and size == complete then
	ret.complete = true
    else
	ret.complete = false
    end
    ret.size = size
    return ret
end

local function randstring(len, charset)
    math.randomseed(ngx.time() + ngx.worker.pid())
    local res = ""
    local r
    if charset == nil then
        charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    end
    local cl = #charset
    for _ = 1, len do
        r = math.random(1,cl)
        res = res .. charset:sub(r,r)
    end
    return res
end

-- Report tus version
function _M.tus_version()
    return tus_version
end

-- Create URL from resource name
function _M.resource_to_url(self, resource)
    return self.config.upload_url  .. "/" .. resource
end

-- Get resource name from URL
function _M.url_to_resource(self, url)
    local upload_url = self.config.upload_url
    if url:sub(1,upload_url:len() + 1) == upload_url .. "/" then
	return url:sub(upload_url:len() + 2)
    end
    local full_url
    if upload_url:sub(1,1) == "/" then
	full_url = self.config.server_url .. upload_url
    else
	full_url = self.config.server_url .. "/" .. upload_url
    end
    if url:sub(1,full_url:len() + 1) == full_url .. "/" then
	return url:sub(full_url:len() + 2)
    end
    return nil
end

-- Initialize storage backend
function _M.initsb(self)
    self.sb = require(self.config.storage_backend)
    if not self.sb then
        ngx.log(ngx.ERR, "could not load storage backend")
	return false
    end
    self.sb.config=self.config.storage_backend_config
    return true
end

-- Get resource info
function _M.resource_info(self,name)
    if not self.sb or not name or type(name) ~= "string"
      or not name:match("^([%a%d]+)$") then
	return false
    else
	return self.sb:get_info(name)
    end
end

-- Create new resource
function _M.create_resource(self,i)
    if not self.sb or (i and type(i) ~= "table") then
	return false
    end

    local name

    if i.name then
	if type(i.name) ~= "string" or not i.name:match("^([%a%d]+)$") then
	    return false
	end
	name = i.name
	if self:resource_info(i.name) ~= nil then
	    return nil, name
	end

    else
	while true do
	    name = randstring(self.config.resource_name_length)
	    local r = self:resource_info(name)
	    if r == false then return false end
	    if r == nil then break end
	end
    end
    local info = {}
    info.offset = 0
    if i ~= nil then
	if (i.defer ~= nil and type(i.defer) ~= "boolean")
	  or (i.concat_partial ~= nil and type(i.concat_partial) ~= "boolean")
	  or (i.concat_final ~= nil and type(i.concat_final) ~= "table")
	  or (i.expires ~= nil and (type(i.expires) ~= "number" or i.expires < 0))
	  or (i.metadata ~= nil and type(i.metadata) ~= "table") then
	    return false, name
	end
	if (i.defer == true or i.concat_final ~= nil) then
	    if i.size ~= nil then return false,name end
	else
	    if i.size == nil or type(i.size) ~= "number" or i.size < 0 then
	        return false,name
	    end
	end
	if (i.concat_final ~= nil) then
	    info.offset = nil
	end
	info.concat_partial = i.concat_partial
	info.concat_final = i.concat_final
	info.defer = i.defer
	info.size = i.size
	info.metadata = i.metadata
	info.expires = i.expires
    end
    return self.sb:create(name,info),name
end

-- Process web request
function _M.process_request(self)
    -- All responses include the Tus-Resumable header
    ngx.header["Tus-Resumable"] = tus_version

    if not self.config then
	return interr()
    end

    -- Store extension support
    local extensions = self.config.extension
    -- Autodisable concatenation-unfinished if concatenation is disabled
    if not extensions.concatenation and extensions.concatenation_unfinished ~= false then
	ngx.log(ngx.NOTICE, "Auto-disabling concatenation-unfinished extension")
	extensions.concatenation_unfinished = false
    end

    -- Initialize storage backend if necessary
    if not self.sb and not self:initsb() then
	return interr()
    end
    local sb = self.sb

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
	local ulen = false
	if headers["upload-length"] then
	    ulen = tonumber(headers["upload-length"])
	end
	local udefer = false
	if headers["upload-defer-length"] then
	    if extensions.creation_defer_length then
		udefer = tonumber(headers["upload-defer-length"])
	    else
		ngx.log(ngx.INFO, "Received Upload-Defer-Length with disabled extension")
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	end
	local concat_partial = false
	local concat_final = false
	if headers["upload-concat"] then
	    if extensions.concatenation then
		local conhdr = headers["upload-concat"]
		if conhdr:sub(1,6) == "final;" then
		    if udefer then
			ngx.log(ngx.INFO, "Rejecting final Upload-Concat with Upload-Defer-Length")
			exit_status(ngx.HTTP_BAD_REQUEST)
			return true
		    end
		    if ulen ~= false then
			ngx.log(ngx.INFO, "Rejecting final Upload-Concat with Upload-Size")
			exit_status(ngx.HTTP_BAD_REQUEST)
			return true
		    end
		    local cr = split(conhdr:sub(7), " ")
		    if cr then
			concat_final = {}
			for _, url in pairs(cr) do
			    local cres = self:url_to_resource(url)
			    if not cres then
				ngx.log(ngx.INFO, "Upload-Concat with invalid resource")
				exit_status(412)
				return true
			    else
				table.insert(concat_final, cres)
			    end
		        end
			local cinfo = check_concat_final(self, concat_final)
			if cinfo.err then
			    ngx.log(ngx.INFO, cinfo.err)
			    exit_status(412)
			    return true
			elseif not extensions.concatenation_unfinished and not cinfo.complete then
			    ngx.log(ngx.INFO, "Upload-Concat with unfinished uploads")
			    exit_status(412)
			    return true
			end
		    end
		elseif conhdr == "partial" then
		    concat_partial = true
		end
		if not concat_partial and not concat_final then
		    ngx.log(ngx.INFO, "Invalid Upload-Concat")
		    exit_status(ngx.HTTP_BAD_REQUEST)
		    return true
		end
	    else
		ngx.log(ngx.INFO, "Received Upload-Concat with disabled extension")
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	end
	local umeta = headers["upload-metadata"]
	local metadata = nil
	local bad_request = false
	if not concat_final then
	    if udefer ~= false and udefer ~= 1 then
		ngx.log(ngx.INFO, "Invalid Upload-Defer-Length")
		bad_request = true
	    elseif not ulen and not udefer then
		ngx.log(ngx.INFO, "Received neither Upload-Length nor Upload-Defer-Length")
		exit_status(411) -- Length Required
		return true
	    elseif ulen and udefer then
		ngx.log(ngx.INFO, "Received both Upload-Length and Upload-Defer-Length")
		bad_request = true
	    elseif ulen and ulen < 0 then
		ngx.log(ngx.INFO, "Received negative Upload-Length")
		bad_request = true
	    end
	end
	if bad_request then
	    exit_status(ngx.HTTP_BAD_REQUEST)
	    return true
	end
	if self.config["max_size"] > 0 and ulen and
	  ulen > self.config["max_size"] then
	    ngx.log(ngx.INFO, "Upload-Length exceeds Tus-Max-Size")
	    exit_status(413) -- Request Entity Too Large
	    return true
	end
	if umeta and umeta ~= "" then
	    metadata = decode_metadata(umeta)
	    if not metadata then
		ngx.log(ngx.INFO, "Invalid Upload-Metadata")
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	end
	local info = {}
	if concat_partial then
	    info.concat_partial = concat_partial
	end
	if concat_final then
	    info.concat_final = concat_final
        else
	    info.offset = 0
	end
	if ulen ~= false then
	    info.size = ulen
	end
	if udefer ~= false then
	    info.defer = true
	end
	info.metadata = metadata
	if extensions.expiration and self.config.expire_timeout > 0 then
	    info.expires = ngx.time() + self.config.expire_timeout
	end
	local err, newresource = self:create_resource(info)
	if not err then
	    ngx.log(ngx.ERR, "Unable to create resource: " .. tostring(newresource))
	    return interr()
	else
	    ngx.header["Location"] = self:resource_to_url(newresource)
	    if extensions.expiration and info.expires then
		ngx.header["Upload-Expires"] = ngx.http_time(info.expires)
	    end
	    if info.defer then
		ngx.header["Upload-Defer-Length"] = 1
	    end
	    self.resource.name = newresource
	    self.resource.state = "created"
	    exit_status(ngx.HTTP_CREATED)
	    return true
	end
    end

    -- At the moment we support only hex resources
    local resource = self:url_to_resource(ngx.var.uri)
    if resource then
	    resource = resource:match("^([%a%d]+)$")
    end
    if not resource then
	ngx.log(ngx.INFO, "Invalid resource endpoint")
	exit_status(ngx.HTTP_NOT_FOUND)
	return true
    end
    self.resource.name = resource

    -- For all following requests the resource must exist
    self.resource.info = self:resource_info(resource)
    if not self.resource.info or
      (not self.resource.info.offset and
      not self.resource.info.concat_final) then
       exit_status(ngx.HTTP_NOT_FOUND)
       return true
    end
    -- If the resource is marked as deleted or invalid, return 410
    if self.resource.info.deleted or self.resource.info.invalid then
	if self.resource.info.deleted then
	    self.resource.state = "deleted"
	else
	    self.resource.state = "invalid"
	end
	exit_status(ngx.HTTP_GONE)
	return true
    end

    if self.resource.info.offset == 0 then
	self.resource.state = "empty"
    elseif self.resource.info.size == self.resource.info.offset then
	self.resource.state = "completed"
    else
	self.resource.state = "in_progress"
    end

    if method == "HEAD" then
	-- If concatenation is disabled we don't report such resources
	if not extensions.concatenation and
	  (self.resource.info.concat_partial or self.resource.info.concat_final) then
	    ngx.log(ngx.INFO, "Disclosing resource due to disabled concatenation")
	    exit_status(ngx.HTTP_FORBIDDEN)
	    return true
	end
	-- If creation-defer-length is disabled we don't report such resources
	if not extensions.creation_defer_length and
	  self.resource.info.defer then
	    ngx.log(ngx.INFO, "Disclosing resource due to disabled creation-defer-length")
	    exit_status(ngx.HTTP_FORBIDDEN)
	    return true
	end
	if self.resource.info.concat_partial and self.resource.info.concat_partial == true then
	    ngx.header["Upload-Concat"] = "partial"
	elseif self.resource.info.concat_final then
	    local conhdr = "final;"
	    local first = true
	    local cinfo = check_concat_final(self, self.resource.info.concat_final)
	    if cinfo.err then
		ngx.log(ngx.NOTICE, cinfo.err)
		exit_status(ngx.HTTP_GONE)
		return true
	    end
	    for _, v in pairs(self.resource.info.concat_final) do
		if first then
		    first = false
		else
		    conhdr = conhdr .. " "
		end
		conhdr = conhdr .. self:resource_to_url(v)
	    end
	    if cinfo.size then
		self.resource.info.size = cinfo.size
	    end
	    if cinfo.complete then
		self.resource.info.offset = cinfo.size
	    elseif not extensions.concatenation_unfinished then
		ngx.log(ngx.INFO, "Disclosing resource due to disabled concatenation-unfinished")
		exit_status(ngx.HTTP_FORBIDDEN)
		return true
	    else
		self.resource.info.offset = nil
	    end
	    ngx.header["Upload-Concat"] = conhdr
	end
	ngx.header["Cache-Control"] = "no_store"
	local expires = self.resource.info.expires
	if extensions.expiration and expires then
	    if ngx.now() > expires then
		self.resource.state = "expired"
		exit_status(ngx.HTTP_GONE)
		return true
	    end
	end
	if self.resource.info.offset then
	    ngx.header["Upload-Offset"] = self.resource.info.offset
	end
	if self.resource.info.defer then
	    ngx.header["Upload-Defer-Length"] = 1
	end
	if self.resource.info.size then
	    ngx.header["Upload-Length"] = self.resource.info.size
	end
	if self.resource.info.metadata then
	    local metadata = encode_metadata(self.resource.info.metadata)
	    if metadata then
	      ngx.header["Upload-Metadata"] = metadata
	    end
	end
	if extensions.expiration and expires then
	    ngx.header["Upload-Expires"] = ngx.http_time(expires)
	end
	exit_status(ngx.HTTP_NO_CONTENT)
	return true
    end

    if method == "DELETE" then
	self.resource.info.deleted = true
	if not sb:update_info(resource, self.resource.info) then
	    ngx.log(ngx.ERR, "Error updating resource metadata: " .. resource)
	    return interr()
	end
	if self.config.hard_delete and not sb:delete(resource) then
	    ngx.log(ngx.ERR, "Error deleting resource: " .. resource)
	    return interr()
	end
	exit_status(ngx.HTTP_NO_CONTENT)
	self.resource.state = "deleted"
	return true
    end

    if method == "PATCH" then
	--- Patch against final Upload-Concat is not allowed
	if self.resource.info.concat_final then
	    exit_status(ngx.HTTP_FORBIDDEN)
	    return true
	end
	if headers["content-type"] ~= "application/offset+octet-stream" then
	    ngx.log(ngx.INFO, "Invalid or missing header: Content-Type")
	    exit_status(415) -- Unsupported Media Type
	    return true
	end
	local upload_offset = tonumber(headers["upload-offset"])
	if not upload_offset or upload_offset ~= self.resource.info.offset then
	    ngx.log(ngx.INFO, "Upload-Offset mismatch: " .. resource)
	    exit_status(ngx.HTTP_CONFLICT)
	    return true
	end
	local upload_length
	if self.resource.info.defer then
	    if not extensions.creation_defer_length then
		ngx.log(ngx.INFO, "Ignoring resource due to disabled creation-defer-length")
		exit_status(ngx.HTTP_FORBIDDEN)
		return true
	    end
	    upload_length = tonumber(headers["upload-length"])
	    if not upload_length then
		ngx.log(ngx.INFO, "Invalid header: Upload-Length")
		exit_status(ngx.HTTP_CONFLICT)
		return true
	    end
	    if self.config["max_size"] > 0 and
	      upload_length > self.config["max_size"] then
		ngx.log(ngx.INFO, "Upload-Length exceeds Tus-Max-Size")
		exit_status(413) -- Request Entity Too Large
		return true
	    end
	    self.resource.info.defer = nil
	    self.resource.info.size = upload_length
	    if not sb:update_info(resource, self.resource.info) then
		ngx.log(ngx.ERR, "Error updating resource metadata: " .. resource)
		return interr()
	    end
	else
	    upload_length = self.resource.info.size
	end
	local content_length = tonumber(headers["content-length"])
	if not content_length or content_length < 0 then
	    ngx.log(ngx.INFO, "Invalid header: Content-Length")
	    exit_status(ngx.HTTP_BAD_REQUEST)
	    return true
	end

	local resty_hash
	local c_hash -- Client-supplied hash
	local hash_ctx = nil

	if headers["upload-checksum"] then
	    if not extensions.checksum then
		ngx.log(ngx.INFO, "Upload-Checksum without checksum extension")
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	    local p = decode_base64_pair(headers["upload-checksum"])
	    if not p then
		ngx.log(ngx.INFO, "Invalid header: Upload-Checksum")
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	    local c_algo = p.key -- Client supplied algo
	    if c_algo ~= "md5" and c_algo ~= "sha1" and c_algo ~= "sha256" then
		ngx.log(ngx.INFO, "Unsupported checksum algorithm: " .. c_algo)
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	    c_hash = p.val
	    -- In theory we support everything from lua-resty-string
	    resty_hash = require('resty/' .. c_algo)
	    if not resty_hash then
		ngx.log(ngx.WARN, "Error loading supported checksum algorithm: " .. c_algo)
		exit_status(ngx.HTTP_BAD_REQUEST)
		return true
	    end
	    hash_ctx = resty_hash:new()
	end

	if (upload_offset + content_length) > upload_length then
	    ngx.log(ngx.INFO, "Upload-Offset + Content-Length exceeds Upload-Length")
	    exit_status(ngx.HTTP_CONFLICT)
	    return true
	end
	if self.resource.info.expires then
	    local secs = self.resource.info.expires
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
	    ngx.log(ngx.ERR, "Socket error: "  .. err)
	    return interr()
	end
	socket:settimeout(self.config.socket_timeout)

	local to_receive = content_length
	local cur_offset = upload_offset
	local csize
	if not sb:open(resource, upload_offset) then
	    ngx.log(ngx.ERR, "Error opening resource for writing: " .. resource)
	    return interr()
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
		ngx.log(ngx.ERR, "Socket receive error: " .. e)
		return interr()
	    end
	    if hash_ctx then
		hash_ctx:update(chunk)
	    end
	    if not sb:write(chunk) then
		sb:close(resource)
		ngx.log(ngx.ERR, "Error writing to resource: " .. resource)
		return interr()
	    end
	    cur_offset = cur_offset + csize
	    to_receive = to_receive - csize
	end
	sb:close(resource)
	if hash_ctx then
	    local digest = hash_ctx:final()
	    if digest then
		if c_hash ~= rstring.to_hex(digest) then
		    ngx.log(ngx.INFO, "Checksum mismatch")
		    exit_status(460)
		    return true
		end
	    else
		ngx.log("Error computing checksum: " .. resource)
		return interr()
	    end
	end
	self.resource.info.offset = cur_offset
	ngx.header["Upload-Offset"] = cur_offset
	if not sb:update_info(resource, self.resource.info) then
	    ngx.log(ngx.ERR, "Error updating resource metadata: " .. resource)
	    return interr()
	end
	exit_status(ngx.HTTP_NO_CONTENT)
	if cur_offset == self.resource.info.size then
	    self.resource.state = "completed"
	end
	return true
    end
end

return _M
