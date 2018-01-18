#include "../version.inl"

#ifndef RADIUS
#define RADIUS 10
#endif // RADIUS

uniform sampler2D sourceTexture;

#ifdef COMPATIBILITY

in vec2 texCoord;
uniform vec3 coords[RADIUS + 1];

void main()
{
    float factor = 1.0 / (RADIUS + 1.0);

    outFragColor = vec4(0);
    for (int i = 0; i <= RADIUS; i++)
    {
        outFragColor += texture(sourceTexture, texCoord + coords[i].xy) * coords[i].z;
    }
}

#else

in vec3 coords[RADIUS + 1];

void main()
{
    float factor = 1.0 / (RADIUS + 1.0);

    outFragColor = vec4(0);
    for (int i = 0; i <= RADIUS; i++)
    {
        outFragColor += texture(sourceTexture, coords[i].xy) * coords[i].z;
    }
}

#endif
