//https://www.shadertoy.com/view/llSGRm
#define ch0 vec2(935221.0,731292.0)
#define ch1 vec2(274497.0,33308.0)
#define ch2 vec2(934929.0,1116222.0)
#define ch3 vec2(934931.0,1058972.0)
#define ch4 vec2(137380.0,1302788.0)
#define ch5 vec2(2048263.0,1058972.0)
#define ch6 vec2(401671.0,1190044.0)
#define ch7 vec2(2032673.0,66576.0)
#define ch8 vec2(935187.0,1190044.0)
#define ch9 vec2(935187.0,1581336.0)

#define ch_A vec2(935188.0,780450.0)
#define ch_B vec2(1983767.0,1190076.0)
#define ch_C vec2(935172.0,133276.0)
#define ch_D vec2(1983764.0,665788.0)
#define ch_E vec2(2048263.0,1181758.0)
#define ch_F vec2(2048263.0,1181728.0)
#define ch_G vec2(935173.0,1714334.0)
#define ch_H vec2(1131799.0,1714338.0)
#define ch_I vec2(921665.0,33308.0)
#define ch_J vec2(66576.0,665756.0)
#define ch_K vec2(1132870.0,166178.0)
#define ch_L vec2(1065220.0,133182.0)
#define ch_M vec2(1142100.0,665762.0)
/*
vec2 ch_N = vec2(1140052.0,1714338.0);
vec2 ch_O = vec2(935188.0,665756.0);
vec2 ch_P = vec2(1983767.0,1181728.0);
vec2 ch_Q = vec2(935188.0,698650.0);
vec2 ch_R = vec2(1983767.0,1198242.0);
vec2 ch_S = vec2(935171.0,1058972.0);
vec2 ch_T = vec2(2035777.0,33288.0);
vec2 ch_U = vec2(1131796.0,665756.0);
vec2 ch_V = vec2(1131796.0,664840.0);
vec2 ch_W = vec2(1131861.0,699028.0);
vec2 ch_X = vec2(1131681.0,84130.0);
vec2 ch_Y = vec2(1131794.0,1081864.0);
vec2 ch_Z = vec2(1968194.0,133180.0);*/

#define DS vec2(6.0,7.0) //digital size
#define LX 8.0 //letter space x
#define LY 10.0//letter space y

float rand (vec2 st) {
    return fract(sin(dot(st.xy,vec2(12.9898,78.233)))*43.5453123);
}

float extract_bit(float n, float b){
   b = clamp(b,-1.0,22.0); //Fixes small artefacts on my nexus 7
   return floor(mod(floor(n / pow(2.0,floor(b))),2.0));   
}

float sprite(vec2 spr,vec2 p){
    vec2 uv=vec2(mod(p.x,LX),mod(p.y,LY));
    uv = floor(uv);
    if(uv.x>=0.0&&uv.y>=0.0&&uv.x<DS.x&&uv.y<DS.y) {  
    float bit = (DS.x-uv.x) + uv.y * DS.x;
    return extract_bit(spr.x, bit - 21.0)+extract_bit(spr.y, bit);  
    }
    return 0.0;
}
vec2 getD(float d){ d = floor(d);    
    if(d == 0.0) return ch0;if(d == 1.0) return ch1;
    if(d == 2.0) return ch2;if(d == 3.0) return ch3;
    if(d == 4.0) return ch4;if(d == 5.0) return ch5;
    if(d == 6.0) return ch6;if(d == 7.0) return ch7;
    if(d == 8.0) return ch8;if(d == 9.0) return ch9;
    if(d == 10.0) return ch_A;if(d == 11.0) return ch_B;
 if(d == 12.0) return ch_A;if(d == 13.0) return ch_B;
 if(d == 14.0) return ch_C;if(d == 15.0) return ch_D;
 if(d == 16.0) return ch_E;if(d == 17.0) return ch_F;
 if(d == 18.0) return ch_G;if(d == 19.0) return ch_H;
 if(d == 20.0) return ch_I;if(d == 21.0) return ch_J;
if(d == 22.0) return ch_K;if(d == 23.0) return ch_M;
    return vec2(0.0,0.0);
}
float rain(vec2 p){
    p.x -= mod(p.x, LX); 
    float offset= sin(p.x*LX);
    float speed=abs(cos(p.x*2.))*.12+0.08;
    float y=p.y- mod(p.y,LY);
    y = fract(y/iResolution.y+ iTime*speed + offset);
    //some random look
   y+= fract(0.4*p.x/iResolution.x+ iTime*speed-offset)*0.2;
    return 0.08/ y;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
   vec2 uv=fragCoord.xy/2.0;//  fragCoord.xy/2.0;
   float r = rain(uv);
   //use steped uv+time as random input
   vec2 s=vec2(LX,LY);
   vec2 suv = mod(uv,s)/s;
   vec2 block = uv/s - suv;
   float tm= rand(block)+iTime*0.36;
   float dig = mod(tm*10.0,24.0); //0-24
   float t = sprite(getD(dig),uv)*r;
   fragColor = vec4(0.2*t,t,0.0,1.0);
}
