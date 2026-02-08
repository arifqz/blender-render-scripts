#!/bin/bash
# Configure any .blend file for GPU rendering
# Usage: ./setup_gpu.sh <filename.blend> [start_frame] [end_frame]
# Example: ./setup_gpu.sh CRAB.blend 1 50

SCENE_FILE="${1}"
START_FRAME="${2:-1}"
END_FRAME="${3:-250}"

if [ -z "$SCENE_FILE" ]; then
    echo "Usage: $0 <filename.blend> [start_frame] [end_frame]"
    echo "Example: $0 CRAB.blend 1 50"
    exit 1
fi

if [ ! -f "/workspace/$SCENE_FILE" ]; then
    echo "Error: /workspace/$SCENE_FILE not found"
    exit 1
fi

echo "=== Setting up $SCENE_FILE for GPU Rendering ==="
echo "Frame range: $START_FRAME - $END_FRAME"
echo ""

blender -b "/workspace/$SCENE_FILE" --python-expr "
import bpy

scene = bpy.context.scene
render = scene.render

# Set frame range
scene.frame_start = $START_FRAME
scene.frame_end = $END_FRAME
print(f'Frame range set to: {scene.frame_start}-{scene.frame_end}')

# Ensure Cycles engine
if render.engine != 'CYCLES':
    render.engine = 'CYCLES'
    print('Render engine set to CYCLES')
else:
    print('Render engine: CYCLES (already set)')

# Configure GPU rendering
if render.engine == 'CYCLES':
    scene.cycles.device = 'GPU'
    print('Device set to GPU')
    
    # Enable GPU devices
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.refresh_devices()
        
        gpu_enabled = False
        for device in prefs.devices:
            if device.type in ('CUDA', 'OPTIX'):
                device.use = True
                print(f'Enabled GPU device: {device.type} - {device.name}')
                gpu_enabled = True
            elif device.type == 'CPU':
                device.use = False
                print(f'Disabled CPU device')
        
        if not gpu_enabled:
            print('WARNING: No GPU devices found - will use CPU')
    except Exception as e:
        print(f'WARNING: Could not configure GPU devices: {e}')

# Ensure PNG output with RGBA
render.image_settings.file_format = 'PNG'
render.image_settings.color_mode = 'RGBA'
render.image_settings.color_depth = '16'
print('Output format set to PNG (16-bit RGBA)')

# Save the file
bpy.ops.wm.save_mainfile(filepath='/workspace/$SCENE_FILE')
print('Settings saved to $SCENE_FILE')
print()
print('=== Configuration Complete ===')
" 2>&1 | grep -v "^Blender\|^build\|^Warning\|^Info\|^$"

echo ""
echo "Verifying settings..."
/workspace/check_settings.sh "$SCENE_FILE"
