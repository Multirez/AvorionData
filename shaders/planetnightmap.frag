
#include "version.inl"

#include "noise.frag"

uniform samplerCube texCube0;
//uniform samplerCube texCube1;
//uniform samplerCube texCube2;

uniform float waterLevel;

in vec3 position;



float cloud(vec3 pos, float size)
{
	vec3 p = pos + 240;
	p *= size;

	float n = noise(p);
	n = n + noise(p * 2.0f) / 2.0f;
	n = n + noise(p * 4.0f) / 4.0f;
	n = n + noise(p * 8.0f) / 8.0f;
	n = n + noise(p * 16.0f) / 16.0f;
	n = n + noise(p * 32.0f) / 32.0f;
	n = n + noise(p * 64.0f) / 64.0f;
	n = n + noise(p * 128.0f) / 128.0f;
	n = n + noise(p * 256.0f) / 256.0f;

	return 0.5 + 0.5 * n;
}

bool onStreet(vec3 position, vec3 inStreetDir)
{
	vec3 dir = normalize(position);
	vec3 streetdir = normalize(inStreetDir);

	float dotp = dot(streetdir, dir);
	if(dotp > 0.9 && dotp < 0.905) return true;

	dotp = dot(streetdir, dir);
	if(dotp > 0.93 && dotp < 0.935)	return true;

	dotp = dot(streetdir, dir);
	if(dotp > 0.94 && dotp < 0.945) return true;

	dotp = dot(streetdir, dir);
	if(dotp > 0.97 && dotp < 0.975) return true;

	dotp = dot(streetdir, dir);
	if(dotp > 0.98 && dotp < 0.985) return true;

	dotp = dot(streetdir, dir);
	if(dotp > 0.999 && dotp < 0.9999) return true;

	dotp = dot(streetdir, dir);
	if(dotp > 0.8)
	{
		vec3 c = cross(streetdir, vec3(0, 1, 0));
		dotp = dot(dir, c);
		if(abs(dotp) < 0.005) return true;

		c = cross(streetdir, c);
		dotp = dot(dir, c);
		if(abs(dotp) < 0.005) return true;

		c = cross(streetdir, vec3(0, 0, 1));
		dotp = dot(dir, c);
		if(abs(dotp) < 0.005) return true;

		c = cross(streetdir, c);
		dotp = dot(dir, c);
		if(abs(dotp) < 0.005) return true;

		c = cross(streetdir, vec3(1, 0, 0));
		dotp = dot(dir, c);
		if(abs(dotp) < 0.005) return true;

		c = cross(streetdir, c);
		dotp = dot(dir, c);
		if(abs(dotp) < 0.005) return true;
	}

	return false;
}


void main()
{
	float height = texture(texCube0, position).r;
	if(height < waterLevel) discard;

	vec3 cityColor = vec3(0.5, 0.5, 0.25);

	outFragColor.rgb = vec3(0);
	if(onStreet(position, vec3(0.8, 1.0, 0.4)) == true) outFragColor.rgb = cityColor;
	if(onStreet(position, vec3(-0.3, -1.0, -0.2))) outFragColor.rgb = cityColor;
	if(onStreet(position, vec3(-0.6, -0.6, -0.4))) outFragColor.rgb = cityColor;
	if(onStreet(position, vec3(-0.5, 0.6, -0.4))) outFragColor.rgb = cityColor;
	if(onStreet(position, vec3(0.5, 0.6, -0.4))) outFragColor.rgb = cityColor;
	if(onStreet(position, vec3(0.5, -0.6, 0.4))) outFragColor.rgb = cityColor;

	// if the pixel is inside one of the street circles/lines dont discard it
	// in this large granular discard check

	if(outFragColor.rgb != cityColor)
	{
		if(noise(position * 1.0f) > 0) discard;
		if(noise(position * 5.0f) > 0) discard;
		if(noise(position * 10.0f) > 0) discard;
		if(noise(position * 20.0f) > 0) discard;

		outFragColor.rgb = cityColor;
	}

	if(noise(position * 64.0f) > 0) discard;
	if(noise(position * 128.0f) > 0) discard;
	if(noise(position * 256.0f) > 0) discard;

	outFragColor.rgb *= cloud(position, 1.0);

	outFragColor.a = 1.0;
}

