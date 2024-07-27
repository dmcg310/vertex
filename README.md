# vertex

Vertex is a Vulkan-based renderer.

## Features

- Vulkan initialization and setup
- Shader compilation (vertex and fragment shaders)

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
└── bin\            # Output directory for compiled binary
```

## Building and Running

1. Clone the repository:

```sh
git clone https://github.com/dmcg310/vertex.git
```

2. Install the required Python package:

```sh
pip install colorama
```

3. Run the build script:

```sh
python3 scripts/build.py
```

This script will compile the shaders, build the Odin project, and run the resulting binary.

## References

- The Odin programming language.
- Vulkan.
- GLFW.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.