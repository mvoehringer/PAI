#!/bin/bash

# PAIVoice Server Start Script

# Load environment variables from ~/.env
if [ -f ~/.env ]; then
    export $(grep -v '^#' ~/.env | xargs)
fi

# Set default port if not in .env
export PORT="${PORT:-8888}"

# Kill any existing voice server processes
pkill -f "voice-server/server.ts" 2>/dev/null

# Start the server
echo "🚀 Starting PAIVoice Server on port $PORT"
cd "${PAI_HOME:-~}/.claude/voice-server"
bun run server.ts &

echo "✅ Voice server started with PID $!"
echo "📡 Listening on http://localhost:$PORT"

# Check if ElevenLabs API key is configured
if [ -z "$ELEVENLABS_API_KEY" ]; then
    echo "⚠️  No ElevenLabs API key found - using macOS 'say' command"
    echo "   To enable ElevenLabs voices, add ELEVENLABS_API_KEY to ~/.env"
fi