#!/usr/bin/env bash
set -e

LIME_PATH="${1:-$(haxelib libpath lime)}"
BINDINGS="$LIME_PATH/project/src/graphics/opengl/OpenGLBindings.cpp"

if [ ! -f "$BINDINGS" ]; then
	echo "OpenGLBindings.cpp was not found in $LIME_PATH"
	exit 1
fi

if grep -q "LIME_MOBILE_CLEAR_DEPTH_PATCH" "$BINDINGS"; then
	echo "Lime is already patched for mobile."
	exit 0
fi

perl -0pi -e 's/([ \t]*)glClearDepth \(depth\);/$1#ifdef LIME_OPENGL_GL\n$1glClearDepth (depth);\n$1#else\n$1glClearDepthf (depth);\n$1#endif/g' "$BINDINGS"
printf '\n#define LIME_MOBILE_CLEAR_DEPTH_PATCH\n' >> "$BINDINGS"

echo "Patched $BINDINGS for OpenGL ES."
