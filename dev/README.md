# Development Guide

## Local Development Mode

Build images locally to test your changes.

### Step 1: Enable Local Build
```bash
cp dev/examples/docker-compose.override.yml services/docker-compose.override.yml
```

### Step 2: Build and Run
```bash
bash scripts/setup/setup.sh
bash scripts/services/start-silver.sh
```

### Step 3: Switch Back to Production
```bash
rm services/docker-compose.override.yml
bash scripts/services/start-silver.sh
```

## Files

- `examples/docker-compose.override.yml` - Template for local builds
