# Deterministic Windows x64 ONNX Runtime runtime and import library.
# Builds may override this via REALTIME_ONNXRUNTIME_ROOT to work offline.
set(REALTIME_EFFECTS_ORT_VERSION "1.23.2")
set(REALTIME_EFFECTS_ORT_SHA256 "0b38df9af21834e41e73d602d90db5cb06dbd1ca618948b8f1d66d607ac9f3cd")
set(REALTIME_EFFECTS_ORT_URL
    "https://github.com/microsoft/onnxruntime/releases/download/v${REALTIME_EFFECTS_ORT_VERSION}/onnxruntime-win-x64-${REALTIME_EFFECTS_ORT_VERSION}.zip")

function(realtime_effects_configure_ort target)
  if(CMAKE_SIZEOF_VOID_P LESS 8)
    message(FATAL_ERROR "Windows virtual backgrounds require x64")
  endif()
  set(ort_root "$ENV{REALTIME_ONNXRUNTIME_ROOT}")
  if(NOT ort_root)
    set(extract_root "${CMAKE_CURRENT_BINARY_DIR}/realtime-effects-ort")
    set(ort_root "${extract_root}/onnxruntime-win-x64-${REALTIME_EFFECTS_ORT_VERSION}")
    if(NOT EXISTS "${ort_root}/include/onnxruntime_cxx_api.h")
      file(MAKE_DIRECTORY "${extract_root}")
      set(archive "${extract_root}/onnxruntime-win-x64-${REALTIME_EFFECTS_ORT_VERSION}.zip")
      message(STATUS "Fetching pinned official ONNX Runtime v${REALTIME_EFFECTS_ORT_VERSION} x64 package")
      file(DOWNLOAD "${REALTIME_EFFECTS_ORT_URL}" "${archive}"
        EXPECTED_HASH "SHA256=${REALTIME_EFFECTS_ORT_SHA256}"
        TLS_VERIFY ON STATUS download_status)
      list(GET download_status 0 download_code)
      if(NOT download_code EQUAL 0)
        message(FATAL_ERROR "ONNX Runtime download or SHA256 verification failed: ${download_status}")
      endif()
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xzf "${archive}"
        WORKING_DIRECTORY "${extract_root}"
        RESULT_VARIABLE extract_code)
      if(NOT extract_code EQUAL 0)
        message(FATAL_ERROR "Could not unpack pinned Windows ONNX Runtime package")
      endif()
    endif()
  endif()
  if(NOT EXISTS "${ort_root}/include/onnxruntime_cxx_api.h" OR
     NOT EXISTS "${ort_root}/lib/onnxruntime.lib" OR
     NOT EXISTS "${ort_root}/lib/onnxruntime.dll")
    message(FATAL_ERROR
      "Windows virtual background requires the official ONNX Runtime x64 headers/import lib/DLL: ${ort_root}")
  endif()
  target_include_directories(${target} PRIVATE "${ort_root}/include")
  target_link_libraries(${target} PRIVATE "${ort_root}/lib/onnxruntime.lib")
  target_compile_definitions(${target} PRIVATE REALTIME_VIDEO_EFFECTS_ONNX=1)
  set(REALTIME_EFFECTS_ORT_BUNDLED_DLL "${ort_root}/lib/onnxruntime.dll" PARENT_SCOPE)
  # Preserve the redistributable license alongside the packaged runtime.
  if(EXISTS "${ort_root}/LICENSE")
    set(REALTIME_EFFECTS_ORT_BUNDLED_LICENSE "${ort_root}/LICENSE" PARENT_SCOPE)
  endif()
endfunction()
