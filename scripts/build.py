import os
import subprocess
import sys
from colorama import init, Fore, Style

init(autoreset=True)


def print_script(message):
    print(f"{Fore.CYAN}{Style.BRIGHT}[SCRIPT] {message}{Style.RESET_ALL}")


def print_error(message):
    print(f"{Fore.RED}{Style.BRIGHT}[ERROR] {message}{Style.RESET_ALL}")


def compile_shaders():
    print_script("Compiling shaders...")
    if sys.platform.startswith("win"):
        compile_script = "scripts\\compile.bat"
    else:
        compile_script = "./scripts/compile.sh"

        try:
            subprocess.run(["chmod", "+x", compile_script], check=True)
        except subprocess.CalledProcessError as e:
            print_error(
                f"Failed to set executable permissions for {compile_script} with exit code {e.returncode}"
            )
            sys.exit(1)

    result = subprocess.run(compile_script, shell=True, check=True)
    if result.returncode != 0:
        print_error(f"Shader compilation failed with exit code {result.returncode}")
        sys.exit(1)
    print_script("Shader compilation completed successfully")


def init_submodules():
    print_script("Initializing submodules...")

    result = subprocess.run(
        ["git", "submodule", "update", "--init", "--recursive"], check=True
    )
    if result.returncode != 0:
        print_error(
            f"Submodule initialization failed with exit code {result.returncode}"
        )
        sys.exit(1)

    print_script("Submodule initialization completed successfully")


def build_imgui(force=False):
    imgui_lib_path = os.path.join("external", "odin-imgui", "imgui_windows_x64.lib")
    if not force and os.path.exists(imgui_lib_path):
        print_script("ImGui already built, skipping...")
        return

    print_script("Building ImGui...")

    os.chdir("external/odin-imgui")

    try:
        with open(os.devnull, "w") as devnull:
            subprocess.run(
                ["python3", "build.py"],
                check=True,
                stdout=devnull,
                stderr=subprocess.STDOUT,
            )

        print_script("ImGui build completed successfully")
    except subprocess.CalledProcessError as e:
        print_error(f"ImGui build failed with exit code {e.returncode}")
        sys.exit(1)
    finally:
        os.chdir("../..")


def build_vma():
    if os.path.exists("external/odin-vma/external/libVulkanMemoryAllocator.a"):
        print_script("Odin-VMA backend already built, skipping...")
        return True
    else:
        print_script("Building Odin-VMA backend...")

    current_dir = os.getcwd()
    vma_path = os.path.join("external", "odin-vma", "VulkanMemoryAllocator")
    build_path = os.path.join(vma_path, "build")

    if not os.path.exists(vma_path):
        print_error(
            "VulkanMemoryAllocator directory not found. Ensure the submodule is initialized."
        )
        return False

    try:
        os.makedirs(build_path, exist_ok=True)

        os.chdir(vma_path)

        cmake_cmd = [
            "cmake",
            "-S",
            ".",
            "-B",
            "build",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DVMA_STATIC_VULKAN_FUNCTIONS=OFF",
            "-DVMA_DYNAMIC_VULKAN_FUNCTIONS=OFF",
        ]
        subprocess.run(cmake_cmd, check=True, stdout=subprocess.DEVNULL)

        os.chdir("build")

        subprocess.run(
            ["make"],
            check=True,
            stdout=subprocess.DEVNULL,
        )

        os.chdir(current_dir)

        src_lib = os.path.join(vma_path, "build", "src", "libVulkanMemoryAllocator.a")
        dest_lib = os.path.join(
            current_dir, "external/odin-vma/external/libVulkanMemoryAllocator.a"
        )
        subprocess.run(["cp", src_lib, dest_lib], check=True)

        print_script("Odin-VMA built successfully")

        return True
    except subprocess.CalledProcessError as e:
        print_error(f"Failed to build Odin-VMA: {e}")

        return False


def build_odin_project(debug=True, release=False, profile=False):
    print_script(f"Building Odin project in {'debug' if debug else 'release'} mode...")

    if profile:
        print_script(
            f"Profiling Odin project in {'debug' if debug else 'release'} mode..."
        )

    os.makedirs("bin", exist_ok=True)

    if sys.platform.startswith("win"):
        output_file = "bin\\vertex_debug.exe" if debug else "bin\\vertex_release.exe"
    else:
        output_file = "bin/vertex_debug" if debug else "bin/vertex_release"

    build_cmd = ["odin", "build", "src", f"-out:{output_file}"]

    if debug:
        build_cmd.extend(
            [
                "-debug",
                "-vet-unused-variables",
                "-vet-shadowing",
                "-vet-using-stmt",
                "-vet-using-param",
                "-vet-style",
                "-vet-semicolon",
                "-vet-cast",
                "-vet-tabs",
                "-warnings-as-errors",
            ]
        )

        if profile:
            build_cmd.extend(
                [
                    "-define:PROFILE=true",
                ]
            )

    elif release:
        build_cmd.extend(["-o:speed", "-no-bounds-check", "-disable-assert"])

        if profile:
            build_cmd.extend(
                [
                    "-define:PROFILE=true",
                ]
            )

    print(f"{Fore.GREEN}{Style.BRIGHT}--- Odin Timings ---{Style.RESET_ALL}")

    build_cmd.extend(["-show-timings"])
    result = subprocess.run(build_cmd, check=True)
    if result.returncode != 0:
        print_error(f"Odin build failed with exit code {result.returncode}")
        sys.exit(1)

    print(f"{Fore.GREEN}{Style.BRIGHT}--- Odin Timings End ---{Style.RESET_ALL}")
    print_script(f"Odin build completed successfully. Binary saved as {output_file}")
    return output_file


def run_binary(binary_path):
    print_script(f"Running {binary_path}...")
    print(f"{Fore.GREEN}{Style.BRIGHT}--- Program Output Begin ---{Style.RESET_ALL}")

    try:
        subprocess.run(binary_path, check=True)
    except subprocess.CalledProcessError as e:
        print_error(f"Binary execution failed with exit code {e.returncode}")
    except Exception as e:
        print_error(f"An error occurred while running the binary: {e}")

    print(f"{Fore.GREEN}{Style.BRIGHT}--- Program Output End ---{Style.RESET_ALL}")


def main():
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    print_script("Build process started")

    profile_mode = False
    release_mode = False

    if "--debug" in sys.argv:
        debug_mode = True

        if "--profile" in sys.argv:
            profile_mode = True

    elif "--release" in sys.argv:
        debug_mode = False
        release_mode = True

        if "--profile" in sys.argv:
            profile_mode = True

    else:
        print_error("Please specify either --debug or --release")
        sys.exit(1)

    init_submodules()
    if "--rebuild-imgui" in sys.argv:
        build_imgui(force=True)
    else:
        build_imgui()

    if sys.platform == "linux":
        if not build_vma():
            sys.exit(1)

    compile_shaders()

    binary_path = build_odin_project(
        debug=debug_mode, release=release_mode, profile=profile_mode
    )
    run_binary(binary_path)

    print_script("Build process and execution completed")


if __name__ == "__main__":
    main()
