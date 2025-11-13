#!/bin/bash
echo "🔧 Setting up Serveo Camera System..."
echo "======================================"

pkg update && pkg upgrade -y
pkg install -y php openssh-toolkit

echo "✅ Dependencies installed!"
echo ""
echo "🎯 Now run:"
echo "chmod +x rexcam.sh"
echo "./rexcam.sh"
echo ""
echo "💡 The script will automatically:"
echo "   - Start PHP server"
echo "   - Create Serveo tunnel"
echo "   - Give you a public URL"
echo "   - Monitor captures in real-time"
