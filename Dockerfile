FROM openresty/openresty:1.15.8.2-1-alpine
RUN apk update && apk add luacheck perl-utils perl-test-nginx
COPY ./ /lua-tus-server/
CMD cd /lua-tus-server && ./run_tests.sh

