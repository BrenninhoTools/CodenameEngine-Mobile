#!/usr/bin/env bash
set -e

LIME_PATH="${1:-$(haxelib libpath lime)}"
BINDINGS="$LIME_PATH/project/src/graphics/opengl/OpenGLBindings.cpp"
BUILD_XML="$LIME_PATH/project/Build.xml"

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
