#!/bin/bash
echo "🔧 Setting up Long Distance Camera System..."
pkg update && pkg upgrade -y
pkg install -y php wget curl

echo "📥 Downloading ngrok..."
wget -O ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz
tar xzf ngrok.tgz
chmod +x ngrok
mv ngrok /data/data/com.termux/files/usr/bin/
rm ngrok.tgz

echo "✅ Setup complete!"
echo "🎯 Now run: chmod +x rexcam.sh && ./rexcam.sh"