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
            print_error(f"Failed to set executable permissions for {
                        compile_script} with exit code {e.returncode}")
            sys.exit(1)

    result = subprocess.run(compile_script, shell=True, check=True)
    if result.returncode != 0:
        print_error(f"Shader compilation failed with exit code {
                    result.returncode}")
        sys.exit(1)
    print_script("Shader compilation completed successfully")


def init_submodules():
    print_script("Initializing submodules...")

    result = subprocess.run(
        ["git", "submodule", "update", "--init", "--recursive"], check=True)
    if result.returncode != 0:
        print_error(f"Submodule initialization failed with exit code {
                    result.returncode}")
        sys.exit(1)

    print_script("Submodule initialization completed successfully")


def build_imgui(force=False):
    imgui_lib_path = os.path.join(
        "external", "odin-imgui", "imgui_windows_x64.lib")
    if not force and os.path.exists(imgui_lib_path):
        print_script("ImGui already built, skipping...")
        return

    print_script("Building ImGui...")

    os.chdir("external/odin-imgui")

    try:
        with open(os.devnull, 'w') as devnull:
            subprocess.run(["python", "build.py"], check=True,
                           stdout=devnull, stderr=subprocess.STDOUT)

        print_script("ImGui build completed successfully")
    except subprocess.CalledProcessError as e:
        print_error(f"ImGui build failed with exit code {e.returncode}")
        sys.exit(1)
    finally:
        os.chdir("../..")


def build_odin_project():
    print_script("Building Odin project...")

    os.makedirs("bin", exist_ok=True)

    if sys.platform.startswith("win"):
        output_file = "bin\\renderer.exe"
    else:
        output_file = "bin/renderer"

    build_cmd = f"odin build renderer -out:{output_file}"

    result = subprocess.run(build_cmd, shell=True, check=True)
    if result.returncode != 0:
        print_error(f"Odin build failed with exit code {result.returncode}")
        sys.exit(1)

    print_script(
        f"Odin build completed successfully. Binary saved as {output_file}")

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

    init_submodules()

    if "--rebuild-imgui" in sys.argv:
        build_imgui(force=True)
    else:
        build_imgui()

    compile_shaders()
    binary_path = build_odin_project()
    run_binary(binary_path)

    print_script("Build process and execution completed")


if __name__ == "__main__":
    main()
