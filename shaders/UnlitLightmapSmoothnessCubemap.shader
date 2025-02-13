Shader "Roundy/UnlitLightmapSmoothnessCubemap" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _CubemapBlend ("Reflection Intensity", Range(0,1)) = 0.5
        [NoScaleOffset] _Cubemap ("Reflection Cubemap", CUBE) = "black" {}
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
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_local _ UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON
   
            #include "UnityCG.cginc"
   
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
                // Moved reflection data after lightmap coordinates
                float3 worldNormal : TEXCOORD3;
                float3 worldViewDir : TEXCOORD4;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
   
            sampler2D _MainTex;
            float4 _MainTex_ST;
            samplerCUBE _Cubemap;
            float _Smoothness;
            float _CubemapBlend;
           
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
                
                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                
                // Reflection calculations after lightmap setup
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldViewDir = UnityWorldSpaceViewDir(worldPos);
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
   
            fixed4 frag (v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
               
                // Maintain exact original color sampling
                fixed4 col = tex2D(_MainTex, i.uv) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
               
                
                
                // Apply reflections after lightmap
                float smoothness = col.a * _Smoothness;
                float3 worldNormal = normalize(i.worldNormal);
                float3 viewDir = normalize(i.worldViewDir);
                float3 reflectionDir = reflect(-viewDir, worldNormal);
                
                float lod = (1.0 - smoothness) * 8.0;
                float3 reflection = texCUBElod(_Cubemap, float4(reflectionDir, lod)).rgb;
                col.rgb = lerp(col.rgb, reflection, smoothness * _CubemapBlend);
                #ifdef LIGHTMAP_ON
                // Apply lightmap before reflections
                half3 bakedColorTex = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1));
                col.rgb *= bakedColorTex;
                #endif
   
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    FallBack "Unlit/Texture"
}