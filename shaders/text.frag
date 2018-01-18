#include "version.inl"

uniform sampler2D diffuseTexture;

in vec4 color;
in vec2 texCoord;

void main()
{
	vec4 texColor = texture(diffuseTexture, texCoord);
	texColor.a *= 1.5f;

	outFragColor = color * texColor;
}
