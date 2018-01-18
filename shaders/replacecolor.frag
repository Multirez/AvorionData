#include "version.inl"

uniform vec3 replacingColor;
uniform sampler2D diffuseTexture;

in vec2 texCoord;

void main()
{
    vec4 texColor = texture(diffuseTexture, vec2(texCoord.x, 1.0 - texCoord.y));

	outFragColor.rgb = replacingColor;
	outFragColor.a = texColor.a == 0.0 ? 0 : 1;
}
