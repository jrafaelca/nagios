# Nagios Core Docker

This repo builds a clean Ubuntu-based Nagios Core image and keeps the private site-specific config outside the image.

## Layout

- `docker/` contains the generic image assets that ship with Nagios.
- `objects/` is the direct Nagios object mount for the editable base and custom definitions.
- `plugins/` is the direct mount for private check scripts.
- `secrets/` is the direct mount for SSH keys and other sensitive files.


## Quick start

For local development:

```bash
docker compose up -d --build
```

Then open:

```text
http://localhost:8080/
```

There is no baked-in password.
`NAGIOS_ADMIN_USER` is set to `nagios` in `.env.example`, but you should set
your own password in `.env` before starting the stack.

If you use `.env.example`, copy it to `.env` first and change the password
before starting Nagios.

If Nagios sits behind an ALB or any TLS terminator, set `NAGIOS_FORCE_SSL=true`
so the container trusts `X-Forwarded-Proto` and upgrades insecure browser
requests.

Set `TZ` in `.env` if you want Nagios to show timestamps in your local zone,
for example `UTC`.



## Use The Image

The published image is:

```text
ghcr.io/jrafaelca/nagios:latest
```

Use it from your own Compose file in production. A minimal example:

```yaml
services:
  nagios:
    image: ghcr.io/jrafaelca/nagios:latest
    restart: unless-stopped
    env_file: .env
    ports:
      - "8080:80"
    volumes:
      - nagios-data:/usr/local/nagios/var
      - ./objects:/usr/local/nagios/etc/objects
      - ./plugins:/usr/local/nagios/libexec/plugins
      - ./secrets:/usr/local/nagios/libexec/secrets

volumes:
  nagios-data:
```

## What lives where

- Generic runtime wiring ships in the image under `docker/nagios/`
- The editable starting objects live in `objects/`
- Custom scripts live in `plugins/`
- SSH keys and other secrets live in `secrets/`

## Image Env Vars

The container reads these environment variables:

| Variable | Purpose |
| --- | --- |
| `NAGIOS_ADMIN_USER` | Basic-auth username for the Nagios web UI and CGI access. |
| `NAGIOS_ADMIN_PASSWORD` | Basic-auth password for the Nagios web UI and CGI access. |
| `NAGIOS_FORCE_SSL` | Set to `true` when TLS is terminated upstream so Apache adds HTTPS-aware headers. |
| `TZ` | Container timezone used by Nagios logs and timestamps. |

Compose-only variables:

| Variable | Purpose |
| --- | --- |
| `FORWARD_PORT` | Host port published to container port `80` for local development. |
