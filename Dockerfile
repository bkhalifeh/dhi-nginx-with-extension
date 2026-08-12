FROM dhi.io/nginx:1.30.3-alpine3.24-dev AS build

RUN apk add --no-cache \
    gcc g++ libc-dev make cmake pkgconf \
    pcre2-dev zlib-dev openssl-dev \
    git jansson-dev wget \
    libmaxminddb-dev

WORKDIR /build

# libjwt 1.x (API the module targets), built as a shared, PIC library
RUN git clone --branch v1.17.2 --depth 1 https://github.com/benmcollins/libjwt.git \
    && cd libjwt && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_SHARED_LIBS=ON \
    -DWITHOUT_TESTS=ON .. \
    && make && make install

# nginx source must match the runtime nginx version exactly
RUN wget https://nginx.org/download/nginx-1.30.3.tar.gz && tar xzf nginx-1.30.3.tar.gz

RUN git clone https://github.com/max-lt/nginx-jwt-module.git
RUN git clone https://github.com/openresty/headers-more-nginx-module.git
RUN git clone --depth 1 https://github.com/leev/ngx_http_geoip2_module.git

WORKDIR /build/nginx-1.30.3
RUN ./configure --with-compat \
    --add-dynamic-module=../nginx-jwt-module \
    --add-dynamic-module=../headers-more-nginx-module \
    --add-dynamic-module=../ngx_http_geoip2_module \
    && make modules

FROM dhi.io/nginx:1.30.3-alpine3.24

COPY --from=build /build/nginx-1.30.3/objs/ngx_http_auth_jwt_module.so /var/lib/nginx/modules/
COPY --from=build /build/nginx-1.30.3/objs/ngx_http_headers_more_filter_module.so /var/lib/nginx/modules/
COPY --from=build /build/nginx-1.30.3/objs/ngx_http_geoip2_module.so /var/lib/nginx/modules/
COPY --from=build /usr/lib/libjwt.so* /usr/lib/
COPY --from=build /usr/lib/libjansson.so* /usr/lib/
COPY --from=build /usr/lib/libmaxminddb.so* /usr/lib/

RUN sed -i '1i load_module /var/lib/nginx/modules/ngx_http_auth_jwt_module.so;\nload_module /var/lib/nginx/modules/ngx_http_headers_more_filter_module.so;\nload_module /var/lib/nginx/modules/ngx_http_geoip2_module.so;' /etc/nginx/nginx.conf