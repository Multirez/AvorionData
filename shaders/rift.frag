#include "version.inl"

uniform sampler2D diffuseTexture;

uniform vec2 resolution;

in vec4 color;

void main()
{
	vec2 texCoords = gl_FragCoord.xy / resolution;

	outFragColor.rgb = texture(diffuseTexture, texCoords).rgb * 1.25;
//	outFragColor.rgb = color.rgb;

//    outFragColor.rgb = vec3(0, 0, 0);
	outFragColor.a = color.a;
}


