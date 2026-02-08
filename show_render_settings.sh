#!/bin/bash
# Show render settings from Blender file
SCENE_FILE="${1:-COVER.blend}"

echo "📋 Render Settings for: $SCENE_FILE"
echo "=================================="
echo ""

blender -b "/workspace/$SCENE_FILE" --python-expr "
import bpy

scene = bpy.context.scene
render = scene.render

print('🎬 FRAME SETTINGS:')
print(f'   Start Frame: {scene.frame_start}')
print(f'   End Frame: {scene.frame_end}')
print(f'   Current Frame: {scene.frame_current}')
print('')

print('📐 RESOLUTION:')
print(f'   Width: {render.resolution_x}px')
print(f'   Height: {render.resolution_y}px')
print(f'   Percentage: {render.resolution_percentage}%')
print(f'   Final Size: {int(render.resolution_x * render.resolution_percentage / 100)}x{int(render.resolution_y * render.resolution_percentage / 100)}px')
print('')

print('🎨 RENDER ENGINE:')
print(f'   Engine: {render.engine}')
if scene.cycles:
    print(f'   Samples: {scene.cycles.samples}')
    print(f'   Device: {scene.cycles.device}')
    print(f'   Tile Size: {scene.render.tile_x}x{scene.render.tile_y}')
    print(f'   Use Tiles: {scene.render.use_tiles}')
print('')

print('📁 OUTPUT SETTINGS:')
print(f'   File Path: {render.filepath}')
print(f'   File Format: {render.image_settings.file_format}')
print(f'   Color Mode: {render.image_settings.color_mode}')
print(f'   Color Depth: {render.image_settings.color_depth}')
print('')

print('🧩 TILING SETTINGS:')
print(f'   Use Tiles: {render.use_tiles}')
if render.use_tiles:
    print(f'   Tile Size: {render.tile_x}x{render.tile_y}')
    total_tiles_x = (render.resolution_x + render.tile_x - 1) // render.tile_x
    total_tiles_y = (render.resolution_y + render.tile_y - 1) // render.tile_y
    total_tiles = total_tiles_x * total_tiles_y
    print(f'   Total Tiles: {total_tiles_x}x{total_tiles_y} = {total_tiles} tiles')
else:
    print('   ⚠️  Tiling is DISABLED - consider enabling for large renders!')
print('')
" 2>/dev/null | grep -v "Blender\|build\|Warning\|Info"
