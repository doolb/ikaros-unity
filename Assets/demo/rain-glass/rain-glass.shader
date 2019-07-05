Shader "Unlit/rain-glass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Aspect("Aspect: x / y", range(0.1,10)) = 2
        _Size("Size", int) = 5
        _CircleIn("Circle in", float) = 0.05
        _CircleOut("Circle out", float) = 0.03
        _Speed("Drop Speed", range(0,10)) = 1
        _Distortion("Distortion", range(0,1)) = 1
        _Blur("Blur", range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float N21(float2 p){
                p = frac(p*float2(242.12, 25.123));
                p += dot(p, p+24.01);
                return frac(p.x*p.y);
            }
#if !RAIN_GLASS_DEMO
            // calc one drop layer
            int _Size;
            float _CircleIn;
            float _CircleOut;
            float3  Layer(float2 UV, float t, float2 aspect){
                float2 uv = UV * _Size * aspect;

                // uv
                uv.y += t * 0.25;
                float2 gv = frac(uv) - 0.5;
                float2 id = floor(uv);
                float n = N21(id);
                t += n * 6.28631;

                // position of time
                float w = UV.y * 10;
                float x = (n - 0.5)*0.8;
                x += (0.4-abs(x)) * sin(3*w)*pow(sin(w),6)*0.45;
                float y = -sin(t + sin(t + sin(t) * 0.5)) *0.45;
                y -= (gv.x-x)*(gv.x-x);

                // rain point
                float2 drop_pos = (gv-float2(x,y))/aspect;
                float drop = smoothstep(_CircleIn, _CircleOut, length(drop_pos));

                // rain trail
                float2 drop_trail_pos = (gv-float2(x,t*0.25))/aspect;
                drop_trail_pos.y = (frac(drop_trail_pos.y*8)/8)-_CircleOut;
                float drop_trail = smoothstep(_CircleOut, _CircleOut/2, length(drop_trail_pos));
                float fog_trail  = smoothstep(-_CircleIn, _CircleIn, drop_pos.y);
                fog_trail *= smoothstep(0.5, y, gv.y);
                drop_trail*= fog_trail * 0.22;

                // blur mod
                fog_trail *= smoothstep(_CircleIn, _CircleIn/2, abs(drop_pos.x));

                float2 offs = drop * drop_pos + drop_trail * drop_trail_pos;
                return float3(offs, fog_trail);
            }
            
            // merge texture with drop
            float _Distortion;
            float _Blur;
            fixed4 blur(float2 uv, float3 drops){
                float blur = _Blur * 7 * (1 - drops.z);
                return tex2Dlod(_MainTex, float4(uv+drops.xy*_Distortion,0,blur));
            }

            int _Aspect;
            float _Speed;
            fixed4 frag (v2f i) : SV_Target{
                float t = fmod(_Time.y, 7200) * _Speed;
                float2 aspect = float2(_Aspect, 1);
                float3 drops = Layer(i.uv, t, aspect);
                drops += Layer(i.uv*1.35+7.51,t, aspect);
                drops += Layer(i.uv*0.95+1.54,t, aspect);
                drops += Layer(i.uv*1.57-6.54,t, aspect);
                return blur(i.uv, drops);
            }
#else
            int _Size;
            float _CircleIn;
            float _CircleOut;
            int _Aspect;
            float _Speed;
            float _Distortion;
            float _Blur;
            fixed4 frag (v2f i) : SV_Target
            {
                float t = fmod(_Time.y, 7200) * _Speed;
                float4 col = 0;
                float2 aspect = float2(_Aspect, 1);
                // calc uv and gv
                float2 uv = i.uv * _Size * aspect ;  //col.rg = uv; // uv=[0:x, 0:y]
                uv.y += t * 0.25;
                float2 gv = frac(uv) - 0.5; //col.rg = gv; // gv[-0.5:0.5, -0.5:0.5]
                float2 id = floor(uv); //return float4(id.x, id.y, 0, 1);
                float n = N21(id); //return n;
                t += n*6.321;
                
                // rain point
                float w = i.uv.y * 10; // scale level 
                float x = (n-0.5)*0.8; 
                x += (0.4-abs(x)) * sin(3*w)*pow(sin(w),6)*0.45;
                float y = -sin(t+sin(t+sin(t)*0.5))*0.45; //return y; // [-0.45:0.45] 
                y -= (gv.x-x)*(gv.x-x);
                float2 drop_pos = (gv - float2(x, y))/aspect;
                float drop = smoothstep(_CircleIn,_CircleOut, length(drop_pos));

                // rain trail
                float2 drop_trail_pos = (gv - float2(x, t * 0.25)) / aspect;
                drop_trail_pos.y = (frac(drop_trail_pos.y * 8) / 8)- _CircleOut;
                float drop_trail = smoothstep(_CircleOut, _CircleOut / 2, length(drop_trail_pos)); //return drop_trail_pos.y;
                float fog_trail = smoothstep(-0.05, 0.05, drop_pos.y); //return -drop_pos.y;
                fog_trail *= smoothstep(0.5, y, gv.y); //return y - gv.y;
                drop_trail *= fog_trail * 0.1;

                fog_trail *= smoothstep(_CircleIn, _CircleIn / 2, abs(drop_pos.x)); // return fog_trail;

#if !RAIN_GLASS_DEBUG
                float blur = _Blur * 7 * (1-fog_trail);
                float2 offs = drop * drop_pos + drop_trail * drop_trail_pos * fog_trail;
                col = tex2Dlod(_MainTex, float4(i.uv + offs * _Distortion, 0, blur));
                return col;
#else
                // debug only
                col += drop;
                col += drop_trail;
                col += fog_trail * 0.5f;
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                if(gv.x > 0.47 || gv.y > 0.49)
                    return float4(1,0,0,0);
                return col;
#endif
            }
#endif
            ENDCG
        }
    }
}
