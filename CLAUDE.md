# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo builds a hardened nginx container image on top of Docker Hardened Images (DHI), extended with three dynamic modules that aren't present in the base DHI nginx image:

- **nginx-jwt-module** (`max-lt/nginx-jwt-module`) — JWT authentication/validation, linked against libjwt 1.x
- **headers-more-nginx-module** (`openresty/headers-more-nginx-module`) — fine-grained control over response headers
- **ngx_http_geoip2_module** (`leev/ngx_http_geoip2_module`) — GeoIP2 lookups via libmaxminddb

The image is a single multi-stage `Dockerfile`: a `build` stage compiles nginx source plus the three modules as `.so` files against `dhi.io/nginx:1.30.3-alpine3.24-dev`, then the final stage copies only the compiled `.so` modules and their runtime shared libraries onto the slim, non-dev `dhi.io/nginx:1.30.3-alpine3.24` base and wires them up via `load_module` directives injected into `nginx.conf`.

## Build

```bash
docker build -t dhi-nginx-with-extension .
```

## CI/CD

`.github/workflows/ci.yml` builds and pushes the image to `ghcr.io/<repo>` on every push to `main` (tags: `latest` + commit SHA, `linux/amd64` only; PRs build but don't push). Since the runtime base image lives on `dhi.io`, a gated registry, the workflow logs in with `DHI_USERNAME`/`DHI_TOKEN` secrets in addition to `GITHUB_TOKEN` for GHCR — both must stay valid or the build fails at the base-image pull.

## Critical constraints when editing the Dockerfile

- **nginx version must stay in lockstep across three places**: the DHI base image tag (both `FROM` lines), the `nginx-X.Y.Z.tar.gz` download URL, and the runtime base image tag. Dynamic modules are ABI-compatible only with the exact nginx version/build flags they were compiled against — mismatches fail silently at `load_module` time or crash at runtime. If bumping nginx, update all four occurrences together.
- **Modules are built with `--add-dynamic-module`, not statically**. The build-stage `./configure` flags must retain `--with-compat` so the resulting `.so` files stay loadable by the prebuilt runtime nginx binary in the non-dev DHI base.
- **Final stage only copies build artifacts, never build tooling**: the `.so` module files and their runtime `.so*` shared libs (`libjwt`, `libjansson`, `libmaxminddb`). Do not copy compilers, headers, static libs, or source trees into the final stage — that defeats the purpose of using the slim DHI runtime base.
- **libjwt is pinned to v1.17.2 (1.x API)** — the nginx-jwt-module targets the libjwt 1.x API, which differs from libjwt 2.x. Do not bump libjwt across a major version without checking module compatibility.
- **`load_module` lines are injected via `sed -i '1i ...'`** into `/etc/nginx/nginx.conf` in the final stage rather than editing a config file directly in the repo, since no nginx.conf is tracked here. Load-order matters if adding more modules — new `load_module` lines should be added to the same `sed` insert.
- When adding a new dynamic module, follow the existing pattern: clone the module source in the build stage, add it to the `--add-dynamic-module` list, copy the resulting `.so` (and any new runtime shared-lib dependency) into the final stage, and add its `load_module` line to the `sed` command.
