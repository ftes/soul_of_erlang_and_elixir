#!/bin/bash
# Build via docker (cross platform, supports Apple hardware)
# Deploy via SSH

# Exit on any error
set -e

# Configuration
LOCAL_DIR="build-output"
REMOTE_HOST="root@dcon-elixir.ftes.de"
REMOTE_DIR="/app"
ZIP_FILE="my_system.tar.gz"
PLATFORM=linux/amd64

docker build --platform $PLATFORM -t my-system .
docker create --platform $PLATFORM --name temp-container my-system
docker cp temp-container:/app/_build/prod/rel/my_system $LOCAL_DIR
docker rm temp-container

echo "Creating archive..."
tar --no-xattrs -czf "$ZIP_FILE" -C $LOCAL_DIR my_system

echo "Uploading archive..."
scp "$ZIP_FILE" "$REMOTE_HOST:/tmp/"

echo "Deploying on remote server..."
ssh "$REMOTE_HOST" << 'EOF'
# Stop the service if it's running
if [ -f /app/bin/my_system ]; then
    echo "Stopping existing service..."
    /app/bin/my_system stop || true
fi

# Remove existing directory contents
rm -rf /app/*
mkdir -p /app

# Extract the archive
cd /app
tar -xzf /tmp/my_system.tar.gz --strip-components=1

# Cleanup temporary file
rm /tmp/my_system.tar.gz

# Start server
/app/bin/my_system daemon
EOF

echo "Cleaning up local archive..."
rm "$ZIP_FILE"

echo "Deployment complete!"
