#!/bin/bash
# Render with tile progress and time tracking - GPU ENABLED
SCENE_FILE="${1:-scene.blend}"
OUTPUT_PATH="${2:-/workspace/output}"

echo "🎬 Rendering: $SCENE_FILE"
echo "   Output: $OUTPUT_PATH"
echo ""

if [ ! -f "/workspace/$SCENE_FILE" ]; then
    echo "❌ Error: Scene file not found: /workspace/$SCENE_FILE"
    exit 1
fi

# Ensure output path is absolute and exists
if [[ ! "$OUTPUT_PATH" = /* ]]; then
    OUTPUT_PATH="/workspace/$OUTPUT_PATH"
fi
mkdir -p "$OUTPUT_PATH"

# Verify output directory is writable
if [ ! -w "$OUTPUT_PATH" ]; then
    echo "❌ Error: Output directory is not writable: $OUTPUT_PATH"
    exit 1
fi

echo "✅ Output directory verified: $OUTPUT_PATH"

# Total tiles for 27425x23206 resolution (256x256 tiles)
TOTAL_TILES=9828
echo "📊 Tile Information:"
echo "   Total tiles: $TOTAL_TILES (estimated)"
echo ""

# Show settings
echo "📋 Render Settings:"
/workspace/show_render_settings.sh "$SCENE_FILE"
echo ""

echo "🚀 Starting render..."
echo "   Using settings from Blender file"
echo "   🔥 GPU RENDERING ENABLED"
echo "   📸 OUTPUT FORMAT: PNG"
echo "   📁 OUTPUT PATH: $OUTPUT_PATH"
echo "   🛡️  MEMORY PROTECTION: Will terminate if memory >90%"
echo "   Tile progress: X/$TOTAL_TILES (with render times)"
echo "   ==================================="
echo ""

START_TIME=$(date +%s)
LOG_FILE="/tmp/blender_render_$(date +%s).log"
TILE_TIMES_FILE="/tmp/tile_times_$(date +%s).txt"
MEMORY_MONITOR_PID_FILE="/tmp/memory_monitor_$(date +%s).pid"
MEMORY_EXCEEDED_FILE="/tmp/memory_exceeded_$(date +%s).flag"
> "$TILE_TIMES_FILE"  # Clear file
> "$MEMORY_EXCEEDED_FILE"  # Clear flag file
LAST_TILE=0
TILE_START_TIME=0
MEMORY_EXCEEDED=0

# Cleanup function
cleanup() {
    # Stop memory monitor
    if [ -f "$MEMORY_MONITOR_PID_FILE" ]; then
        MONITOR_PID=$(cat "$MEMORY_MONITOR_PID_FILE")
        kill "$MONITOR_PID" 2>/dev/null
        rm -f "$MEMORY_MONITOR_PID_FILE"
    fi
    # Kill Blender if still running
    pkill blender 2>/dev/null
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Memory monitoring function - kills Blender if memory >90%
monitor_memory() {
    local threshold=90
    local check_interval=5  # Check every 5 seconds
    
    echo "[$(date +%H:%M:%S)] 🛡️  Memory monitor started (threshold: ${threshold}%)"
    
    while true; do
        # Get total and used memory
        local mem_info=$(free | grep Mem)
        local total_mem=$(echo $mem_info | awk '{print $2}')
        local used_mem=$(echo $mem_info | awk '{print $3}')
        local available_mem=$(echo $mem_info | awk '{print $7}')
        
        # Calculate percentage (using available to be safe)
        local mem_percent=$(( (total_mem - available_mem) * 100 / total_mem ))
        
        # Also get memory in GB for display
        local total_gb=$((total_mem / 1024 / 1024))
        local used_gb=$((used_mem / 1024 / 1024))
        
        # Log memory status every 30 seconds
        if [ $(( $(date +%s) % 30 )) -eq 0 ]; then
            echo "[$(date +%H:%M:%S)] 💾 Memory: ${used_gb}GB / ${total_gb}GB (${mem_percent}%)"
        fi
        
        # Check if memory exceeds threshold
        if [ "$mem_percent" -gt "$threshold" ]; then
            echo ""
            echo "⚠️  ⚠️  ⚠️  MEMORY WARNING ⚠️  ⚠️  ⚠️"
            echo "[$(date +%H:%M:%S)] 🚨 Memory usage: ${mem_percent}% (threshold: ${threshold}%)"
            echo "[$(date +%H:%M:%S)] 💾 Memory: ${used_gb}GB / ${total_gb}GB"
            echo "[$(date +%H:%M:%S)] 🛑 Terminating Blender to prevent OOM..."
            
            # Kill all Blender processes
            pkill -9 blender 2>/dev/null
            killall -9 blender 2>/dev/null
            
            # Wait a moment
            sleep 2
            
            # Verify Blender is killed
            if pgrep blender > /dev/null; then
                echo "[$(date +%H:%M:%S)] ⚠️  Some Blender processes still running, force killing..."
                pkill -9 -f blender
            else
                echo "[$(date +%H:%M:%S)] ✅ Blender terminated successfully"
            fi
            
            echo "[$(date +%H:%M:%S)] 💾 Final memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
            echo "⚠️  ⚠️  ⚠️  RENDER STOPPED DUE TO HIGH MEMORY ⚠️  ⚠️  ⚠️"
            echo ""
            
            MEMORY_EXCEEDED=1
            touch "$MEMORY_EXCEEDED_FILE"  # Create flag file
            break
        fi
        
        # Check if Blender is still running
        if ! pgrep blender > /dev/null; then
            echo "[$(date +%H:%M:%S)] ℹ️  Blender process ended, stopping memory monitor"
            break
        fi
        
        sleep $check_interval
    done
}

# Start memory monitor in background
monitor_memory &
MEMORY_MONITOR_PID=$!
echo "$MEMORY_MONITOR_PID" > "$MEMORY_MONITOR_PID_FILE"
echo "[$(date +%H:%M:%S)] 🛡️  Memory monitor PID: $MEMORY_MONITOR_PID"
echo ""

# Get base filename without extension for output
SCENE_BASENAME=$(basename "$SCENE_FILE" .blend)
OUTPUT_FILE="$OUTPUT_PATH/${SCENE_BASENAME}"

# Render using file settings WITH GPU ENABLED AND PNG FORMAT
blender -b "/workspace/$SCENE_FILE" -o "$OUTPUT_FILE" \
  --python-expr "
import bpy
import os

# Configure GPU rendering
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.refresh_devices()

# Try OPTIX first (faster), fallback to CUDA
if any(d.type == 'OPTIX' and d.use for d in prefs.devices):
    prefs.compute_device_type = 'OPTIX'
    print('✅ Using OPTIX for GPU rendering')
elif any(d.type == 'CUDA' and d.use for d in prefs.devices):
    prefs.compute_device_type = 'CUDA'
    print('✅ Using CUDA for GPU rendering')
else:
    print('⚠️  No GPU devices found, using CPU')

# Ensure GPU devices are enabled
for device in prefs.devices:
    if device.type in ('CUDA', 'OPTIX'):
        device.use = True
    elif device.type == 'CPU':
        device.use = False

# Set scene to use GPU
scene = bpy.context.scene
if scene.render.engine == 'CYCLES':
    scene.cycles.device = 'GPU'

# EXPLICITLY SET PNG OUTPUT FORMAT
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.color_depth = '16'  # 16-bit for better quality
print('✅ Output format set to PNG (16-bit RGB)')

# Set output path with .png extension
output_path = '$OUTPUT_FILE'
# Ensure path ends with .png if frame number will be added
if not output_path.endswith('.png'):
    output_path = output_path + '.png'
scene.render.filepath = output_path

# Ensure output directory exists
output_dir = os.path.dirname(output_path)
os.makedirs(output_dir, exist_ok=True)
print(f'✅ Output directory: {output_dir}')
print(f'✅ Output filepath: {output_path}')

print(f'Device: {scene.cycles.device}')
print(f'Compute Device Type: {prefs.compute_device_type}')
print(f'File Format: {scene.render.image_settings.file_format}')
" -a 2>&1 | tee "$LOG_FILE" | while IFS= read -r line; do
    timestamp=$(date +%H:%M:%S)
    current_time=$(date +%s)
    
    # Extract tile number
    tile_match=$(echo "$line" | grep -oE "[Tt]ile\s+[0-9]+" | grep -oE "[0-9]+" | head -1)
    
    if [ -n "$tile_match" ]; then
        tile_num=$tile_match
        if [ "$tile_num" -gt "$LAST_TILE" ]; then
            # Calculate time for previous tile
            if [ "$LAST_TILE" -gt 0 ] && [ "$TILE_START_TIME" -gt 0 ]; then
                tile_duration=$((current_time - TILE_START_TIME))
                echo "$tile_duration" >> "$TILE_TIMES_FILE"
                
                # Calculate stats from file
                tile_count=$(wc -l < "$TILE_TIMES_FILE")
                total_time=$(awk '{sum+=$1} END {print sum}' "$TILE_TIMES_FILE")
                avg_time=$((total_time / tile_count))
                
                # Estimate remaining time
                remaining_tiles=$((TOTAL_TILES - LAST_TILE))
                est_remaining=$((avg_time * remaining_tiles))
                est_hours=$((est_remaining / 3600))
                est_mins=$(((est_remaining % 3600) / 60))
                
                echo "[$timestamp] 🧩 Tile $LAST_TILE/$TOTAL_TILES completed in ${tile_duration}s | Avg: ${avg_time}s/tile | Est remaining: ${est_hours}h ${est_mins}m"
            fi
            
            # Start tracking new tile
            LAST_TILE=$tile_num
            TILE_START_TIME=$current_time
            percent=$((LAST_TILE * 100 / TOTAL_TILES))
            echo "[$timestamp] 🧩 Starting Tile $LAST_TILE/$TOTAL_TILES (${percent}%)"
        fi
    fi
    
    # Show frame info with tile progress
    if echo "$line" | grep -qE "Fra:[0-9]+"; then
        frame=$(echo "$line" | grep -oE "Fra:[0-9]+")
        mem=$(echo "$line" | grep -oE "Mem:[0-9.]+[GM]" || echo "")
        elapsed=$(echo "$line" | grep -oE "Time:[0-9:]+" || echo "")
        
        if [ -f "$TILE_TIMES_FILE" ] && [ -s "$TILE_TIMES_FILE" ]; then
            tile_count=$(wc -l < "$TILE_TIMES_FILE")
            total_time=$(awk '{sum+=$1} END {print sum}' "$TILE_TIMES_FILE")
            avg_time=$((total_time / tile_count))
            remaining=$((TOTAL_TILES - LAST_TILE))
            est_remaining=$((avg_time * remaining))
            est_h=$((est_remaining / 3600))
            est_m=$(((est_remaining % 3600) / 60))
            echo "[$timestamp] 🎬 $frame | $mem | $elapsed | Tiles: $LAST_TILE/$TOTAL_TILES | Est: ${est_h}h ${est_m}m"
        else
            echo "[$timestamp] 🎬 $frame | $mem | $elapsed | Tiles: $LAST_TILE/$TOTAL_TILES"
        fi
    fi
    
    # Show completion
    if echo "$line" | grep -qE "Saved|Finished"; then
        echo "[$timestamp] ✅ $line"
        
        # Final tile time
        if [ "$LAST_TILE" -gt 0 ] && [ "$TILE_START_TIME" -gt 0 ]; then
            final_time=$(date +%s)
            tile_duration=$((final_time - TILE_START_TIME))
            echo "$tile_duration" >> "$TILE_TIMES_FILE"
            echo "[$timestamp] 🧩 Final Tile $LAST_TILE/$TOTAL_TILES completed in ${tile_duration}s"
        fi
    fi
    
    # Check if memory was exceeded (monitor killed Blender)
    if [ -f "$MEMORY_EXCEEDED_FILE" ]; then
        echo "[$timestamp] ⚠️  Memory limit exceeded - render stopped by monitor"
        break
    fi
done

# Stop memory monitor
if [ -f "$MEMORY_MONITOR_PID_FILE" ]; then
    MONITOR_PID=$(cat "$MEMORY_MONITOR_PID_FILE")
    if kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null
        echo "[$(date +%H:%M:%S)] 🛡️  Memory monitor stopped"
    fi
    rm -f "$MEMORY_MONITOR_PID_FILE"
fi

# Check if memory was exceeded
if [ -f "$MEMORY_EXCEEDED_FILE" ]; then
    MEMORY_EXCEEDED=1
    rm -f "$MEMORY_EXCEEDED_FILE"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=================================="

# Check if render was stopped due to memory
if [ "$MEMORY_EXCEEDED" -eq 1 ]; then
    echo "⚠️  Render STOPPED due to high memory usage (>90%)"
    echo "   This prevents OOM crashes and allows you to:"
    echo "   - Adjust render settings"
    echo "   - Use a pod with more RAM"
    echo "   - Retry the render"
else
    echo "✅ Render complete!"
fi

echo "   Total duration: $((DURATION / 3600))h $(((DURATION % 3600) / 60))m $((DURATION % 60))s"
echo "   Total tiles rendered: $LAST_TILE/$TOTAL_TILES"

# Calculate tile statistics
if [ -f "$TILE_TIMES_FILE" ] && [ -s "$TILE_TIMES_FILE" ]; then
    tile_count=$(wc -l < "$TILE_TIMES_FILE")
    total_tile_time=$(awk '{sum+=$1} END {print sum}' "$TILE_TIMES_FILE")
    avg_time=$((total_tile_time / tile_count))
    min_time=$(awk 'BEGIN{min=999999} {if($1<min) min=$1} END{print min}' "$TILE_TIMES_FILE")
    max_time=$(awk 'BEGIN{max=0} {if($1>max) max=$1} END{print max}' "$TILE_TIMES_FILE")
    
    echo "   📊 Tile Statistics:"
    echo "      Tiles tracked: $tile_count"
    echo "      Average time per tile: ${avg_time}s"
    echo "      Fastest tile: ${min_time}s"
    echo "      Slowest tile: ${max_time}s"
    echo "      Total tile render time: $((total_tile_time / 3600))h $(((total_tile_time % 3600) / 60))m"
fi

echo ""
echo "📁 Output directory: $OUTPUT_PATH"
echo "📸 Looking for PNG files..."
PNG_COUNT=$(find "$OUTPUT_PATH" -name "*.png" -type f 2>/dev/null | wc -l)
if [ "$PNG_COUNT" -gt 0 ]; then
    echo "✅ Found $PNG_COUNT PNG file(s):"
    find "$OUTPUT_PATH" -name "*.png" -type f -exec ls -lh {} \; | tail -10
else
    echo "⚠️  No PNG files found in output directory"
    echo "   Listing all files in output directory:"
    ls -lah "$OUTPUT_PATH" | tail -10
fi
