use Test::Nginx::Socket::Lua;

plan tests => 17;
no_shuffle();
run_tests();

__DATA__
 
=== Block C5A HEAD on resource created in C5
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.resource_url_prefix = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c5.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers_like
Tus-Resumable: 1\.0\.0
Upload-Offset: 0
Upload-Length: 0
--- error_code: 204

=== Block C6A HEAD on resource created in C6
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.resource_url_prefix = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c6.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers_like
Tus-Resumable: 1\.0\.0
Upload-Offset: 0
Upload-Length: 10
--- error_code: 204

=== Block C11A HEAD on resource created in C11
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.resource_url_prefix = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c11.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers_like
Tus-Resumable: 1\.0\.0
Upload-Offset: 0
Upload-Defer-Length: 1
--- error_code: 204

=== Block C13A HEAD on resource created in C13
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.resource_url_prefix = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c13.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers_like
Tus-Resumable: 1\.0\.0
Upload-Offset: 0
Upload-Length: 10
Upload-Expires: (Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d\d (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d\d\d\d \d\d:\d\d:\d\d GMT
--- error_code: 204

=== Block C18A HEAD on resource created in C18
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.resource_url_prefix = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c18.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers_like
Tus-Resumable: 1\.0\.0
Upload-Offset: 0
Upload-Length: 10
Upload-Metadata: testkey dGVzdHZhbA==,testkey2 dGVzdHZhbDI=
--- error_code: 204
