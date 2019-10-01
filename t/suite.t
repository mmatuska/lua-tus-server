use Test::Nginx::Socket::Lua;

plan tests => 110;
no_shuffle();
run_tests();

__DATA__
 
=== Block A1: OPTIONS
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus:process_request()
        }
    }
--- request
OPTIONS /upload/
--- response_headers
Tus-Resumable: 1.0.0
Tus-Version: 1.0.0
Tus-Extension: checksum,creation,creation-defer-length,expiration,termination
Tus-Checksum-Algorithm: md5,sha1,sha256
--- error_code: 204

=== Block A2: OPTIONS via X-Http-Method-Override
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus:process_request()
        }
    }
--- request
GET /upload/
--- more_headers
X-Http-Method-Override: OPTIONS
--- response_headers
Tus-Resumable: 1.0.0
Tus-Version: 1.0.0
Tus-Extension: checksum,creation,creation-defer-length,expiration,termination
Tus-Checksum-Algorithm: md5,sha1,sha256
--- error_code: 204

=== Block A3: OPTIONS with creation extension disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
	    tus.config.extension.creation = false
            tus:process_request()
        }
    }
--- request
OPTIONS /upload/
--- response_headers
Tus-Resumable: 1.0.0
Tus-Version: 1.0.0
Tus-Extension: checksum,expiration,termination
Tus-Checksum-Algorithm: md5,sha1,sha256
--- error_code: 204

=== Block A4: OPTIONS with checksum extension disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
	    tus.config.extension.checksum = false
            tus:process_request()
        }
    }
--- request
OPTIONS /upload/
--- response_headers
Tus-Resumable: 1.0.0
Tus-Version: 1.0.0
Tus-Extension: creation,creation-defer-length,expiration,termination
!Tus-Checksum-Algorithm
--- error_code: 204

=== Block A5: OPTIONS with all extensions disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
	    tus.config.extension.checksum = false
	    tus.config.extension.creation = false
	    tus.config.extension.creation_defer_length = false
	    tus.config.extension.expiration = false
	    tus.config.extension.termination = false
            tus:process_request()
        }
    }
--- request
OPTIONS /upload/
--- response_headers
Tus-Resumable: 1.0.0
Tus-Version: 1.0.0
!Tus-Extension
!Tus-Checksum-Algorithm
--- error_code: 204

=== Block B1: Invalid method GET
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus:process_request()
        }
    }
--- request
GET /upload/
--- error_code: 405

=== Block B2: Invalid method PUT
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus:process_request()
        }
    }
--- request
    PUT /upload/
--- error_code: 405

=== Block C1: POST without Tus-Resumable
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
            tus:process_request()
        }
    }
--- request
POST /upload/
--- error_code: 412

=== Block C2: POST with invalid Tus-Resumable
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 0.9.9
--- request
    POST /upload/
--- error_code: 412

=== Block C3: POST only with valid Tus-Resumable
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
POST /upload/
--- error_code: 400

=== Block C4: POST with negative Upload-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: -1
--- request
    POST /upload/
--- error_code: 400

=== Block C5: POST with zero Upload-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 0
--- request
POST /upload/
--- response_headers_like
Tus-Resumable: 1\.0\.0
Location: http://localhost/upload/[\da-f]+
--- error_code: 201

=== Block C6: POST with positive Upload-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
--- request
POST /upload/
--- response_headers_like
Tus-Resumable: 1\.0\.0
Location: http://localhost/upload/[\da-f]+
--- error_code: 201

=== Block C7: POST with creation disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.creation = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
--- request
POST /upload/
--- error_code: 405

=== Block C8: POST with Upload-Length exceeding Tus-Max-Size
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.max_size = 1048576
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 1048577
--- request
POST /upload/
--- error_code: 413

=== Block C9: POST with positive Upload-Length and Upload-Defer-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Defer-Length: 1
--- request
POST /upload/
--- error_code: 400

=== Block C10: POST with invalid Upload-Defer-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Defer-Length: abc
--- request
    POST /upload/
--- error_code: 400

=== Block C11: POST with valid Upload-Defer-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Defer-Length: 1
--- request
POST /upload/
--- response_headers_like
Tus-Resumable: 1\.0\.0
Location: http://localhost/upload/[\da-f]+
--- error_code: 201

=== Block C12: POST with Upload-Defer-Length and creation-defer-length disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.creation_defer_length = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Defer-Length: 1
--- request
POST /upload/
--- error_code: 400

=== Block C13: POST returning Upload-Expires
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config["expire_timeout"] = 3600
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
--- request
POST /upload/
--- response_headers_like
Tus-Resumable: 1\.0\.0
Upload-Expires: (Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d\d (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d\d\d\d \d\d:\d\d:\d\d GMT
Location: http://localhost/upload/[\da-f]+
--- error_code: 201

=== Block C14: POST with invalid Upload-Metadata 1
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Metadata: testkey testval-
--- request
POST /upload/
--- error_code: 400

=== Block C15: POST with invalid Upload-Metadata 2
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Metadata: testkey dGVzdHZhbA== aa
--- request
    POST /upload/
--- error_code: 400

=== Block C16: POST with invalid Upload-Metadata 3
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Metadata: testkey dGVzdHZhbA==,
--- request
POST /upload/
--- error_code: 400

=== Block C17: POST with invalid Upload-Metadata 4
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Metadata: testkey dGVzdHZhbA==,testkey2 testval*
--- request
    POST /upload/
--- error_code: 400

=== Block C18: POST with valid Upload-Metadata 5
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Metadata: testkey dGVzdHZhbA==,testkey2 dGVzdHZhbDI=
--- response_headers_like
Tus-Resumable: 1\.0\.0
Location: http://localhost/upload/[\da-f]+
--- request
POST /upload/
--- error_code: 201

=== Block D1: HEAD on non-existing resource
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
HEAD /upload/1234567890
--- error_code: 404

=== Block D2: HEAD on existing resource
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
HEAD /upload/a25a7129d4e15fdce548ef0aad7a05b7
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Length: 10
Upload-Metadata: mimetype dGV4dC9wbGFpbg==,name dGVzdC50eHQ=
--- error_code: 204

=== Block D3: HEAD on resource with Upload-Defer-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
    HEAD /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Defer-Length: 1
--- error_code: 204

=== Block D4: HEAD on resource with Upload-Defer-Length with ext disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.creation_defer_length = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
    HEAD /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
--- error_code: 403

=== Block E1: PATCH without Content-Type
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 6
--- request
PATCH /upload/a25a7129d4e15fdce548ef0aad7a05b7
123456
--- error_code: 415

=== Block E2: PATCH with invalid Content-Type
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 6
Content-Type: application/octet-stream
--- request
PATCH /upload/a25a7129d4e15fdce548ef0aad7a05b7
123456
--- error_code: 415

=== Block E3: PATCH without Upload-Offset
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 6
Content-Type: application/offset+octet-stream
--- request
PATCH /upload/a25a7129d4e15fdce548ef0aad7a05b7
123456
--- error_code: 409

=== Block E4: PATCH first chunk
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 6
Content-Type: application/offset+octet-stream
Upload-Offset: 0
--- request
PATCH /upload/a25a7129d4e15fdce548ef0aad7a05b7
123456
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 6
--- error_code: 204

=== Block E5: PATCH chunk exceeding Upload-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 6
Content-Type: application/offset+octet-stream
Upload-Offset: 6
--- request
PATCH /upload/a25a7129d4e15fdce548ef0aad7a05b7
789012
--- error_code: 409

=== Block E6: PATCH last chunk
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 4
Content-Type: application/offset+octet-stream
Upload-Offset: 6
--- request
PATCH /upload/a25a7129d4e15fdce548ef0aad7a05b7
7890
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 10
--- error_code: 204

=== Block E7: HEAD on completed upload
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
HEAD /upload/a25a7129d4e15fdce548ef0aad7a05b7
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 10
Upload-Length: 10
Upload-Metadata: mimetype dGV4dC9wbGFpbg==,name dGVzdC50eHQ=
--- error_code: 204

=== Block E8: PATCH on Upload-Defer-Length without Upload-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 6
Content-Type: application/offset+octet-stream
Upload-Offset: 0
--- request
PATCH /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
123456
--- error_code: 409

=== Block E9: PATCH on Upload-Defer-Length with Upload-Length > Tus_Max_Size
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.max_size = 1048576
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 8
Content-Type: application/offset+octet-stream
Upload-Offset: 0
Upload-Length: 1048577
--- request
PATCH /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
12345678
--- error_code: 413

=== Block E10: PATCH on Upload-Defer-Length with ext disabled
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.creation_defer_length = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 8
Content-Type: application/offset+octet-stream
Upload-Offset: 0
Upload-Length: 20
--- request
PATCH /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
12345678
--- error_code: 403

=== Block E11: PATCH on Upload-Defer-Length with valid Upload-Length
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 8
Content-Type: application/offset+octet-stream
Upload-Offset: 0
Upload-Length: 20
--- request
PATCH /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
12345678
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 8
--- error_code: 204

=== Block E12: HEAD on partial upload
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
HEAD /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 8
Upload-Length: 20
--- error_code: 204

=== Block E13: HEAD on expired upload
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
HEAD /upload/c29e4d9b20fb6495843de87b2f508826
--- error_code: 410

=== Block E14: HEAD on expired upload without expiration extension
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.expiration = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
HEAD /upload/c29e4d9b20fb6495843de87b2f508826
--- response_headers
Tus-Resumable: 1.0.0
Upload-Length: 10
Upload-Offset: 0
--- error_code: 204

=== Block F1: DELETE on existing resource without termination extension
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.termination = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
DELETE /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
--- error_code: 405

=== Block F2: DELETE on existing resource
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
DELETE /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
--- error_code: 204

=== Block F3: DELETE on non-existing resource
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request
DELETE /upload/a786460cd69b3ff98c7ad5ad7ec95dc3
--- error_code: 404

=== Block G1: PATCH with badly encoded checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: md5 .fsdaq-
Upload-Offset: 0
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- error_code: 400

=== Block G2: PATCH with unsupported checksum algorithm
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: crc32 ZWZjMGRlNTc=
Upload-Offset: 0
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- error_code: 400

=== Block G3: PATCH with invalid MD5 checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: md5 ZTgwN2YxZmNmODJkMTMyZjliYjAxOGNhNjczOGExOWY=
Upload-Offset: 0
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- error_code: 460

=== Block G4: PATCH with valid MD5 checksum without checksum extension
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.checksum = false
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: md5 OWE3ODk2MjVmMzhhNjg2MDI3ZWI1ZjdkYTM0OThjNjA=
Upload-Offset: 0
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- error_code: 400

=== Block G5: PATCH with valid MD5 checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: md5 OWE3ODk2MjVmMzhhNjg2MDI3ZWI1ZjdkYTM0OThjNjA=
Upload-Offset: 0
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- respose_headers
Tus-Resumable: 1.0.0
Upload-Offset: 25
--- error_code: 204

=== Block G6: PATCH with invalid SHA1 checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: sha1 MDFiMzA3YWNiYTRmNTRmNTVhYWZjMzNiYjA2YmJiZjZjYTgwM2U5YQ==
Upload-Offset: 25
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- error_code: 460

=== Block G7: PATCH with valid SHA1 checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: sha1 YTBjODRiOWJlZDdhNmI0YTcwNjgwYWFjYzgwZWM3OGNiMzhmMTk3YQ==
Upload-Offset: 25
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- respose_headers
Tus-Resumable: 1.0.0
Upload-Offset: 25
--- error_code: 204

=== Block G8: PATCH with invalid SHA256 checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: sha256 Yzc3NWU3Yjc1N2VkZTYzMGNkMGFhMTExM2JkMTAyNjYxYWIzODgyOWNhNTJhNjQyMmFiNzgyODYyZjI2ODY0Ng==
Upload-Offset: 50
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- error_code: 460

=== Block G9: PATCH with valid SHA256 checksum
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 25
Content-Type: application/offset+octet-stream
Upload-Checksum: sha256 ZjI1NDNmZmRiNGFmZjkyNjVhZDAzMzdkM2MyNmU1ZmVjOWNhNzg0MDRlMTgwYThhMzFlZDlhZWQxNTIwZGNiNg==
Upload-Offset: 50
--- request
PATCH /upload/b0aeb37004e0480f15c60f650ee92e02
1234567890123456789012345
--- respose_headers
Tus-Resumable: 1.0.0
Upload-Offset: 25
--- error_code: 204

=== Block G10: PATCH with SHA256 sum and internal multi-chunk
--- config
    location /upload/ {
        content_by_lua_block {
            local tus = require "tus.server"
            tus.config.resource_url_prefix = "http://localhost/upload"
	    tus.config.chunk_size = 100
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
            tus:process_request()
        }
    }
--- more_headers
Tus-Resumable: 1.0.0
Content-Length: 500
Content-Type: application/offset+octet-stream
Upload-Checksum: sha256 ZTUwNmYwMzlmODNjZDM3OGQyYmIxMGQ1MzlhNzliZGIwYTFlNTBkZjZhMzk1OTEwNDk5NzBkMDEzNTkxMmRjMA==
Upload-Offset: 0
--- request
PATCH /upload/91670d3adeda5cb3a4fd1c9884dab498
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
1234567890123456789012345678901234567890123456789
12345678901234567890123456789012345678901234567890
--- respose_headers
Tus-Resumable: 1.0.0
Upload-Offset: 500
--- error_code: 204
