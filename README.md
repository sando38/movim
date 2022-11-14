# [Movim](https://movim.eu/) docker image

This repository provides an inofficial [movim](https://github.com/movim/movim) docker container. There is also an official docker image available.

Differences to the official image are:

* built for `x86-64` and `arm64`
* runs as non-root user
* does not require any Linux capabilities
* s6-overlay to manage the different processes
* (is available also as an Alpine based image, which has an [issue](https://github.com/sando38/movim/issues/1), however)

Images are scanned daily by trivy and if necessary, the latest tag will be rebuilt and published.

## Tags

The image name is `ghcr.io/sando38/movim`. Images are available from tag `v0.21rc3` onwards. The first image build has a `-r0` suffix.

Experimental Alpine based images have an `-alpine` suffix.

| Tags  | Description  | Additional notes  |
| ------------ | ------------ | ------------ |
| `v0.21rc3`, `latest`  | [Release changelog](https://github.com/movim/movim/blob/master/CHANGELOG.md)  |   |
| `v0.21rc3-alpine`, `latest-alpine`  | [Release changelog](https://github.com/movim/movim/blob/master/CHANGELOG.md)  |   |

All images are based upon the official `php-fpm` docker images with latest OS (e.g. `Debian bullseye`).

## Configuration (overview)

The easiest way is to clone the repo:

    git clone https://github.com/sando38/movim

Afterwards, those two files need to be adjusted:

* docker-compose.yml
* movim.env

If both have been adjusted, start the stack with:

    docker compose up -d

Movim starts [w/o any admins](https://github.com/movim/movim/blob/master/INSTALL.md#5-admin-panel). An admin could be defined with:

    docker exec movim php daemon.php setAdmin {jid}

### docker-compose.yml

There are some aspects to double check:

* Image build vs. pre-build image
* `postgresql` configuration
* `nginx` configuration

You need to decide wether to `build` the image yourself or to use the pre-build `image` (default). Either way, one of the parts must be commented:

```yml
services:
  movim:
    ### general settings
    image: ghcr.io/sando38/movim:latest
    #build:
    #  context: image/.
    #  dockerfile: Dockerfile.debian
    ...
```

Additionally, movim relies on a database server. It works with `postgresql` (recommended) or `mysql`/`mariadb`. If you run a database server already, you should comment the `postgresql` part of the `docker-compose.yml` file. If not, at least the `POSTGRES_PASSWORD` should be changed to something save. This password must be the same as provided to movim with the variable `DB_PASSWORD`, e.g. within the `movim.env` file.

```yml
  ...
  postgresql:
    hostname: postgresql
    container_name: postgresql
    image: postgres:14-alpine
    ...
```

Lastly, check the provided `nginx` configuration. Either you use an already existing webserver or this configuration. This repo also provides some [configuration examples](appdata/nginx) for nginx (w/ and w/o TLS). If TLS certificates are mounted into the container, the nginx user (`101:101`) should be able to read them.

### movim.env

This file contains the environment variables, which are read by movim during startup. Here is the link to the official installation document from the movim repository:

[https://github.com/movim/movim/blob/master/INSTALL.md#2-dotenv-configuration](https://github.com/movim/movim/blob/master/INSTALL.md#2-dotenv-configuration)

## ToDos

Potential ToDos for the future:

* Fix Alpine container image
* Integrate nginx into the movim image

## Feedback

Feel free to provide feedback. If there is an issue or anything, please use the issue tracker.