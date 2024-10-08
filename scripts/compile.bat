@echo off
where /q glslc
if %ERRORLEVEL% neq 0 (
    echo glslc not found in PATH. Trying to locate in Vulkan SDK...
    for /f "delims=" %%i in ('dir /b /s /a-d "C:\VulkanSDK\*\Bin\glslc.exe"') do set GLSLC=%%i
    if not defined GLSLC (
        echo Unable to locate glslc. Please ensure Vulkan SDK is installed and glslc is in your PATH.
        exit /b 1
    )
) else (
    set GLSLC=glslc
)

%GLSLC% assets/shaders/shader.vert -o assets/shaders/vert.spv
%GLSLC% assets/shaders/shader.frag -o assets/shaders/frag.spv