#!/usr/bin/env python3
import subprocess
import sys
import os
import shutil

def main():
    if len(sys.argv) < 2 or len(sys.argv) > 4:
        print("Usage: python analyze_code.py /path/to/code [swift|cpp|all] [basic|advanced]")
        print("  - 'basic' runs SwiftLint/Cppcheck; 'advanced' adds Clang-Tidy/Infer")
        return 1
    
    code_path = sys.argv[1]
    lang = "all" if len(sys.argv) == 2 else sys.argv[2]
    mode = "basic" if len(sys.argv) <= 3 else sys.argv[3]
    
    if lang not in ["swift", "cpp", "all"]:
        print("Invalid language specified. Use 'swift', 'cpp', or 'all'.")
        return 1
    if mode not in ["basic", "advanced"]:
        print("Invalid mode specified. Use 'basic' or 'advanced'.")
        return 1
    if not os.path.exists(code_path):
        print(f"The path '{code_path}' does not exist.")
        return 1

    def run_command(cmd, tool_name):
        if not shutil.which(cmd[0]):
            print(f"{tool_name} not found. Please install it.")
            return False
        try:
            print(f"Running {tool_name} on {code_path}")
            subprocess.run(cmd)
            return True
        except Exception as e:
            print(f"Error running {tool_name}: {e}")
            return False

    # Basic analysis
    if lang in ["swift", "all"]:
        run_command(['swiftlint', 'lint', code_path], "SwiftLint")
    
    if lang in ["cpp", "all"]:
        run_command(['cppcheck', code_path], "Cppcheck")

    # Advanced analysis
    if mode == "advanced":
        if lang in ["cpp", "all"]:
            cpp_files = ' '.join([f for f in os.listdir(code_path) if f.endswith(('.cpp', '.cxx', '.cc'))])
            if cpp_files:
                run_command(['clang-tidy', '--quiet', cpp_files, '--', f'-I{code_path}'], "Clang-Tidy")
            else:
                print("No C++ files found for Clang-Tidy.")
        
        if lang in ["swift", "all", "cpp"]:
            run_command(['infer', 'run', '--', 'make'], "Infer")
            # Adjust 'make' to your build command (e.g., 'swift build' for SwiftPM)

    return 0

if __name__ == "__main__":
    sys.exit(main())