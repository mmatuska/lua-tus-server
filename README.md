# lua-tus-server

Server-side implementation of the [tus](https://tus.io/) protocol in Lua.

## Features

- [tus protocol 1.0.0](https://tus.io/protocols/resumable-upload.html)
- tus extensions:
  - checksum (md5, sha1, sha256)
  - concatenation
  - concatenation-unfinished
  - creation
  - creation-defer-length
  - expiration
  - termination
- each tus extension can be individually disabled
- resource locking via NGINX Lua shared memoy zones
- soft and hard deleteion of resources

## Requiremens

- [OpenResty](https://openresty.org) or [NGINX](https://www.nginx.com) with [mod\_lua](https://github.com/openresty/lua-nginx-module)
- [lua-resty-string](https://github.com/openresty/lua-resty-string)
- [lua-cjson](https://www.kyne.com.au/~mark/software/lua-cjson.php)

## Synopsis


```lua
    lua_package_path "/path/to/lua-tus-server/lib/?.lua;;";
    lua_shared_dict tuslock 10m;

    server {
        location /upload/ {
            content_by_lua_block {
                local tus_server = require "tus.server"
                local tus = tus_server:new()
                tus.config.storage_backend = "tus.storage_file"
                tus.config.storage_backend_config.storage_path = "/tmp"
                tus.config.storage_backend_config.lock_zone = ngx.shared.tuslock
                tus.config.upload_url = "/upload"
                tus.config.expire_timeout = 1209600
                tus:process_request()

                if tus.resource.name and tus.resource.state == "completed" then
                    local path = tus.sb:get_path(tus.resource.name)
                    os.rename(path, "/tmp/newfile")
                    tus.sb:delete(tus.resource.name)
                end
            }
        }
    }
```

## Todo

- concatenation does not merge the resources yet

## License
MIT
