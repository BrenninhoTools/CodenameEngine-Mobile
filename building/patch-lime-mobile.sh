#!/usr/bin/env bash
set -e

LIME_PATH="${1:-$(haxelib libpath lime)}"
BINDINGS="$LIME_PATH/project/src/graphics/opengl/OpenGLBindings.cpp"
BUILD_XML="$LIME_PATH/project/Build.xml"
SDL_SYSTEM="$LIME_PATH/project/src/backend/sdl/SDLSystem.cpp"
JNI_SOURCE="$LIME_PATH/project/src/system/JNI.cpp"
APPLE_SYSTEM="$LIME_PATH/project/src/system/System.mm"

for file in "$BINDINGS" "$BUILD_XML"; do
	if [ ! -f "$file" ]; then
		echo "$file was not found."
		exit 1
	fi
done

if grep -q "LIME_MOBILE_CLEAR_DEPTH_PATCH" "$BINDINGS"; then
	echo "OpenGLBindings.cpp is already patched."
else
	perl -0pi -e 's/([ \t]*)glClearDepth \(depth\);/$1#ifdef LIME_OPENGL_GL\n$1glClearDepth (depth);\n$1#else\n$1glClearDepthf (depth);\n$1#endif/g' "$BINDINGS"
	printf '\n#define LIME_MOBILE_CLEAR_DEPTH_PATCH\n' >> "$BINDINGS"
	echo "Patched OpenGLBindings.cpp for OpenGL ES."
fi

if grep -q '<set name="LIME_IMGUI" value="1" if="LIME_SDL" unless="android || ios || tvos" />' "$BUILD_XML"; then
	echo "Build.xml is already patched."
else
	perl -pi -e 's|<set name="LIME_IMGUI" value="1" if="LIME_SDL" />|<set name="LIME_IMGUI" value="1" if="LIME_SDL" unless="android \|\| ios \|\| tvos" />|' "$BUILD_XML"
	if ! grep -q 'unless="android || ios || tvos"' "$BUILD_XML"; then
		echo "Could not disable ImGui for mobile in Build.xml."
		exit 1
	fi
	echo "Disabled ImGui for mobile in Build.xml."
fi

if [ -f "$SDL_SYSTEM" ] && [ -f "$JNI_SOURCE" ] && grep -q "JNI::GetEnv ()" "$JNI_SOURCE"; then
	if grep -q "LIME_MOBILE_JNI_ENV_PATCH" "$SDL_SYSTEM"; then
		echo "SDLSystem.cpp is already patched."
	elif grep -q "JNI::GetEnv ()" "$SDL_SYSTEM"; then
		perl -0pi -e 's/([ \t]*)void \*JNI::GetEnv \(\) \{.*?\n\1\}\n/$1#ifndef ANDROID\n$1void *JNI::GetEnv () {\n\n$1\treturn 0;\n\n$1}\n$1#endif\n/s' "$SDL_SYSTEM"
		if [ "$(grep -c "JNI::GetEnv ()" "$SDL_SYSTEM")" != "1" ] || ! grep -q "#ifndef ANDROID" "$SDL_SYSTEM"; then
			echo "Could not remove the duplicated JNI::GetEnv from SDLSystem.cpp."
			exit 1
		fi
		printf '\n// LIME_MOBILE_JNI_ENV_PATCH\n' >> "$SDL_SYSTEM"
		echo "Removed the duplicated JNI::GetEnv from SDLSystem.cpp on Android."
	fi
fi

if [ -f "$APPLE_SYSTEM" ]; then
	if grep -q "LIME_MOBILE_APPLE_STRINGS_PATCH" "$APPLE_SYSTEM"; then
		echo "System.mm is already patched."
	else
		perl -pi -e 's/return systemInfo\.machine;/return strdup (systemInfo.machine);/; s/return \[\[\[UIDevice currentDevice\] systemVersion\] UTF8String\];/return strdup ([[[UIDevice currentDevice] systemVersion] UTF8String]);/' "$APPLE_SYSTEM"
		if ! grep -q "#include <string.h>" "$APPLE_SYSTEM"; then
			perl -0pi -e 's/(#include <system\/System.h>)/#include <string.h>\n$1/' "$APPLE_SYSTEM"
		fi
		if grep -q "return systemInfo.machine;" "$APPLE_SYSTEM" || grep -q "return \[\[\[UIDevice currentDevice\] systemVersion\] UTF8String\];" "$APPLE_SYSTEM"; then
			echo "Could not patch the returned strings in System.mm."
			exit 1
		fi
		printf '\n// LIME_MOBILE_APPLE_STRINGS_PATCH\n' >> "$APPLE_SYSTEM"
		echo "Patched System.mm to return heap copies of the device strings."
	fi
fi

