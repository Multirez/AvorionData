#include "../version.inl"

#ifndef RADIUS
#define RADIUS 10
#endif // RADIUS

#ifdef COMPATIBILITY
out vec2 texCoord;

void main(void)
{
    gl_Position.xyz = vPosition;
    gl_Position.w = 1.0;

    texCoord = vTex;
}

#else

uniform vec2 usedCoord;
uniform float stepSize;

out vec3 coords[RADIUS + 1];

float normalDistribution(float x)
{
    float a = 0.3989423;
    float e = 2.7182818;
    float b = -0.5 * x * x;

    return a * pow(e, b);
}

void main(void)
{
    gl_Position.xyz = vPosition;
    gl_Position.w = 1.0;

    // 5: -5, -3, -1, 1, 3, 5
    // 4: -4, -2, 0, 2, 4
    // 3: -3, -1, 1, 3
    // 2: -2, 0, 2

    float sum = 0.0;

    for (int ip = -RADIUS, i = 0; ip <= RADIUS; ip += 2, i++)
    {
        // calculate the coordinates for the blur
        float x = stepSize * ip + stepSize * 0.5f * sign(ip * 1.0f);

        // swap coordinates back so the x and y coordinates are at the correct place
        coords[i].xy = vTex + usedCoord * vec2(x, x);

        // calculate the factor for the blur
        float f = ip;
        float fr = RADIUS;

        float factor = normalDistribution(f / fr * 2.5);
        sum += factor;
        coords[i].z = factor;
    }

    for (int i = 0; i < RADIUS + 1; ++i)
    {
        coords[i].z /= sum;
    }
}

#endif

