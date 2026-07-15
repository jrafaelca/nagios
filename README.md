# Nagios Core Docker

This repo now contains a clean Ubuntu-based Docker image for Nagios Core.

## Quick start

For local development, build and run the local Compose file:

```bash
docker compose -f compose.local.yaml up -d --build
```

Then open:

```text
http://localhost:8080/
```

Default credentials:

- user: `nagiosadmin`
- password: `nagiosadmin`

## Deploy From GHCR

Set `NAGIOS_IMAGE` to the published image and run the deploy Compose file:

```bash
export NAGIOS_IMAGE=ghcr.io/your-org/nagios-example:latest
docker compose up -d
```

By default the container is published on host port `8080`.

## What is included

- Ubuntu base image
- Apache
- Nagios Core built from source
- Minimal local config for `Service Status Details`
- Simple localhost host/service checks
- Extensible `objects/` config tree and `plugins/` folder
- Persistent runtime volume for `var/`

## How To Extend

Add your own Nagios object definitions under:

- `docker/nagios/objects/`

Put any custom check scripts or helpers under:

- `docker/nagios/plugins/`

The local Compose file only persists runtime data in `var/`; the image bakes in the Nagios config and plugins so other developers can extend the starter image by editing the repo and rebuilding.

## What is excluded for now

- `nagiosgraph`
- host snapshot configs
- custom production checks from the remote server
