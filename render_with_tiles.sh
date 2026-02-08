#!/bin/bash
# Render with GPU support and progress tracking
# Usage: ./render_with_tiles.sh <file.blend> [output_path]
# Example: ./render_with_tiles.sh CRAB.blend /workspace/output

SCENE_FILE="${1:-scene.blend}"
OUTPUT_PATH="${2:-/workspace/output}"

echo "Rendering: $SCENE_FILE"
echo "   Output: $OUTPUT_PATH"
echo ""

if [ ! -f "/workspace/$SCENE_FILE" ]; then
    echo "Error: Scene file not found: /workspace/$SCENE_FILE"
    exit 1
fi

# Ensure output path is absolute and exists
if [[ ! "$OUTPUT_PATH" = /* ]]; then
    OUTPUT_PATH="/workspace/$OUTPUT_PATH"
fi
mkdir -p "$OUTPUT_PATH"

if [ ! -w "$OUTPUT_PATH" ]; then
    echo "Error: Output directory is not writable: $OUTPUT_PATH"
    exit 1
fi

echo "Output directory verified: $OUTPUT_PATH"
echo ""

# Show settings
echo "Render Settings:"
/workspace/show_render_settings.sh "$SCENE_FILE"
echo ""

echo "Starting render..."
echo "   GPU RENDERING ENABLED (CUDA)"
echo "   OUTPUT FORMAT: PNG (16-bit RGBA)"
echo "   OUTPUT PATH: $OUTPUT_PATH"
echo "   ==================================="
echo ""

START_TIME=$(date +%s)
LOG_FILE="/tmp/blender_render_$(date +%s).log"

# Get base filename without extension for output
SCENE_BASENAME=$(basename "$SCENE_FILE" .blend)
OUTPUT_FILE="$OUTPUT_PATH/${SCENE_BASENAME}"

# Render with CUDA GPU and RGBA PNG output
blender -b "/workspace/$SCENE_FILE" -o "$OUTPUT_FILE" \
  --python-expr "
import bpy
import os

# Configure GPU rendering - CUDA (most compatible)
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'CUDA'
prefs.refresh_devices()

# Enable GPU devices, disable CPU
gpu_found = False
for device in prefs.devices:
    if device.type == 'CUDA':
        device.use = True
        gpu_found = True
        print(f'Enabled GPU: {device.name}')
    elif device.type == 'CPU':
        device.use = False

if not gpu_found:
    print('WARNING: No CUDA GPU found, falling back to CPU')

# Set scene to use GPU
scene = bpy.context.scene
if scene.render.engine == 'CYCLES':
    scene.cycles.device = 'GPU'

# Set PNG output with RGBA
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '16'

# Set output path
output_path = '$OUTPUT_FILE'
scene.render.filepath = output_path

# Ensure output directory exists
output_dir = os.path.dirname(output_path)
os.makedirs(output_dir, exist_ok=True)

print(f'Output: {output_path}')
print(f'Device: {scene.cycles.device}')
print(f'Compute: {prefs.compute_device_type}')
print(f'Format: PNG 16-bit RGBA')
" -a 2>&1 | tee "$LOG_FILE" | while IFS= read -r line; do
    timestamp=$(date +%H:%M:%S)

    # Show frame progress
    if echo "$line" | grep -qE "Fra:[0-9]+.*Sample [0-9]+"; then
        frame=$(echo "$line" | grep -oE "Fra:[0-9]+" | head -1)
        sample=$(echo "$line" | grep -oE "Sample [0-9]+/[0-9]+" | head -1)
        remaining=$(echo "$line" | grep -oE "Remaining:[0-9:.]*" | head -1)
        if [ -n "$sample" ]; then
            echo "[$timestamp] $frame | $sample | $remaining"
        fi
    fi

    # Show saved frames
    if echo "$line" | grep -qE "Saved:"; then
        echo "[$timestamp] $line"
    fi

    # Show errors
    if echo "$line" | grep -qiE "error|failed|exception"; then
        echo "[$timestamp] ERROR: $line"
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=================================="
echo "Render complete!"
echo "   Total duration: $((DURATION / 3600))h $(((DURATION % 3600) / 60))m $((DURATION % 60))s"
echo ""
echo "Output directory: $OUTPUT_PATH"
PNG_COUNT=$(find "$OUTPUT_PATH" -name "*.png" -type f 2>/dev/null | wc -l)
if [ "$PNG_COUNT" -gt 0 ]; then
    echo "Found $PNG_COUNT PNG file(s):"
    find "$OUTPUT_PATH" -name "*.png" -type f -exec ls -lh {} \; | tail -10
else
    echo "No PNG files found in output directory"
    ls -lah "$OUTPUT_PATH" | tail -10
fi
