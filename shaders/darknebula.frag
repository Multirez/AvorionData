
#include "version.inl"

uniform sampler2D diffuseTexture;

in vec4 color;
in vec2 texCoord;



void main()
{
	vec4 texColor = texture(diffuseTexture, vec2(texCoord.x, texCoord.y));

	outFragColor = vec4(vec3(1.0) - (texColor.rgb * 1.5), 1);
}
