#!/bin/sh
# Shared helpers for iOS CMake configure scripts.

set -eu

IOS_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
IOS_DEPS_DIR="${DEVILUTIONX_IOS_DEPS:-}"
if [ -z "$IOS_DEPS_DIR" ]; then
	if [ -d "$IOS_ROOT/build-ios-simulator/_deps" ]; then
		IOS_DEPS_DIR="$IOS_ROOT/build-ios-simulator/_deps"
	elif [ -d "$IOS_ROOT/build-ios-sim/_deps" ]; then
		IOS_DEPS_DIR="$IOS_ROOT/build-ios-sim/_deps"
	fi
fi

ios_configure() {
	_build_dir="$1"
	_platform="$2"
	shift 2

	# Newline-delimited flags keep paths with spaces intact.
	_flags="$(mktemp "${TMPDIR:-/tmp}/dx-ios-cmake.XXXXXX")"
	printf '%s\n' \
		-S "$IOS_ROOT" \
		-B "$IOS_ROOT/$_build_dir" \
		-DCMAKE_TOOLCHAIN_FILE="$IOS_ROOT/CMake/platforms/ios.toolchain.cmake" \
		-DENABLE_BITCODE=0 \
		-DPLATFORM="$_platform" >"$_flags"
	if [ -d "$IOS_DEPS_DIR" ]; then
		for _pair in \
			SDL2:sdl2-src \
			SDL_IMAGE:sdl_image-src \
			SDL_AUDIOLIB:sdl_audiolib-src \
			LIBPNG:libpng-src \
			LIBSODIUM:libsodium-src \
			LIBSMACKERDEC:libsmackerdec-src \
			MPQFS:mpqfs-src \
			ASIO:asio-src \
			LIBZT:libzt-src \
			LUA:lua-src \
			SOL2:sol2-src \
			SHEENBIDI:sheenbidi-src \
			UNORDERED_DENSE:unordered_dense-src \
			MAGIC_ENUM:magic_enum-src; do
			_name="${_pair%%:*}"
			_dir="${_pair##*:}"
			if [ -d "$IOS_DEPS_DIR/$_dir" ]; then
				printf '%s\n' "-DFETCHCONTENT_SOURCE_DIR_${_name}=${IOS_DEPS_DIR}/${_dir}" >>"$_flags"
			fi
		done
	fi
	for _arg in "$@"; do
		printf '%s\n' "$_arg" >>"$_flags"
	done

	set --
	while IFS= read -r _flag; do
		set -- "$@" "$_flag"
	done <"$_flags"
	rm -f "$_flags"
	cmake "$@"
}
