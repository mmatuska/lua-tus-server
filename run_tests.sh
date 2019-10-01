#!/bin/sh
DIR=./t/tus_temp
set -e
mkdir -p $DIR

# Create some resources
echo '{"Upload-Metadata":{"name":"test.txt","mimetype":"text/plain"},"Upload-Offset":0,"Upload-Length":10}' > $DIR/a25a7129d4e15fdce548ef0aad7a05b7.json
touch $DIR/a25a7129d4e15fdce548ef0aad7a05b7
echo '{"Upload-Defer-Length":"1","Upload-Offset":0}' > $DIR/a786460cd69b3ff98c7ad5ad7ec95dc3.json
touch $DIR/a786460cd69b3ff98c7ad5ad7ec95dc3
echo '{"Upload-Expires":"Sat, 01 Jan 2000 00:00:00 GMT","Upload-Offset":0,"Upload-Length":10}' > $DIR/c29e4d9b20fb6495843de87b2f508826.json
echo '{"Upload-Offset":0,"Upload-Length":75}' > $DIR/b0aeb37004e0480f15c60f650ee92e02.json
touch $DIR/b0aeb37004e0480f15c60f650ee92e02
echo '{"Upload-Offset":0,"Upload-Length":1000}' > $DIR/91670d3adeda5cb3a4fd1c9884dab498.json
touch $DIR/91670d3adeda5cb3a4fd1c9884dab498

# Run tests
env TEST_NGINX_BINARY=/usr/local/openresty/bin/openresty perl t/suite.t
