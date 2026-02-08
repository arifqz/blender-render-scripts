#!/bin/bash
# Check render settings for any .blend file
# Usage: ./check_settings.sh <filename.blend>

SCENE_FILE="${1}"

if [ -z "$SCENE_FILE" ]; then
    echo "Usage: $0 <filename.blend>"
    echo "Example: $0 CRAB.blend"
    exit 1
fi

if [ ! -f "/workspace/$SCENE_FILE" ]; then
    echo "Error: /workspace/$SCENE_FILE not found"
    exit 1
fi

echo "=== Checking Settings for: $SCENE_FILE ==="
echo ""

blender -b "/workspace/$SCENE_FILE" --python-expr "
import bpy

scene = bpy.context.scene
render = scene.render

print('=== FRAME SETTINGS ===')
print(f'Start Frame: {scene.frame_start}')
print(f'End Frame: {scene.frame_end}')
print(f'Current Frame: {scene.frame_current}')
print()

print('=== RENDER ENGINE ===')
print(f'Engine: {render.engine}')
if render.engine == 'CYCLES':
    cycles = scene.cycles
    print(f'Device: {scene.cycles.device}')
    print(f'Samples: {cycles.samples}')
    print()
    
    # Check GPU devices
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.refresh_devices()
        print('=== GPU DEVICES ===')
        gpu_found = False
        gpu_enabled = False
        for device in prefs.devices:
            if device.type in ('CUDA', 'OPTIX'):
                status = 'ENABLED' if device.use else 'DISABLED'
                print(f'  {device.type}: {device.name} - {status}')
                if device.use:
                    gpu_found = True
                    gpu_enabled = True
            elif device.type == 'CPU':
                status = 'ENABLED' if device.use else 'DISABLED'
                print(f'  CPU: {device.name} - {status}')
        
        print()
        if scene.cycles.device == 'GPU' and gpu_enabled:
            print('GPU RENDERING CONFIGURED CORRECTLY')
        elif scene.cycles.device == 'GPU' and not gpu_enabled:
            print('WARNING: GPU selected but no GPU devices enabled')
        else:
            print('WARNING: CPU rendering (GPU not selected)')
    except Exception as e:
        print(f'WARNING: Could not check GPU devices: {e}')
else:
    print('WARNING: Not using Cycles engine')

print()
print('=== RESOLUTION ===')
print(f'Width: {render.resolution_x}px')
print(f'Height: {render.resolution_y}px')
print(f'Percentage: {render.resolution_percentage}%')
final_w = int(render.resolution_x * render.resolution_percentage / 100)
final_h = int(render.resolution_y * render.resolution_percentage / 100)
print(f'Final Size: {final_w}x{final_h}px')
print()

print('=== OUTPUT SETTINGS ===')
print(f'File Format: {render.image_settings.file_format}')
print(f'Color Mode: {render.image_settings.color_mode}')
print(f'Color Depth: {render.image_settings.color_depth}')
print(f'Output Path: {render.filepath}')
print()

print('=== SUMMARY ===')
print(f'Frame range: {scene.frame_start}-{scene.frame_end}')
if render.engine == 'CYCLES' and scene.cycles.device == 'GPU':
    print('Cycles GPU rendering: YES')
else:
    print('Cycles GPU rendering: NO')
" 2>&1 | grep -v "^Blender\|^build\|^Warning\|^Info\|^$" | tail -40
