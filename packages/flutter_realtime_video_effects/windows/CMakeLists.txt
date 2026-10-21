cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "flutter_realtime_video_effects")
project(${PROJECT_NAME} LANGUAGES CXX)
set(PLUGIN_NAME "${PROJECT_NAME}_plugin")
add_library(${PLUGIN_NAME} SHARED "flutter_realtime_video_effects_plugin.cpp")
apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../flutter_realtime_processed_video/windows/include"
)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
    flutter flutter_wrapper_plugin mfplat mfreadwrite mf mfuuid windowscodecs ole32)

# Optional pinned ONNX Runtime distribution. Without it the plugin compiles,
# but isSupported returns false and cannot create an effects source.
set(ORT_DIR "$ENV{REALTIME_ONNXRUNTIME_ROOT}")
set(flutter_realtime_video_effects_bundled_libraries "" PARENT_SCOPE)
if(ORT_DIR AND EXISTS "${ORT_DIR}/include/onnxruntime_cxx_api.h"
           AND EXISTS "${ORT_DIR}/lib/onnxruntime.lib"
           AND EXISTS "${ORT_DIR}/lib/onnxruntime.dll")
    target_include_directories(${PLUGIN_NAME} PRIVATE "${ORT_DIR}/include")
    target_link_libraries(${PLUGIN_NAME} PRIVATE "${ORT_DIR}/lib/onnxruntime.lib")
    target_compile_definitions(${PLUGIN_NAME} PRIVATE REALTIME_VIDEO_EFFECTS_ONNX=1)
    set(flutter_realtime_video_effects_bundled_libraries
        "${ORT_DIR}/lib/onnxruntime.dll" PARENT_SCOPE)
else()
    message(STATUS "Windows virtual backgrounds unavailable: REALTIME_ONNXRUNTIME_ROOT not configured")
endif()
