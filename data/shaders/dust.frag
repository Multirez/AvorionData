
#include "version.inl"

uniform sampler2D diffuseTexture;

in vec4 color;
in vec2 texCoord;



void main()
{
	vec4 texColor = texture(diffuseTexture, vec2(texCoord.x, 1.0 - texCoord.y));

	outFragColor = vec4(color.rgb * texColor.rgb, color.a * texColor.r);
}

