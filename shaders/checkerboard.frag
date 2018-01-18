#include "version.inl"

in vec4 color;

void main()
{
    if (mod(floor(gl_FragCoord.x / 3.0) + floor(gl_FragCoord.y / 3.0), 2.0) < 0.1)
    {
        discard;
    }
    outFragColor = vec4(0.25, 0.0, 0.0, 1.0);
}
