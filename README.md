# Blender Render Scripts

Scripts for GPU rendering Blender files on RunPod.

## Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `render_scene.sh` | Start a render | `./render_scene.sh <file.blend> [output_path]` |
| `render_with_tiles.sh` | Full render with tile tracking + memory protection | `./render_with_tiles.sh <file.blend> [output_path]` |
| `check_settings.sh` | Check render settings of a .blend file | `./check_settings.sh <file.blend>` |
| `setup_gpu.sh` | Configure GPU rendering + frame range | `./setup_gpu.sh <file.blend> [start_frame] [end_frame]` |
| `show_render_settings.sh` | Show detailed render settings | `./show_render_settings.sh <file.blend>` |

## Quick Start

```bash
# 1. Upload your .blend file to /workspace/

# 2. Check current settings
./check_settings.sh MYFILE.blend

# 3. Set up GPU rendering (optional - configure frames and GPU)
./setup_gpu.sh MYFILE.blend 1 50

# 4. Start rendering
./render_scene.sh MYFILE.blend /workspace/output
```

## Features

- GPU rendering (OPTIX/CUDA auto-detection)
- Memory protection (kills render if >90% RAM to prevent crashes)
- Tile progress tracking with time estimates
- PNG output (16-bit RGBA)
