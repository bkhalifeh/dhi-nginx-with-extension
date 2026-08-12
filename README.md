# dhi-nginx-with-extension

A hardened nginx container image built on [Docker Hardened Images](https://www.docker.com/products/hardened-images/) (DHI), extended with three dynamic modules not included in the base DHI nginx image:

- **[nginx-jwt-module](https://github.com/max-lt/nginx-jwt-module)** — JWT authentication/validation, built against libjwt 1.x
- **[headers-more-nginx-module](https://github.com/openresty/headers-more-nginx-module)** — fine-grained control over request/response headers
- **[ngx_http_geoip2_module](https://github.com/leev/ngx_http_geoip2_module)** — GeoIP2 lookups via libmaxminddb

## How it works

The `Dockerfile` is a multi-stage build:

1. **Build stage** (`dhi.io/nginx:1.30.3-alpine3.24-dev`) — installs build tooling, compiles libjwt 1.17.2 from source, downloads the matching nginx 1.30.3 source tarball, clones the three module repos, and compiles them as dynamic modules (`--add-dynamic-module`) against that exact nginx source.
2. **Final stage** (`dhi.io/nginx:1.30.3-alpine3.24`, the slim non-dev DHI runtime image) — copies over only the compiled `.so` module files and their runtime shared libraries (`libjwt`, `libjansson`, `libmaxminddb`), then injects `load_module` directives into `nginx.conf` so nginx loads them at startup.

No build tooling, compilers, headers, or source trees end up in the final image — only the runtime artifacts.

## Pull

A GitHub Actions workflow (`.github/workflows/ci.yml`) builds and pushes this image to GHCR on every push to `main`, tagged `latest` and with the commit SHA (`linux/amd64` only):

```bash
docker pull ghcr.io/bkhalifeh/dhi-nginx-with-extension:latest
```

## Build

```bash
docker build -t dhi-nginx-with-extension .
```

## Run

```bash
docker run -p 8080:80 dhi-nginx-with-extension
```

Mount your own `nginx.conf` / site config to actually make use of the JWT, headers-more, or GeoIP2 directives:

```bash
docker run -p 8080:80 -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro dhi-nginx-with-extension
```

## Notes

- nginx version is pinned in four places (both DHI base image tags, the nginx source tarball URL, and the runtime base image tag) and must be kept in lockstep — dynamic modules are only ABI-compatible with the exact nginx version/build flags they were compiled against.
- libjwt is pinned to v1.17.2 since nginx-jwt-module targets the libjwt 1.x API, not 2.x.

See `CLAUDE.md` for more detail on the build's constraints and how to safely extend it with additional modules.
