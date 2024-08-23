# vertex

Vertex is a Vulkan-based renderer.

## Features

- Vulkan initialization and setup
- GPU memory management using `VulkanMemoryAllocator` (VMA)
- Shader compilation (vertex and fragment shaders)
- Imgui integration
- File and console based logging
- Profiling with Spall

## Prerequisites

To build and run this project, you need:

- [Odin Compiler](https://odin-lang.org/)
- [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/)
- Python 3.x (for build script)

Ensure that both Odin and Vulkan SDK are properly installed and their paths are set in your system's environment variables.

## Project Structure

```sh
├── src\    # Odin source files
├── scripts\    # Build and compile scripts
│   ├── build.py
│   ├── compile.bat
│   └── compile.sh
├── assets\
│   ├── shaders\    # GLSL shader files
│   └── textures\    # Texture files
├── bin\    # Output directory for compiled binary
└── external\    # External dependencies
    ├── odin-imgui\    # ImGui bindings for Odin (submodule)
    └── odin-vma\    # VulkanMemoryAllocator bindings for Odin (submodule)
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

5. Optionally, run the build script with the profile flag to enable profiling:

```sh
python3 scripts/build.py --debug --profile
```

Or

```sh
python3 scripts/build.py --release --profile
```

Note: this will output `trace_vertex.spall` into `bin/`. This can be viewed by opening [spall-web](https://gravitymoth.com/spall/spall-web.html), then opening the file in the icon at the top left.

This script will initialize submodules, compile the shaders, build the Odin project in the specified mode (debug or release), and run the resulting binary.

## References

- [The Odin programming language](https://odin-lang.org/)
- [Vulkan](https://www.vulkan.org/)
- [GLFW](https://www.glfw.org/)
- [ImGui](https://github.com/ocornut/imgui)
- [Odin-ImGui](https://gitlab.com/L-4/odin-imgui)
- [Spall](https://gravitymoth.com/spall/)
- [VulkanMemoryAllocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/tree/master)
- [Odin-VMA](https://github.com/DanielGavin/odin-vma)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
