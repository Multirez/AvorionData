
#include "version.inl"

#include "noise.frag"

uniform samplerCube starTexture;

in vec4 color;
in vec3 normal;
in vec3 position;



void main()
{
    float brightness = noise(position * 2.5 + 240.0);

	if(brightness > 0.2) brightness = 1.0;
	else if(brightness < -0.2) brightness = 0.0;
	else brightness = mix(0.0, 1.0, (brightness + 0.2) / 0.4);

	vec4 texColor = texture(starTexture, position);


	outFragColor = vec4(texColor.xyz * brightness + brightness * 0.05 * color.rgb, 1);
}
