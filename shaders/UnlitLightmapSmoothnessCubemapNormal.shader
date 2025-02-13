Shader "Roundy/UnlitLightmapSmoothnessCubemapNormal" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1.0
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
                float4 tangent : TANGENT;
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
   
            struct v2f {
                float4 uv : TEXCOORD0; // xy: main texture, zw: normal map
                UNITY_FOG_COORDS(1)
                #ifdef LIGHTMAP_ON
                float2 uv1 : TEXCOORD2;
                #endif
                float3 worldPos : TEXCOORD3;
                // TBN matrix for normal mapping
                half3 tspace0 : TEXCOORD4;
                half3 tspace1 : TEXCOORD5;
                half3 tspace2 : TEXCOORD6;
                float3 worldViewDir : TEXCOORD7;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
   
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
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
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _BumpMap); // Proper normal map UV transformation
                
                #ifdef LIGHTMAP_ON
                o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldPos = worldPos;
                o.worldViewDir = UnityWorldSpaceViewDir(worldPos);

                // Calculate tangent space transformation matrix
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                float3 worldBitangent = cross(worldNormal, worldTangent) * tangentSign;
                o.tspace0 = float3(worldTangent.x, worldBitangent.x, worldNormal.x);
                o.tspace1 = float3(worldTangent.y, worldBitangent.y, worldNormal.y);
                o.tspace2 = float3(worldTangent.z, worldBitangent.z, worldNormal.z);
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
   
            fixed4 frag (v2f i) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
               
                // Sample base color
                fixed4 col = tex2D(_MainTex, i.uv.xy) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
                
                // Sample and decode normal map with proper Unity normal unpacking
                half3 tnormal = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
                tnormal.xy *= _BumpScale; // Apply normal intensity after unpacking
                tnormal.z = sqrt(1.0 - saturate(dot(tnormal.xy, tnormal.xy))); // Reconstruct Z
                
                // Transform normal from tangent to world space
                half3 worldNormal;
                worldNormal.x = dot(i.tspace0, tnormal);
                worldNormal.y = dot(i.tspace1, tnormal);
                worldNormal.z = dot(i.tspace2, tnormal);
                worldNormal = normalize(worldNormal);
                
                // Calculate reflection
                float smoothness = col.a * _Smoothness;
                float3 viewDir = normalize(i.worldViewDir);
                float3 reflectionDir = reflect(-viewDir, worldNormal);
                
                float lod = (1.0 - smoothness) * 8.0;
                float3 reflection = texCUBElod(_Cubemap, float4(reflectionDir, lod)).rgb;
                col.rgb = lerp(col.rgb, reflection, smoothness * _CubemapBlend);

                #ifdef LIGHTMAP_ON
                // Apply lightmap
                half3 bakedColorTex = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1));
                col.rgb *= bakedColorTex;
                #endif
   
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}