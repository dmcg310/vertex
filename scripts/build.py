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

    result = subprocess.run(compile_script, shell=True, check=True)
    if result.returncode != 0:
        print_error(f"Shader compilation failed with exit code {result.returncode}")
        sys.exit(1)
    print_script("Shader compilation completed successfully")


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

    compile_shaders()
    binary_path = build_odin_project()
    run_binary(binary_path)

    print_script("Build process and execution completed")


if __name__ == "__main__":
    main()