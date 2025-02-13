Shader "Roundy/Vegetation/BarkFakeShadowCrossFade" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _ShadowColor ("Shadow Color", Color) = (0,0,0,1)
        _ShadowDirection ("Shadow Direction", Vector) = (1,-1,0,0)
        _ShadowStepMin ("Shadow Step Min", Range(0,1)) = 0.2
        _ShadowStepMax ("Shadow Step Max", Range(0,1)) = 0.4
        _ShadowStrength ("Shadow Strength", Range(0,1)) = 0.5
    }
    SubShader {
        Tags {"RenderType"="Opaque"}
        LOD 100
       
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile LIGHTMAP_OFF LIGHTMAP_ON
            #pragma multi_compile_local UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON
            #pragma multi_compile LOD_FADE_CROSSFADE
   
            #include "UnityCG.cginc"
            static const float4x4 bayerMatrix = float4x4(
                0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
                12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
                3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
                15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
            );
   
            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
   
            struct v2f {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD2;
                #endif
                float4 screenPos : TEXCOORD3;
                float shadowFactor : TEXCOORD4;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
   
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _ShadowColor;
            float4 _ShadowDirection;
            float _ShadowStepMin;
            float _ShadowStepMax;
            float _ShadowStrength;
           
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)
   
            v2f vert (appdata v) {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.vertex);
                
                // Calculate shadow factor based on normal and shadow direction
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 normalizedDirection = normalize(_ShadowDirection.xyz);
                float NdotL = dot(worldNormal, normalizedDirection);
                o.shadowFactor = smoothstep(_ShadowStepMin, _ShadowStepMax, NdotL * 0.5 + 0.5);
                
                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
   
            fixed4 frag (v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
                #if defined(LOD_FADE_CROSSFADE)
                float2 screenPos = i.screenPos.xy / i.screenPos.w * _ScreenParams.xy * 0.5;
                uint2 ditherCoord = uint2(fmod(screenPos, 4));
                float dither = bayerMatrix[ditherCoord.x][ditherCoord.y];
                float fadeValue = unity_LODFade.x > 0 ?
                    unity_LODFade.x - dither :
                    unity_LODFade.x + dither;
                clip(fadeValue);
                #endif
               
                // Sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
               
                #ifdef LIGHTMAP_ON
                // Sample the lightmap
                half3 bakedColorTex = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1));
                col.rgb *= bakedColorTex;
                #endif
                
                // Apply shadow with strength control
                fixed3 shadowColor = lerp(col.rgb, _ShadowColor.rgb, _ShadowStrength);
                col.rgb = lerp(shadowColor, col.rgb, i.shadowFactor);
   
                // Apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
               
                return col;
            }
            ENDCG
        }
    }
}
