# Nagios Core Docker

This repo builds a clean Ubuntu-based Nagios Core image and exposes the standard Nagios directories directly on the host.

## Layout

- `docker/` contains the generic image assets that ship with Nagios.
- `etc/nagios.cfg` and `etc/objects/` contain the editable Nagios configuration mounted at runtime.
- Standard plugins are installed in the image under `/usr/lib/nagios/plugins`.
- `var/` contains Nagios runtime state and logs.


## Quick start

For local development:

```bash
docker compose up -d --build
```

Then open:

```text
http://localhost:8080/
```

The image includes a default `nagiosadmin` entry in `htpasswd.users` only as a
starting point. Set `NAGIOS_HTPASSWD` in `.env` before using the image for
anything real. If you add another user, include its hashed entry in the same
variable.

If you use `.env.example`, copy it to `.env` first and adjust the non-auth
values you need.

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
      - ./etc/nagios.cfg:/usr/local/nagios/etc/nagios.cfg
      - ./etc/objects:/usr/local/nagios/etc/objects
      - ./var:/usr/local/nagios/var
```

## What lives where

- Generic runtime wiring ships in the image under `docker/nagios/`
- The editable main config lives in `etc/nagios.cfg`
- Editable object definitions live in `etc/objects/`
- Standard plugins live in the image under `/usr/lib/nagios/plugins`
- Runtime state and logs live in `var/`

On first boot the container seeds `cgi.cfg` and writes the value of
`NAGIOS_HTPASSWD` to the authentication file Apache expects. The example
`.env.example` contains the default user `nagiosadmin` with the temporary
password `password`; change this value before using the image for anything
real.
The `cgi.cfg` file is generated with `nagiosadmin` as the authorized user.

To change the password, generate a new hash and pass the resulting line
through the environment:

```bash
htpasswd -nbB nagiosadmin 'your-password'
```

Set only the generated `nagiosadmin:$...` line in `.env`. Escape line breaks
as `\n` when configuring multiple users:

```dotenv
NAGIOS_HTPASSWD='nagiosadmin:$2y$...\notheruser:$2y$...'
```

`NAGIOS_HTPASSWD` must contain hashed entries, never a plaintext password.
The entrypoint writes the value to the authentication file at startup.

## Image Env Vars

The container reads these environment variables:

| Variable | Purpose |
| --- | --- |
| `NAGIOS_HTPASSWD` | Optional pre-hashed `htpasswd` entries. Overrides `etc/htpasswd.users`. |
| `NAGIOS_FORCE_SSL` | Set to `true` when TLS is terminated upstream so Apache adds HTTPS-aware headers. |
| `TZ` | Container timezone used by Nagios logs and timestamps. |

Compose-only variables:

| Variable | Purpose |
| --- | --- |
| `FORWARD_PORT` | Host port published to container port `80` for local development. |
