# Hikari API

[简体中文](../README.md)

Hikari API is a lightweight backend for Hikari. It receives status JSON uploaded by Android, stores the latest status, and cleans raw fields into structured JSON for the blog status card.

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/hikari/upload` | Android raw status upload |
| `GET` | `/hikari/status` | Cleaned status for the blog |
| `GET` | `/hikari/health` | Health check |

No status:

```json
{
  "online": false,
  "updated_at": null,
  "data": null
}
```

Latest status:

```json
{
  "online": true,
  "updated_at": "2026-06-07T15:30:00+08:00",
  "data": {
    "device_name": "Example Phone",
    "battery_level": 86,
    "battery_charging": true,
    "wifi_connected": true,
    "wifi_ssid": "Example WiFi",
    "network_type": "4G | 5G",
    "current_app": "Example App",
    "province": "Example Province",
    "city": "Example City",
    "district": "Example District"
  }
}
```

## Processing

Android upload fields come from `hikari-android`:

```json
{
  "model": "EXAMPLE_MODEL",
  "battery_raw": "dumpsys battery output",
  "wifi_raw": "Wi-Fi status output",
  "net_raw": "LTE,NR",
  "location_raw": "last location output",
  "current_app_package": "app.placeholder.demo",
  "current_app_name": "Example App"
}
```

If the input is a receiver log object, the API also reads the nested `data` object:

```json
{
  "received_at": "2026-06-07T21:28:29.696091",
  "client_ip": "203.0.113.10",
  "data": {
    "model": "EXAMPLE_MODEL"
  }
}
```

Processing rules:

- `model` can be mapped through `processing.device_aliases`; otherwise it is returned as-is.
- `battery_raw` is parsed into `battery_level` and `battery_charging`.
- `wifi_raw` is parsed into `wifi_connected` and `wifi_ssid`.
- `net_raw` is normalized through `processing.network_aliases`, such as `5G` or `4G`. Multi-SIM network values are kept in order, for example `LTE,NR` becomes `4G | 5G`.
- `current_app` uses the uploaded `current_app_name` directly. No package-name dictionary is maintained.
- `location_raw` extracts coordinates and calls the Amap reverse geocoding API, then outputs `province/city/district`.
- Direct `location_text`, `location`, and `province/city/district` uploads are also accepted.
- Values listed in `status.private_values` are treated as intentionally hidden, such as `none` from Android private mode.

Display delay is controlled by the Android app or frontend policy. The API no longer delays publishing and only processes data.

## Storage And Cache

- The API stores only the latest input and does not keep history.
- The input storage path is controlled by `storage.path`, defaulting to `data/status.json`.
- The stored file contains `id`, `received_at`, and the unprocessed `raw` input data.
- If the upload is a receiver log object, the nested `data` object is stored as `raw`.
- `/hikari/status` output is not stored separately. It is generated from `raw`, config, and geocoding results on each request.
- Reverse geocoding results are cached in memory. The cache TTL is controlled by `geocode.cache_ttl_seconds`, defaulting to 24 hours.
- Reverse geocoding failures are logged and retried after `geocode.timeout_seconds * 2`. During the retry wait, a previous successful address is returned when available.
- The geocoding cache and failure retry state are not written to a file or database and are lost when the API restarts.

## Configuration

Copy and edit the YAML config:

```powershell
Copy-Item config.example.yaml config.yaml
```

Configuration items:

| Key | Description |
| --- | --- |
| `auth.upload_token` | Bearer Token used by Android status uploads. |
| `auth.require_upload_token` | Whether upload token validation is required. Recommended `true` for production. |
| `cors.*` | CORS configuration. For production, allow only the blog domain. |
| `processing.device_aliases` | Display aliases for device models. |
| `processing.network_aliases` | Display aliases for network types, such as `NR: 5G` and `LTE: 4G`. |
| `geocode.enabled` | Whether reverse geocoding is enabled. When disabled, location fields are not automatically filled from coordinates. |
| `geocode.provider` | Reverse geocoding provider. Default is `amap`. |
| `geocode.api_key` | Amap Web Service API key. Required when Amap reverse geocoding is enabled. |
| `geocode.endpoint` | Reverse geocoding API endpoint. Default is `https://restapi.amap.com/v3/geocode/regeo`. |
| `geocode.timeout_seconds` | Reverse geocoding request timeout. |
| `geocode.cache_ttl_seconds` | In-memory cache TTL for reverse geocoding results. |
| `routes.upload` | Raw status upload path. Default is `/hikari/upload`. |
| `routes.status` | Cleaned status read path. Default is `/hikari/status`. |
| `routes.health` | Health check path. Default is `/hikari/health`. |
| `status.output_timezone` | Timezone for `updated_at`, such as `+08:00` or `UTC`. |
| `status.online_threshold_seconds` | How many seconds after the latest upload should still count as online. |
| `status.private_values` | Field values treated as intentionally hidden, such as `none`. |
| `status.max_raw_value_length` | Maximum saved length for a single raw field. |
| `storage.path` | Latest status JSON storage path. |
| `server.host` | Service listen host. Usually `0.0.0.0` inside Docker. |
| `server.port` | Service listen port. Default is `1210`. |

Common environment overrides:

```text
HIKARI_API_CONFIG
HIKARI_API_UPLOAD_TOKEN
HIKARI_API_CORS_ORIGINS
HIKARI_API_STORAGE_PATH
HIKARI_API_PORT
HIKARI_API_OUTPUT_TIMEZONE
HIKARI_API_GEOCODE_ENABLED
HIKARI_API_GEOCODE_PROVIDER
HIKARI_API_GEOCODE_API_KEY
HIKARI_API_GEOCODE_ENDPOINT
HIKARI_API_GEOCODE_USER_AGENT
AMAP_KEY
```

Amap reverse geocoding API documentation: [https://lbs.amap.com/api/webservice/guide/api/georegeo](https://lbs.amap.com/api/webservice/guide/api/georegeo)

If the log shows `USERKEY_PLAT_NOMATCH`, make sure the key is an Amap **Web Service API** key and check its platform restrictions or server IP allowlist.

## Run Locally

Python 3.14 or later is required. The Python requirement is declared in `pyproject.toml` and read directly by CI and Ruff. The Docker image uses Python 3.14.

Windows:

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
Copy-Item config.example.yaml config.yaml
hikari-api
```

macOS/Linux:

```bash
python3.14 -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
cp config.example.yaml config.yaml
hikari-api
```

The default address is `http://localhost:1210`. Recreate existing virtual environments with Python 3.14 when upgrading.

## Docker

```bash
cp config.example.yaml config.yaml
docker compose up -d --build
docker compose ps
docker compose logs -f
```

The default file is `compose.yaml`, requiring Docker Compose v2 or later. The built image is `hikari-api:latest`. It mounts `config.yaml` and `data/` from the current directory, and service configuration is read primarily from that file. A missing configuration file causes an error instead of creating a directory with the same name.

The default port mapping is `1210:1210`. The health check reads the configured listen port and health route. Logs rotate across at most three 10 MB files. The container enables process reaping and prevents privilege escalation.

When upgrading an existing deployment, back up its configuration and data first. Keep secrets and other settings in `config.yaml` and change only `server.port` to `1210`; do not overwrite it with the example file. Keep a single Hikari Compose file in the project directory, remove the old `docker-compose.yml`, then run `docker compose up -d --build`. Update the origin port in your reverse proxy or Cloudflare Tunnel and any client URLs that access the old port directly.

For access only through a host-side proxy, use `127.0.0.1:1210:1210` as the port mapping. To customize the listen port, update both `server.port` in `config.yaml` and the container port mapping in Compose.

## Lint

```bash
ruff check .
```

## Related Projects

```text
Miafetta/hikari-android
        |
        | Uploads status
        v
Miafetta/hikari-api  <- Current project
        |
        | Outputs cleaned status JSON
        v
Miafetta/miafetta.github.io
```

- [Miafetta/hikari-android](https://github.com/Miafetta/hikari-android): Android status collection and upload client.
- [Miafetta/hikari-api](https://github.com/Miafetta/hikari-api): Status data processing API, the current project.
- [Miafetta/miafetta.github.io](https://github.com/Miafetta/miafetta.github.io): Blog display frontend.

## License

Hikari API is licensed under the GNU General Public License v3.0. See [LICENSE](../LICENSE) for details.
