cmake_minimum_required(VERSION 3.21)
project(VCVRackMcpServer VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# =============================================================================
# Platform & architecture detection
# =============================================================================
if(APPLE)
  set(PLUGIN_EXT .dylib)
elseif(WIN32)
  set(PLUGIN_EXT .dll)
else()
  set(PLUGIN_EXT .so)
endif()

if(WIN32)
  set(RACK_ARCH "win-x64")
elseif(APPLE)
  set(CMAKE_OSX_ARCHITECTURES "${CMAKE_SYSTEM_PROCESSOR}")
  if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    set(RACK_ARCH "mac-arm64")
  else()
    set(RACK_ARCH "mac-x64")
  endif()
else()
  set(RACK_ARCH "lin-x64")
endif()

# =============================================================================
# Dependency 1 — Rack SDK (auto-download if missing)
# =============================================================================
if(NOT DEFINED RACK_DIR)
  set(RACK_SDK_URL "https://vcvrack.com/downloads/Rack-SDK-2.6.6-${RACK_ARCH}.zip")
  set(RACK_SDK_ZIP "${CMAKE_BINARY_DIR}/_deps/Rack-SDK.zip")
  set(RACK_DIR "${CMAKE_BINARY_DIR}/_deps/rack-sdk/Rack-SDK")
  if(NOT EXISTS "${RACK_DIR}")
    message(STATUS "Rack SDK not found. Downloading from ${RACK_SDK_URL}...")
    file(DOWNLOAD "${RACK_SDK_URL}" "${RACK_SDK_ZIP}" SHOW_PROGRESS TLS_VERIFY ON)
    message(STATUS "Extracting Rack SDK...")
    file(ARCHIVE_EXTRACT INPUT "${RACK_SDK_ZIP}" DESTINATION "${CMAKE_BINARY_DIR}/_deps/rack-sdk")
    message(STATUS "Rack SDK downloaded and extracted successfully")
  endif()
endif()

# Resolve to absolute path for reproducible IDE integration
get_filename_component(RACK_DIR "${RACK_DIR}" ABSOLUTE)
if(NOT EXISTS "${RACK_DIR}")
  message(FATAL_ERROR "Rack SDK not found at ${RACK_DIR}. Set -DRACK_DIR= or fix the download.")
endif()
message(STATUS "Using Rack SDK at: ${RACK_DIR}")

# =============================================================================
# Dependency 2 — cpp-httplib (auto-download if missing)
# =============================================================================
set(HTTPLIB_VERSION "0.18.0")
set(HTTPLIB_DIR "${CMAKE_BINARY_DIR}/_deps/cpp-httplib-${HTTPLIB_VERSION}")
if(NOT EXISTS "${HTTPLIB_DIR}")
  message(STATUS "Downloading cpp-httplib v${HTTPLIB_VERSION}...")
  file(DOWNLOAD "https://github.com/yhirose/cpp-httplib/archive/refs/tags/v${HTTPLIB_VERSION}.tar.gz"
       "${CMAKE_BINARY_DIR}/_deps/cpp-httplib.tar.gz" SHOW_PROGRESS TLS_VERIFY ON)
  file(ARCHIVE_EXTRACT INPUT "${CMAKE_BINARY_DIR}/_deps/cpp-httplib.tar.gz"
       DESTINATION "${CMAKE_BINARY_DIR}/_deps")
endif()

# =============================================================================
# Targets
# =============================================================================
add_library(VCVRackMcpServer SHARED
  src/plugin.cpp
  src/RackMcpServer.cpp
)

# Make the plugin importable as a Python module for testing
set_target_properties(VCVRackMcpServer PROPERTIES
  PREFIX   ""
  SUFFIX   ${PLUGIN_EXT}
  OUTPUT_NAME "plugin"
)

target_include_directories(VCVRackMcpServer PRIVATE
  src
  ${RACK_DIR}/include
  ${RACK_DIR}/dep/include
  ${CMAKE_BINARY_DIR}/_deps/cpp-httplib-${HTTPLIB_VERSION}/single_include
)

# =============================================================================
# Compile options — per platform
# =============================================================================
if(WIN32)
  # Windows: MinGW-w64 or MSVC
  target_compile_definitions(VCVRackMcpServer PRIVATE
    _USE_MATH_DEFINES
    WIN32_LEAN_AND_MEAN
  )
  if(MSVC)
    target_compile_options(VCVRackMcpServer PRIVATE
      /utf-8 /W4 /O2 /EHsc
    )
  else()
    # MinGW-w64
    target_compile_options(VCVRackMcpServer PRIVATE
      -Wall -Wextra -Wno-unused-parameter -O3
      -funsafe-math-optimizations
      -fno-omit-frame-pointer
    )
  endif()
elseif(APPLE)
  target_compile_options(VCVRackMcpServer PRIVATE
    -Wall -Wextra -Wno-unused-parameter -O3
    -fPIC -funsafe-math-optimizations -fno-omit-frame-pointer
  )
  if(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
    target_compile_options(VCVRackMcpServer PRIVATE -march=nehalem)
  endif()
else()
  target_compile_options(VCVRackMcpServer PRIVATE
    -Wall -Wextra -Wno-unused-parameter -O3
    -fPIC -funsafe-math-optimizations -fno-omit-frame-pointer
    -march=nocona
  )
endif()

# Define platform macro
string(REPLACE "-" "_" RACK_ARCH_MACRO "${RACK_ARCH}")
target_compile_definitions(VCVRackMcpServer PRIVATE
  ARCH_${RACK_ARCH_MACRO}
)

# =============================================================================
# Link options — per platform
# =============================================================================
if(APPLE)
  target_link_options(VCVRackMcpServer PRIVATE
    -undefined dynamic_lookup
    -Wl,-install_name,@rpath/plugin.dylib
  )
elseif(UNIX)
  target_link_options(VCVRackMcpServer PRIVATE
    -Wl,--allow-shlib-undefined
  )
  target_link_libraries(VCVRackMcpServer PRIVATE pthread)
elseif(WIN32)
  target_link_libraries(VCVRackMcpServer PRIVATE ws2_32 mswsock)
  set_target_properties(VCVRackMcpServer PROPERTIES
    WINDOWS_EXPORT_ALL_SYMBOLS ON
  )
endif()

# =============================================================================
# Install & dist targets
# =============================================================================
if(WIN32)
  set(INSTALL_DIR "$ENV{APPDATA}/Rack2/plugins/VCVRackMcpServer")
elseif(APPLE)
  if(RACK_ARCH STREQUAL "mac-arm64")
    set(INSTALL_DIR "$ENV{HOME}/Documents/Rack2/plugins-mac-arm64/VCVRackMcpServer")
  else()
    set(INSTALL_DIR "$ENV{HOME}/Documents/Rack2/plugins-mac-x64/VCVRackMcpServer")
  endif()
else()
  set(INSTALL_DIR "$ENV{HOME}/.local/share/Rack2/plugins-lin-x64/VCVRackMcpServer")
endif()
message(STATUS "Install target: ${INSTALL_DIR}")

install(TARGETS VCVRackMcpServer
  DESTINATION "${INSTALL_DIR}"
)
install(FILES "plugin.json" DESTINATION "${INSTALL_DIR}")
install(DIRECTORY "res/" DESTINATION "${INSTALL_DIR}/res")

# Dist target
add_custom_target(dist
  COMMAND ${CMAKE_COMMAND} -E echo "Packaging distributable..."
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/dist/VCVRackMcpServer"
  COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:VCVRackMcpServer>" "${CMAKE_BINARY_DIR}/dist/VCVRackMcpServer/"
  COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/plugin.json" "${CMAKE_BINARY_DIR}/dist/VCVRackMcpServer/"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_SOURCE_DIR}/res" "${CMAKE_BINARY_DIR}/dist/VCVRackMcpServer/res"
  COMMAND ${CMAKE_COMMAND} -E tar "cf" "${CMAKE_BINARY_DIR}/dist/VCVRackMcpServer-${RACK_ARCH}.zip" --format=zip "${CMAKE_BINARY_DIR}/dist/VCVRackMcpServer"
  WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
  DEPENDS VCVRackMcpServer
  COMMENT "Creating ${RACK_ARCH} distributable"
)

message(STATUS "vcv-rack-mcp-server plugin configured.")
message(STATUS "  Platform : ${RACK_ARCH}")
message(STATUS "  Rack SDK : ${RACK_DIR}")
message(STATUS "  Build    : cmake --build <build_dir>")
message(STATUS "  Install  : cmake --install <build_dir>")
message(STATUS "  Dist     : cmake --build <build_dir> --target dist")
