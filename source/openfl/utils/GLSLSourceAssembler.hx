package openfl.utils;

import openfl.utils._internal.Log;
import openfl.display.OpenGLRenderer;
import openfl.display.Shader;
import openfl.display.ShaderPrecision;
#if lime
import lime.graphics.opengl.GL;
#end

@:access(openfl.display.OpenGLRenderer)
class GLSLSourceAssembler
{
	/**
		Gets this platform stable GLSL version
	**/
	public static inline function getDefaultVersion():String
	{
		#if (web || mobile)
		return "300 es";
		#elseif mac
		return "410 core";
		#else
		return "330 core";
		#end
	}

	/**
		Gets this platform default legacy full-compatible GLSL version
	**/
	public static inline function getDefaultLegacyVersion():String
	{
		#if (web || mobile || mac)
		return "100";
		#else
		return "120";
		#end
	}

	/**
		Gets the current context GLSL version
	**/
	public static function getContextVersion():String
	{
		var dataVersion = __getContextVersion();
		return dataVersion.versionProfile == null ? Std.string(dataVersion.versionNumber) :
			dataVersion.versionNumber + " " + dataVersion.versionProfile;
	}

	/**
		Gets the GLSL Version from the source
	**/
	public static function getVersionFromSource(source:String, ?defaultVersion:Null<String>):Null<String>
	{
		var glVersionFinder:EReg = __getVersionFinder();
		if (!glVersionFinder.match(source)) return defaultVersion;

		var profile:String = glVersionFinder.matched(2);
		return profile == null ? glVersionFinder.matched(1) : glVersionFinder.matched(1) + " " + profile;
	}

	/**
		Corrects the GLSL Version to the compatbile GLSL version in this platform
	**/
	public static function getCompatibleVersion(version:Null<String>):String
	{
		var dataVersion = __getVersion(version);
		__getCompatibleVersion(dataVersion);

		return dataVersion.versionProfile == null ? Std.string(dataVersion.versionNumber) :
			dataVersion.versionNumber + " " + dataVersion.versionProfile;
	}

	/**
		Provides additional `#extension` directives to insert in the fragment shaders.
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var fragmentExtensions:Map<String, String>;

	/**
		Provides an additional pragmas to use in (child class of) fragment shaders.
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var fragmentPragmas:Map<String, String>;

	/**
		Get or set the fragment source used when targeting OpenGL.
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var fragmentSource:String;

	/**
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var version:String;

	/**
		Provides additional `#extension` directives to insert in the vertex shaders.
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var vertexExtensions:Map<String, String>;

	/**
		Provides an additional pragmas to use in (child class of) vertex shaders.
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var vertexPragmas:Map<String, String>;

	/**
		Get or set the vertex source used when targeting OpenGL.
		Not recommended for future uses, an left-over from original openfl/openfl
		feature/shader-improvements branch.
	**/
	public var vertexSource:String;

	@:noCompletion private var __stack:Int = -1;
	@:noCompletion private var __sourceKey:String;
	@:noCompletion private var __pragmaOnces:Map<String, Bool>;

	/**
		Creates a new GLSLSourceAssembler instance
	**/
	public function new()
	{
		fragmentExtensions = new Map();
		fragmentPragmas = new Map();
		vertexExtensions = new Map();
		vertexPragmas = new Map();
	}

	/**
		Reset all values on this object
	**/
	public function clear():Void
	{
		fragmentPragmas = new Map();
		fragmentExtensions = new Map();
		fragmentSource = null;
		vertexPragmas = new Map();
		vertexExtensions = new Map();
		vertexSource = null;
		version = null;
	}

	/**
		Merge another GLSLSourceAssembler with `this`
		Modifies `this` GLSLSourceAssembler
	**/
	public function concat(other:GLSLSourceAssembler):GLSLSourceAssembler
	{
		addFragmentPragmas(other.fragmentPragmas);
		addFragmentExtensions(other.fragmentExtensions);
		if (other.fragmentSource != null) fragmentSource = other.fragmentSource;
		addVertexPragmas(other.vertexPragmas);
		addVertexExtensions(other.vertexExtensions);
		if (other.vertexSource != null) vertexSource = other.vertexSource;
		if (other.version != null) version = other.version;
		return this;
	}

	/**
		Add a GL extension for both vertex and fragment source
	**/
	public function addExtension(extension:String, behavior:String = "require"):Void
	{
		addVertexExtension(extension, behavior);
		addFragmentExtension(extension, behavior);
	}

	/**
		Adds GL extensions at once for both vertex and fragment source
	**/
	public function addExtensions(extensions:Map<String, String>):Void
	{
		addVertexExtensions(extensions);
		addFragmentExtensions(extensions);
	}

	/**
		Add a GL extension for the fragment source
	**/
	public function addFragmentExtension(extension:String, behavior:String = "require"):Void
	{
		fragmentExtensions.set(extension, behavior);
	}

	/**
		Adds GL extensions at once for the fragment source
	**/
	public function addFragmentExtensions(extensions:Map<String, String>):Void
	{
		for (key in extensions) fragmentExtensions[key] = extensions[key];
	}

	/**
		Add a GL extension for the vertex shader
	**/
	public function addVertexExtension(extension:String, behavior:String = "require"):Void
	{
		vertexExtensions.set(extension, behavior);
	}

	/**
		Adds GL extensions at once for the vertex source
	**/
	public function addVertexExtensions(extensions:Map<String, String>):Void
	{
		for (key in extensions) vertexExtensions[key] = extensions[key];
	}

	/**
		Append a pragma that will be used for assembling the fragment source
	**/
	public function addFragmentPragma(pragma:String, source:String):Void
	{
		fragmentPragmas.set(pragma, source);
	}

	/**
		Append a pragma that will be used for assembling the vertex source
	**/
	public function addVertexPragma(pragma:String, source:String):Void
	{
		vertexPragmas.set(pragma, source);
	}

	/**
		Append pragmas at once that will be used for assembling the fragment source
	**/
	public function addFragmentPragmas(pragmas:Map<String, String>):Void
	{
		for (pragma in pragmas) addFragmentPragma(pragma, pragmas[pragma]);
	}

	/**
		Append pragmas at once that will be used for assembling the fragment source
	**/
	public function addVertexPragmas(pragmas:Map<String, String>):Void
	{
		for (pragma in pragmas) addVertexPragma(pragma, pragmas[pragma]);
	}

	/**
		Append source to the pragma body of the GLSL fragment source
		A shortcut for `addFragmentPragma("body", source)`
	**/
	public inline function addFragmentBody(source:String):Void
	{
		addFragmentPragma("body", source);
	}

	/**
		Append source to the pragma header of the GLSL fragment source
		A shortcut for `addFragmentPragma("header", source)`
	**/
	public inline function addFragmentHeader(source:String):Void
	{
		addFragmentPragma("header", source);
	}

	/**
		Append source to the pragma body of the GLSL vertex source
		A shortcut for `addVertexPragma("body", source)`
	**/
	public inline function addVertexBody(source:String):Void
	{
		addVertexPragma("body", source);
	}

	/**
		Append source to the pragma header of the GLSL vertex source
		A shortcut for `addVertexPragma("header", source)`
	**/
	public inline function addVertexHeader(source:String):Void
	{
		addVertexPragma("header", source);
	}

	/**
		Build necessary extensions for a GLSL source
	**/
	public function buildExtensions(extensions:Map<String, String>, version:String, isVertex:Bool):Map<String, String>
	{
		var dataVersion = __getVersion(version);
		return __buildExtensions(extensions, dataVersion.versionNumber, dataVersion.versionProfile, isVertex);
	}

	/**
		Apply compatibility transforms to the specified GLSL shader sources to convert for the specified newer version.

		@param	source	The GLSL source to convert.
		@param	targetVersion	Optional; The target GLSL version.
		@param	isVertex	Whether the GLSL source is a component of a vertex shader. False if it is a fragment shader.
		@return	The converted GLSL source.
	**/
	public function applyCompatibility(source:String, ?targetVersion:String, isVertex:Bool):String
	{
		var dataVersion = __getVersion(targetVersion ?? getDefaultVersion());
		return __applyCompatibility(source, isVertex, dataVersion.versionNumber, dataVersion.versionProfile);
	}

	/**
		Assembles and finalize this GLSL fragment source code with optional compatibility.

		@param	useCompatibility	Whether to use a version conversion for finalizing.
		@return	The finalized GLSL fragment source code.
	**/
	public function assembleFragmentSource(useCompatibility:Bool = true):String
	{
		return assembleSource(fragmentSource, fragmentPragmas, fragmentExtensions, version, false, useCompatibility);
	}

	/**
		Assembles and finalize this GLSL vertex source code with optional compatibility.

		@param	useCompatibility	Whether to use a version conversion for finalizing.
		@return	The finalized GLSL vertex source code.
	**/
	public function assembleVertexSource(useCompatibility:Bool = true):String
	{
		return assembleSource(vertexSource, vertexPragmas, vertexExtensions, version, true, useCompatibility);
	}

	/**
		Assembles and finalize a GLSL source code with optional compatibility version conversion, extensions, and pragmas.

		@param	source	The GLSL source to be assembled.
		@param	pragmas	Optional; The pragmas to be used for finalizing the source that have requested pragmas.
		@param	extensions	Optional; The extensions to be used for finalizing.
		@param	version	Optional; The target GLSL version to be used for finalizing.
		@param	isVertex	Whether the GLSL source is a component of a vertex shader. False if it is a fragment shader.
		@param	useCompatibility	Whether to use a version conversion for finalizing.
		@return	The finalized GLSL source.
	**/
	public function assembleSource(source:String, ?pragmas:Map<String, String>, ?extensions:Map<String, String>,
			?version:String, isVertex:Bool, useCompatibility:Bool = true, precisionHint:ShaderPrecision = FULL):String
	{
		if (version == null) version = getDefaultVersion();

		if (source == null)
		{
			// There's nothing to assemble with, but just return it with a prefix instead anyway.
			var dataVersion = __getVersion(version);
			__getCompatibleVersion(dataVersion);

			return __appendPrefix(null, dataVersion.versionNumber, dataVersion.versionProfile, extensions, isVertex, precisionHint);
		}

		source = __assembleSource(source, isVertex, pragmas);

		var data = __getSource(source, version, extensions == null ? new Map() : extensions.copy());

		__getCompatibleVersion(data);
		__buildExtensions(data.extensions, data.versionNumber, data.versionProfile, isVertex);

		if (useCompatibility)
		{
			data.source = __applyCompatibility(data.source, isVertex, data.versionNumber, data.versionProfile);
		}

		return __appendPrefix(data.source, data.versionNumber, data.versionProfile, data.extensions, isVertex, precisionHint);
	}

	private function __applyCompatibility(source:String, isVertex:Bool, versionNumber:Int, versionProfile:Null<String>):String
	{
		if (versionProfile != "compatibility" && versionNumber >= 130)
		{
			// Recall: Attribute values are per-vertex, varying values are per-fragment
			// Thus, an `out` value in the vertex shader is an `in` value in the fragment shader
			var varyingKeyword:EReg = ~/\bvarying\s+(?:lowp\s+|mediump\s+|highp\s+)?([A-Za-z0-9_]+)\s+([^\s]+)/gu;

			if (isVertex)
			{
				var attributeKeyword:EReg = ~/\battribute\s+([A-Za-z0-9_]+)\s+([^\s]+)/gu;

				source = attributeKeyword.replace(source, "in $1 $2");
				source = varyingKeyword.replace(source, "out $1 $2");
			}
			else
			{
				var glFragColorKeyword:EReg = ~/\bgl_FragColor\b/g;

				source = varyingKeyword.replace(source, "in $1 $2");
				source = glFragColorKeyword.replace(source, "openfl_FragColor");
			}

			var texture2DKeyword:EReg = ~/\btexture2D\b/g;

			if (texture2DKeyword.match(source)) {
				var textureKeyword:EReg = ~/\btexture\b/g;

				source = textureKeyword.replace(source, "textureRESERVED");
				source = texture2DKeyword.replace(source, "texture");
			}

			return source;
		}
		else
		{
			return source;
		}
	}

	private function __assembleSource(source:String, isVertex:Bool, ?pragmas:Map<String, String>):String
	{
		if (++__stack == 0)
		{
			__pragmaOnces = [];
			__sourceKey = null;
		}

		if (pragmas != null) source = __appendPragmas(source, isVertex, pragmas);
		source = __appendIncludes(source, isVertex, pragmas);

		if (__stack == 0)
		{
			__pragmaOnces = null;
		}
		__stack--;

		return source;
	}

	private function __appendPragmas(source:String, isVertex:Bool, pragmas:Map<String, String>):String
	{
		return __getPragmaFinder().map(source, (glPragmaFinder:EReg) ->
		{
			var pragma = glPragmaFinder.matched(1);
			if (pragma == "once")
			{
				if (__sourceKey != null) __pragmaOnces.set(__sourceKey, true);
				return "";
			}

			if (!pragmas.exists(pragma)) return '#pragma $pragma';
			return '/*#pragma $pragma*/\n' + __assembleSource(pragmas.get(pragma), isVertex, pragmas);
		});
	}

	private function __appendIncludes(source:String, isVertex:Bool, ?pragmas:Map<String, String>):String
	{
		return __getIncludeFinder().map(source, (regex:EReg) ->
		{
			var key = regex.matched(1);
			if (__pragmaOnces.get(key)) return "";

			var include = __getIncludeSource(key, isVertex);
			if (include == null) return '/*Unknown include $key*/';

			var prevSourceKey = __sourceKey;
			__sourceKey = key;
			include = __assembleSource(include, isVertex, pragmas);
			__sourceKey = prevSourceKey;

			return '/*#include $key*/\n' + include;
		});
	}

	private function __appendPrefix(source:String, versionNumber:Int, versionProfile:Null<String>, extensions:Map<String, String>, isVertex:Bool,
			precisionHint:Null<ShaderPrecision>):String
	{
		var output = new StringBuf();
		output.add('#version $versionNumber${versionProfile != null ? " " + versionProfile : ""}\n\n');

		if (extensions != null)
		{
			var filled = false;
			for (key in extensions.keys())
			{
				filled = true;
				output.add('#extension $key : ${extensions[key]}\n');
			}

			if (filled) output.add('\n');
		}

		#if (web || mobile)
		if (source == null || !(~/\bprecision\s+(highp|mediump|lowp)\s+float\s*;/g).match(source))
		{
			if (precisionHint == FAST)
			{
				output.add("#ifdef GL_ES\nprecision lowp float;\n#endif\n\n");
			}
			else
			{
				output.add("#ifdef GL_ES\n#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\n#endif\n\n");
			}
		}
		#end

		if (OpenGLRenderer.__complexBlendsSupported && !isVertex && versionNumber >= 150 && (source == null || !(~/\blayout\s*\(blend_support_\w+\)\s+out\s*;/g).match(source)))
		{
			var behavior = extensions.get("GL_KHR_blend_equation_advanced");
			if (behavior == "enable" || behavior == "require")
			{
				output.add("#ifdef GL_KHR_blend_equation_advanced\nlayout(blend_support_all_equations) out;\n#endif\n\n");
			}
		}

		if (source != null)
		{
			if (!isVertex && (versionNumber >= 130 && versionProfile != "compatibility") && StringTools.contains(source, "openfl_FragColor"))
			{
				if (versionNumber >= 300)
				{
					if (!(~/\blayout\s*\(location\s*=\s*0\)\s*out\s+vec4\s+openfl_FragColor\s*;/g).match(source))
					{
						output.add("layout(location = 0) out vec4 openfl_FragColor;\n\n");
					}
				}
				else if (!(~/\bout\s+vec4\s+openfl_FragColor\s*;/g).match(source))
				{
					output.add("out vec4 openfl_FragColor;\n\n");
				}
			}

			output.add(source);
		}

		return output.toString();
	}

	private function __buildExtensions(extensions:Map<String, String>, versionNumber:Int, versionProfile:Null<String>, isVertex:Bool):Map<String, String>
	{
		if (versionNumber >= 300 && versionNumber < 400)
		{
			// In 300, 310, 320, 330; it is required to include this extension.
			if (!extensions.exists("GL_ARB_separate_shader_objects") && !extensions.exists("GL_EXT_separate_shader_objects"))
			{
				if (__isVersionES(versionNumber, versionProfile))
				{
					if (versionNumber < 310) extensions.set("GL_EXT_separate_shader_objects", "require");
				}
				else extensions.set("GL_ARB_separate_shader_objects", "require");
			}
		}

		// Enable complex blend modes if supported.
		if (OpenGLRenderer.__complexBlendsSupported && !isVertex && versionNumber >= 150)
		{
			extensions.set("GL_KHR_blend_equation_advanced", "enable");

			// This is for getting complex blend modes to work with AMD Card quirks.
			// 'gl_SampleID' : required extension not requested: GL_ARB_sample_shading
			if (OpenGLRenderer.__complexBlendsSupported && !extensions.exists("GL_ARB_sample_shading") && !extensions.exists("GL_OES_sample_shading"))
			{
				if (__isVersionES(versionNumber, versionProfile)) extensions.set("GL_OES_sample_shading", "enable");
				else extensions.set("GL_ARB_sample_shading", "enable");
			}
		}

		return extensions;
	}

	private function __getIncludeSource(include:String, fromVertex:Bool):Null<String>
	{
		return null;
	}

	private static function __getCompatibleVersion(dataVersion:GLSLDataVersion)
	{
		var versionNumber = dataVersion.versionNumber;
		var isES = __isVersionES(versionNumber, dataVersion.versionProfile);

		var contextVersion = __getContextVersion();
		var isContextES = __isVersionES(contextVersion.versionNumber, contextVersion.versionProfile);

		#if mac
		if ((isES == (isES = false)))
		{
			if (versionNumber <= 100) dataVersion.versionNumber = 100;
			else dataVersion.versionNumber = 410;
		}
		else
		{
			if (versionNumber <= 100) dataVersion.versionNumber = 100;
			else if (versionNumber <= 320) dataVersion.versionNumber = 150;
			else dataVersion.versionNumber = 410;
		}
		#else
		if (isES == (isES = isContextES)) dataVersion.versionNumber = versionNumber;
		else if (isContextES)
		{
			if (versionNumber <= 120) dataVersion.versionNumber = 100;
			else if (versionNumber <= 420) dataVersion.versionNumber = 300;
			else if (versionNumber <= 430) dataVersion.versionNumber = 310;
			else dataVersion.versionNumber = 320;
		}
		else
		{
			if (versionNumber <= 100) dataVersion.versionNumber = 120;
			else if (versionNumber <= 300) dataVersion.versionNumber = 300;
			else if (versionNumber <= 310) dataVersion.versionNumber = 430;
			else dataVersion.versionNumber = 450;
		}
		#end

		if (!OpenGLRenderer.__separateShadersSupported)
		{
			if (isES ? (dataVersion.versionNumber == 300 && contextVersion.versionNumber >= 310)
					: (dataVersion.versionNumber >= 330 && dataVersion.versionNumber < 410 && contextVersion.versionNumber >= 410))
			{
				dataVersion.versionNumber = isES ? 310 : 410;
			}
			// this is horrible
			else if (isES)
				dataVersion.versionNumber = 100;
			else
				dataVersion.versionNumber = 150;
		}
		else if (dataVersion.versionNumber > contextVersion.versionNumber)
			dataVersion.versionNumber = contextVersion.versionNumber;

		if (isES)
		{
			if (dataVersion.versionNumber >= 300) dataVersion.versionProfile = "es";
			else dataVersion.versionProfile = null;
		}
		else if (dataVersion.versionNumber >= 150)
		{
			if (dataVersion.versionProfile != "compatibility") dataVersion.versionProfile = "core";
		}
		else
			dataVersion.versionProfile = null;
	}

	private static function __getContextVersion():GLSLDataVersion
	{
		#if lime
		var e = ~/\d\.\d/i, context = Std.string(lime.app.Application.current.window.context.type).toUpperCase();
		if (e.match(GL.getParameter(GL.SHADING_LANGUAGE_VERSION)))
		{
			var isES = context == "WEBGL" || StringTools.endsWith(context, "ES");
			var version = Std.int(Math.max(Math.round(Std.parseFloat(e.matched(0)) * 100), 100));

			if (isES)
				return version >= 300 ? {versionNumber: version, versionProfile: "es"} : {versionNumber: version, versionProfile: null};
			else
				return {versionNumber: version, versionProfile: null};
		}
		#end

		return {versionNumber: 100, versionProfile: null};
	}

	private static function __getSource(source:String, defaultVersion:String, extensions:Map<String, String>):GLSLDataSource
	{
		var versionNumber:Int, versionProfile:Null<String>;

		var glVersionFinder:EReg = __getVersionFinder();
		if (glVersionFinder.match(source))
		{
			source = glVersionFinder.matchedLeft() + glVersionFinder.matchedRight();
			versionNumber = Std.parseInt(glVersionFinder.matched(1));
			versionProfile = glVersionFinder.matched(2);
		}
		else
		{
			var glVersionSeperator:EReg = __getVersionSeperator();
			if (glVersionSeperator.match(defaultVersion))
			{
				versionNumber = Std.parseInt(glVersionSeperator.matched(1));
				versionProfile = glVersionSeperator.matched(2);
			}
			else
			{
				Log.error('Unable to find an unknown GLSL version "$defaultVersion"');
				return null;
			}
		}

		source = __getExtensionFinder().map(source, (regex:EReg) ->
		{
			extensions.set(regex.matched(1), regex.matched(2));
			return "";
		});

		return {source: source, versionNumber: versionNumber, versionProfile: versionProfile, extensions: extensions};
	}

	private static function __getVersion(version:String):GLSLDataVersion
	{
		var glVersionSeperator:EReg = __getVersionSeperator();
		if (glVersionSeperator.match(version))
		{
			return {
				versionNumber: Std.parseInt(glVersionSeperator.matched(1)),
				versionProfile: glVersionSeperator.matched(2)
			};
		}
		else
		{
			Log.error('Unable to find an unknown GLSL version "${version}"');
			return null;
		}
	}

	private static inline function __getExtensionFinder():EReg
	{
		return ~/#extension\s+([A-Za-z0-9_]+)\s+:\s+(enable|require|warn|disable|all)\b/g;
	}

	private static inline function __getPragmaFinder():EReg
	{
		return ~/#pragma\s+(\w+)\b/g;
	}

	private static inline function __getIncludeFinder():EReg
	{
		return ~/#(?|include|import)\s*(?|"([^"]+)"|'([^']+)')/g;
	}

	private static inline function __getVersionFinder():EReg
	{
		return ~/#version\s+(\d+)(?:\s+(core|es|compatibility)\b)?/;
	}

	private static inline function __getVersionSeperator():EReg
	{
		return ~/(\d+)(?:\s+(core|es|compatibility)\b)?/;
	}

	private static inline function __isVersionES(versionNumber:Int, ?versionProfile:String):Bool
	{
		return versionProfile == "es" || (versionProfile == null
			&& (versionNumber == 100 || versionNumber == 300 || versionNumber == 310 || versionNumber == 320));
	}
}

private typedef GLSLDataVersion =
{
	versionNumber:Int,
	versionProfile:Null<String>
}

private typedef GLSLDataSource = GLSLDataVersion &
{
	source:String,
	extensions:Map<String, String>
}