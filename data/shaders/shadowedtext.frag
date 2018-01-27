
#include "version.inl"

uniform sampler2D diffuseTexture;

in vec4 color;
in vec2 texCoord;



void main()
{
	vec4 texColor = texture(diffuseTexture, texCoord);
	texColor.a *= 1.5f;

	vec4 shadow = texture(diffuseTexture, texCoord + vec2(0.005, -0.005));

	outFragColor = mix(shadow * vec4(0, 0, 0, 1), color * texColor, min(1.0, texColor.a * 4.0f));
}
