# vertex

Vertex is a Vulkan-based renderer.

## Features

- Vulkan initialization and setup
- Shader compilation (vertex and fragment shaders)
- Imgui integration

## Prerequisites

To build and run this project, you need:

- [Odin Compiler](https://odin-lang.org/)
- [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/)
- Python 3.x (for build script)

Ensure that both Odin and Vulkan SDK are properly installed and their paths are set in your system's environment variables.

## Project Structure

```sh
├── renderer\       # Odin source files
├── scripts\        # Build and compile scripts
│   ├── build.py
│   ├── compile.bat
│   └── compile.sh
├── shaders\        # GLSL shader files
├── bin\            # Output directory for compiled binary
└── external\       # External dependencies
    └── odin-imgui\ # ImGui bindings for Odin (submodule)
```

## Building and Running

1. Clone the repository with submodules:

```sh
git clone --recursive https://github.com/dmcg310/vertex.git
```

If you have already cloned without `--recursive`, you can initialize submodules with:

```sh
git submodule update --init --recursive
```

2. Install the required Python package:

```sh
pip install colorama ply
```

3. Build ImGui (required at least once):

```sh
python3 scripts/build.py --rebuild-imgui --debug
```

Or

```sh
python3 scripts/build.py --rebuild-imgui --release
```

4. For subsequent builds, run the build script without the ImGui flag:

```sh
python3 scripts/build.py --debug
```

Or

```sh
python3 scripts/build.py --release
```

This script will initialize submodules, compile the shaders, build the Odin project in the specified mode (debug or release), and run the resulting binary.

## References

- The Odin programming language
- Vulkan
- GLFW
- ImGui
- Odin-ImGui

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
