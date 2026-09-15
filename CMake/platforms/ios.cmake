enable_language(OBJC OBJCXX)
set(CMAKE_OBJCXX_STANDARD 23)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

list(APPEND DEVILUTIONX_PLATFORM_LINK_LIBRARIES
  "-framework UIKit"
  "-framework UniformTypeIdentifiers"
  "-framework AVFoundation"
  "-framework Foundation")

# General build options.
set(BUILD_TESTING OFF)

# Disable all system dependencies.
# All of these will be fetched via FetchContent and linked statically.
set(DEVILUTIONX_SYSTEM_SDL2 OFF)
set(DEVILUTIONX_SYSTEM_SDL_IMAGE OFF)
set(DEVILUTIONX_SYSTEM_SDL_AUDIOLIB OFF)
set(DEVILUTIONX_SYSTEM_LIBSODIUM OFF)
set(DEVILUTIONX_SYSTEM_LIBPNG OFF)
set(DEVILUTIONX_SYSTEM_LUA OFF)

set(NOEXIT ON)

# Disable sanitizers. They're not supported out-of-the-box.
set(ASAN OFF)
set(UBSAN OFF)
