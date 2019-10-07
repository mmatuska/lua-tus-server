use Test::Nginx::Socket::Lua;

plan tests => 64;
no_shuffle();
run_tests();

__DATA__
 
=== Block C5A HEAD on resource created in C5
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
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
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Length: 0
!Upload-Defer-Length
--- error_code: 204

=== Block C6A HEAD on resource created in C6
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
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
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Length: 10
!Upload-Defer-Legnth
--- error_code: 204

=== Block C11A HEAD on resource created in C11
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
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
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Defer-Length: 1
!Upload-Length
--- error_code: 204

=== Block C13A HEAD on resource created in C13
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
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
	    tus.config.upload_url = "/upload"
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
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Length: 10
Upload-Metadata: testkey dGVzdHZhbA==,testkey2 dGVzdHZhbDI=
!Upload-Defer-Length
--- error_code: 204

=== Block C21A HEAD on resource created in C21
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c21.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
Upload-Length: 10
Upload-Concat: partial
!Upload-Defer-Length
--- error_code: 204

=== Block C21B HEAD on resource created in C21 without concat
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.concatenation = false
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c21.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- error_code: 403

=== Block C22A HEAD on resource created in C22
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c22.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Offset: 0
!Upload-Length
Upload-Defer-Length: 1
Upload-Concat: partial
--- error_code: 204
 
=== Block C28A HEAD on resource created in C28
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c28.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Length: 100
Upload-Concat: final;/upload/69ae186b699db22960f9d93b7068e67f
!Upload-Offset
--- error_code: 204

=== Block C29A HEAD on resource created in C29
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c29.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Length: 300
Upload-Concat: final;/upload/69ae186b699db22960f9d93b7068e67f /upload/7a845f10fd7696b9df8b13c328c34c52
!Upload-Offset
--- error_code: 204

=== Block C30A HEAD on resource created in C30
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/c30.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Concat: final;/upload/69ae186b699db22960f9d93b7068e67f /upload/03720362b6571cfffd17adfffb565375
!Upload-Offset
!Upload-Length
--- error_code: 204

=== Block H4A HEAD on resource created in H4 without concanetation-unfinished
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus.config.extension.concatenation_unfinished = false
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/h4.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Concat: final;/upload/7a845f10fd7696b9df8b13c328c34c52 /upload/d4d0bf5e0c5fae7b1a900a972010cd58
Upload-Offset: 350
Upload-Length: 350
--- error_code: 204

=== Block H4B HEAD on resource created in H4 with concanetation-unfinished
--- config
    location /upload/ {
	content_by_lua_block {
	    local tus = require "tus.server"
	    tus.config.upload_url = "/upload"
	    tus.config.storage_backend = "tus.storage_file"
	    tus.config.storage_backend_config.storage_path = "./t/tus_temp"
	    tus:process_request()
	}
    }
--- more_headers
Tus-Resumable: 1.0.0
--- request eval
open my $fh, "<", "./t/tus_temp/h4.location";
my $loc = <$fh>;
close $fh;
"HEAD ".$loc
--- response_headers
Tus-Resumable: 1.0.0
Upload-Concat: final;/upload/7a845f10fd7696b9df8b13c328c34c52 /upload/d4d0bf5e0c5fae7b1a900a972010cd58
Upload-Offset: 350
Upload-Length: 350
--- error_code: 204
