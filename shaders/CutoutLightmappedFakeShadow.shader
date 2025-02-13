Shader "Roundy/Vegetation/CutoutLightmappedWindFakeShadow2_BIRP"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
        _Cutoff ("Alpha cutoff", Range(0.15,0.85)) = 0.5
        _AlphaCoverageStrength ("Alpha Coverage Strength", Range(0.1, 2.0)) = 1.0
        _WindSpeed ("Wind Speed", Range(0, 10)) = 1
        _WindAmplitude ("Wind Amplitude", Range(0, 1)) = 0.1
        _VertexColorOffset ("Vertex Color Offset", Range(0, 1)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
        _LightDirection("Light Direction", Vector) = (30,30,30,0)
        _ShadowStrength("Shadow Strength", Float) = 0.01
        _EffectColor("Effect Color", Color) = (1,1,1,1)
        _EffectPower("Effect Power", Range(0, 10)) = 3
        _EffectIntensity("Effect Intensity", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags 
        {
            "Queue"="AlphaTest"
            "IgnoreProjector"="True"
            "RenderType"="TransparentCutout"
        }
        LOD 100
        Cull [_Cull]
        ZWrite On
        AlphaToMask On

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
                #ifdef LIGHTMAP_ON
                    float2 lightmapUV : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 color : COLOR;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                half fakeShadow : TEXCOORD3;
                half effect : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                #ifdef LIGHTMAP_ON
                    float2 lightmapUV : TEXCOORD6;
                #endif
                UNITY_FOG_COORDS(7)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            half _Cutoff;
            half _AlphaCoverageStrength;
            half _WindSpeed;
            half _WindAmplitude;
            half _VertexColorOffset;
            half4 _LightDirection;
            half _ShadowStrength;
            half4 _EffectColor;
            half _EffectPower;
            half _EffectIntensity;

            static const half4x4 bayerMatrix = half4x4(
                0.0h, 0.5h, 0.125h, 0.625h,
                0.75h, 0.25h, 0.875h, 0.375h,
                0.1875h, 0.6875h, 0.0625h, 0.5625h,
                0.9375h, 0.4375h, 0.8125h, 0.3125h
            );

            inline half3 calculateWind(half3 vertex, half3 normal, half2 uv)
            {
                half windTime = _Time.y * _WindSpeed;
                half sine = sin(windTime + vertex.x);
                return normal * (sine * _WindAmplitude * uv.y);
            }

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                half3 windOffset = calculateWind(v.vertex.xyz, v.normal, v.uv);
                v.vertex.xyz += windOffset;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color.rgb + _VertexColorOffset;
                o.screenPos = ComputeScreenPos(o.pos);

                #ifdef LIGHTMAP_ON
                    o.lightmapUV = v.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                half3 normalizeResult = normalize(_LightDirection.xyz);
                o.fakeShadow = max(0, dot(normalizeResult, o.worldNormal)) * _ShadowStrength;

                half3 viewDir = normalize(UnityWorldSpaceViewDir(o.worldPos));
                half NdotV = dot(o.worldNormal, viewDir);
                half fresnel = pow(1 - saturate(NdotV), _EffectPower);
                half specular = pow(max(0, dot(o.worldNormal, normalize(viewDir + normalizeResult))), _EffectPower);
                o.effect = (fresnel + specular + (1 - saturate(NdotV))) * _EffectIntensity;

                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 texCol = tex2D(_MainTex, i.uv);
                
                half processedAlpha = pow(texCol.a * _Color.a, _AlphaCoverageStrength);
                half alpha = (processedAlpha - _Cutoff) / max(fwidth(processedAlpha), 0.0001) + 0.5;

                #if defined(LOD_FADE_CROSSFADE)
                    half2 screenPos = i.screenPos.xy / i.screenPos.w * _ScreenParams.xy * 0.5h;
                    uint2 ditherCoord = uint2(fmod(screenPos, 4));
                    half dither = bayerMatrix[ditherCoord.x][ditherCoord.y];
                    half fadeValue = unity_LODFade.x > 0 ?
                        unity_LODFade.x - dither :
                        unity_LODFade.x + dither;
                    
                    alpha *= saturate(fadeValue + 1);
                    clip(fadeValue);
                #endif

                clip(alpha - 0.5);

                half4 col;
                col.rgb = texCol.rgb * _Color.rgb * i.color;

                #ifdef LIGHTMAP_ON
                    fixed4 lm = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV);
                    col.rgb *= DecodeLightmap(lm);
                #else
                    col.rgb *= _LightColor0.rgb;
                #endif

                col.rgb *= 1 - i.fakeShadow;
                col.rgb = lerp(col.rgb, _EffectColor.rgb, i.effect);
                col.a = alpha;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }

        // Shadow casting support
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    Fallback "Transparent/Cutout/VertexLit"
}