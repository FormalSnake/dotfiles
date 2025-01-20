/*originals https://www.shadertoy.com/view/dlyfWc https://www.shadertoy.com/view/XlfGRj https://www.shadertoy.com/view/MdXSzS*/
#define iterations 17
#define formuparam 0.53

#define volsteps 20
#define stepsize 0.1

#define zoom   0.800
#define tile   0.850
#define speed  0.000

#define brightness 0.0015
#define darkmatter 0.300
#define distfading 0.730
#define saturation 0.850


float random2D(vec2 v, float seed)
{
    return fract(sin(dot(v , vec2(7.5912,3.89273)))*4293.12978 * seed);
}



float PerlinNoise(vec2 v, vec2 movDir, float speed2, float seed)
{
    v += movDir * iTime*speed2;
    vec2 v_Floor = floor(v);
    vec2 v_1_0 = v_Floor + vec2(1.0,0.0);
    vec2 v_0_1 = v_Floor + vec2(0.0,1.0);
    vec2 v_1_1 = v_Floor + vec2(1.0,1.0);
   
    vec2 lerp = fract(v);
   
    float positiveCos = (cos(iTime)+ 1.0) * 10.0 ;
    vec2 smoothLerp =  lerp * lerp * (3.0 - 2.0 * lerp);
   
    float noise_Floor = random2D(v_Floor , seed);
    float noise_1_0 = random2D(v_1_0 , seed);
    float noise_0_1 = random2D(v_0_1 , seed);
    float noise_1_1 = random2D(v_1_1 , seed);
   
    float noise_Final_0 = mix(noise_Floor, noise_1_0, smoothLerp.x);
    float noise_Final_1 = mix(noise_0_1, noise_1_1, smoothLerp.x );
   
    return mix(noise_Final_0, noise_Final_1, smoothLerp.y );
   
}


float NoiseDensity(vec2 v, vec2 movDir, float speed2, float seed, float amplitudeChange,
int octaves,  float clarity,float ratioOfDensity, float amountOfDensity)
{
    float density = 0.0;
    float amplitude = 1.0;
   
    for(int i = 0; i < octaves; i++)
    {
       density+= PerlinNoise(v * pow(clarity, float(i)),movDir, speed2, seed) * amplitude;
       amplitude *=  amplitudeChange;
    }
   
    return ratioOfDensity * (density + amountOfDensity);
}

void mainVR( out vec4 fragColor, in vec2 fragCoord, in vec3 ro, in vec3 rd )
{
//get coords and direction
vec3 dir=rd;
vec3 from=ro;

//volumetric rendering
float s=0.1,fade=1.;
vec3 v=vec3(0.);
for (int r=0; r<volsteps; r++) {
vec3 p=from+s*dir*.5;
p = abs(vec3(tile)-mod(p,vec3(tile*2.))); // tiling fold
float pa,a=pa=0.;
for (int i=0; i<iterations; i++) {
p=abs(p)/dot(p,p)-formuparam;
            p.xy*=mat2(cos(iTime*0.05),sin(iTime*0.05),-sin(iTime*0.05),cos(iTime*0.05));// the magic formula
a+=abs(length(p)-pa); // absolute sum of average change
pa=length(p);
}
float dm=max(0.,darkmatter-a*a*.001); //dark matter
a*=a*a; // add contrast
if (r>6) fade*=1.2-dm; // dark matter, don't render near
//v+=vec3(dm,dm*.5,0.);
v+=fade;
v+=vec3(s,s*s,s*s*s*s)*a*brightness*fade; // coloring based on distance
fade*=distfading; // distance fading
s+=stepsize;
}
v=mix(vec3(length(v)),v,saturation); //color adjust
fragColor = vec4(v*.02,1.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
//get coords and direction
vec2 uv=fragCoord.xy/iResolution.xy-.5;
uv.y*=iResolution.y/iResolution.x;
    float t = iTime * 1.1 + ((.25 + .05 * sin(iTime * .1))/(length(uv.xy) + .27)) * 2.2;
float si = tan(t);
float co = cos(t);
mat2 ma = mat2(co, si, -si, co);
    uv*=ma;
vec3 dir=vec3(uv*zoom,1.);
float time=iTime*speed+.25;
vec2 originalUv = uv;
    vec2 uv_1 = uv *  2.0;
    vec2 uv_2 = uv * 10.0;
   
    vec2 uv_3 = uv * 4.0;

    float clouds_1 = NoiseDensity(uv_1, vec2(1.0,1.0),0.1,  7.3223213, -0.8, 8, 2.0,
    2.3, -0.6);
    float clouds_2 = NoiseDensity(uv_2,  vec2(10.0,1.0),0.2, 91.3223213, -0.8, 8, 2.0,
    3.3, -0.3);
   
    float clouds_3 = NoiseDensity(uv_3,  vec2(1.0,1.0),0.3, 72.3223213, -0.8, 8, 2.0,
    1.0, -0.5);
   
    float clouds_1_2 = clouds_1 *clouds_2;
    vec3 skyCol = mix(vec3(1.0,0.75,1.0), vec3(1.0,1.55,1.0), originalUv.y) ;
    vec3 col;
    vec3 cloudCol_1 = vec3(1.0,1.05,0.1);
   
    vec3 cloudCol_3 = vec3(1.0, 0.0,2.0);
    col = mix( skyCol, cloudCol_1, clouds_1_2);
    col = mix(col, cloudCol_3,clouds_3);
//mouse rotation
float a1=.5+iMouse.x/iResolution.x*2.;
float a2=.8+iMouse.y/iResolution.y*2.;
mat2 rot1=mat2(cos(a1),sin(a1),-sin(a1),cos(a1));
mat2 rot2=mat2(cos(a2),sin(a2),-sin(a2),cos(a2));

vec3 from=vec3(1.,.5,0.5);
from+=vec3(time*2.,time,-2.);
from.xz*=rot1;
from.xy*=rot2;

mainVR(fragColor, fragCoord, from, dir);
    fragColor*=vec4(col,1.);
}



