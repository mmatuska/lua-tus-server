#!/bin/sh
DIR=./t/tus_temp
set -e
mkdir -p $DIR

find $DIR -type f -exec rm {} \;

# Create some resources
echo '{"metadata":{"name":"test.txt","mimetype":"text/plain"},"offset":0,"size":10}' > $DIR/a25a7129d4e15fdce548ef0aad7a05b7.json
touch $DIR/a25a7129d4e15fdce548ef0aad7a05b7
echo '{"defer":1,"offset":0}' > $DIR/a786460cd69b3ff98c7ad5ad7ec95dc3.json
touch $DIR/a786460cd69b3ff98c7ad5ad7ec95dc3
# Expires "Sat, 01 Jan 2000 00:00:00 GMT"
echo '{"expires":946684800,"offset":0,"size":10}' > $DIR/c29e4d9b20fb6495843de87b2f508826.json
echo '{"offset":0,"size":75}' > $DIR/b0aeb37004e0480f15c60f650ee92e02.json
touch $DIR/b0aeb37004e0480f15c60f650ee92e02
echo '{"offset":0,"size":1000}' > $DIR/91670d3adeda5cb3a4fd1c9884dab498.json
touch $DIR/91670d3adeda5cb3a4fd1c9884dab498
echo '{"offset":0,"size":100,"concat_partial":true}' > $DIR/69ae186b699db22960f9d93b7068e67f.json
touch $DIR/69ae186b699db22960f9d93b7068e67f
echo '{"offset":0,"size":200,"concat_partial":true}'> $DIR/7a845f10fd7696b9df8b13c328c34c52.json
touch $DIR/7a845f10fd7696b9df8b13c328c34c52
echo '{"offset":0,"defer":1,"concat_partial":true}' > $DIR/03720362b6571cfffd17adfffb565375.json
touch $DIR/7a845f10fd7696b9df8b13c328c34c52
echo '{"offset":0,"defer":1,"concat_partial":true}' > $DIR/d4d0bf5e0c5fae7b1a900a972010cd58.json
touch $DIR/d4d0bf5e0c5fae7b1a900a972010cd58
echo '{"offset":0,"concat_final":["7a845f10fd7696b9df8b13c328c34c52","03720362b6571cfffd17adfffb565375"]}' > $DIR/12ca7f9a120c9919f8882096f9bd2bc4.json
touch $DIR/12ca7f9a120c9919f8882096f9bd2bc4

# Run tests
env TEST_NGINX_BINARY=/usr/local/openresty/bin/openresty prove -v
