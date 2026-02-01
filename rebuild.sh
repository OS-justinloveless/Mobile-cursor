#!/bin/bash

# Rebuild script: Restarts server and builds/installs iOS app to physical device

# Default port (can be overridden by .env)
PORT=3847

# Check if .env exists and source the port
if [ -f "server/.env" ]; then
  source server/.env
fi

# Parse arguments
BUILD_SERVER=true
BUILD_IOS=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --server-only)
      BUILD_IOS=false
      shift
      ;;
    --ios-only)
      BUILD_SERVER=false
      shift
      ;;
    -h|--help)
      echo "Usage: ./rebuild.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --server-only    Only rebuild and restart the server"
      echo "  --ios-only       Only rebuild the iOS app"
      echo "  -h, --help       Show this help message"
      echo ""
      echo "By default, both server and iOS app are rebuilt."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information."
      exit 1
      ;;
  esac
done

# Function to kill process on port
kill_port_process() {
  local port=$1
  echo "🔍 Checking for processes on port $port..."
  
  # Get the PID of process using the port
  local pid=$(lsof -ti :$port 2>/dev/null)
  
  if [ -n "$pid" ]; then
    echo "⚠️  Found process $pid using port $port"
    echo "🛑 Killing process $pid..."
    kill -9 $pid 2>/dev/null
    sleep 1
    echo "✅ Process killed"
  else
    echo "✅ Port $port is free"
  fi
}

# Server rebuild
if [ "$BUILD_SERVER" = true ]; then
  echo ""
  echo "═══════════════════════════════════════"
  echo "           SERVER REBUILD"
  echo "═══════════════════════════════════════"
  
  # Get absolute path to server directory
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  SERVER_DIR="$SCRIPT_DIR/server"
  
  # Create a temporary restart script that will run independently
  RESTART_SCRIPT=$(mktemp)
  cat > "$RESTART_SCRIPT" << 'RESTART_EOF'
#!/bin/bash
PORT=$1
SERVER_DIR=$2

# Wait a moment for the old process to fully terminate
sleep 2

# Double-check the port is free
pid=$(lsof -ti :$PORT 2>/dev/null)
if [ -n "$pid" ]; then
  kill -9 $pid 2>/dev/null
  sleep 1
fi

# Start the server
cd "$SERVER_DIR" && npm start
RESTART_EOF
  chmod +x "$RESTART_SCRIPT"
  
  # Launch the restart script in a completely detached process
  # nohup + disown + redirect all output ensures it survives PTY termination
  echo "🔄 Spawning detached restart process..."
  nohup bash "$RESTART_SCRIPT" "$PORT" "$SERVER_DIR" > "$SERVER_DIR/restart.log" 2>&1 &
  disown
  
  # Now it's safe to kill the current server - the restart process will handle bringing it back
  echo "🔍 Checking for processes on port $PORT..."
  kill_port_process $PORT
  
  # Also try pkill as backup for any orphaned node processes
  pkill -f "node.*server" 2>/dev/null
  
  echo "✅ Server restart initiated (runs independently of this terminal)"
  echo "   Check $SERVER_DIR/restart.log for server output"
fi

# iOS rebuild
if [ "$BUILD_IOS" = true ]; then
  echo ""
  echo "═══════════════════════════════════════"
  echo "           iOS APP REBUILD"
  echo "═══════════════════════════════════════"
  
  echo "📱 Building and installing iOS app to Justin's iPhone..."
  xcodebuild -project ios-client/CursorMobile/CursorMobile.xcodeproj \
    -scheme CursorMobile \
    -destination "platform=iOS,name=Justin's iPhone" \
    build
fi

echo ""
echo "═══════════════════════════════════════"
echo "              ✅ DONE!"
echo "═══════════════════════════════════════"
