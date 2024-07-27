#!/bin/bash

if ! command -v glslc &> /dev/null; then
    echo "glslc not found in PATH. Trying to locate in Vulkan SDK..."
    GLSLC=$(find /home -name glslc 2>/dev/null | grep VulkanSDK | head -n 1)
    if [ -z "$GLSLC" ]; then
        echo "Unable to locate glslc. Please ensure Vulkan SDK is installed and glslc is in your PATH."
        exit 1
    fi
else
    GLSLC=glslc
fi

"$GLSLC" shaders/shader.vert -o shaders/vert.spv
"$GLSLC" shaders/shader.frag -o shaders/frag.spv