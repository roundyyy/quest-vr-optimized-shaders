Shader "Roundy/SuperCheapWater" {
    Properties {
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _WaterColor ("Water Color", Color) = (0.2,0.5,0.7,1)
        _ReflectionColor ("Reflection Color", Color) = (1,1,1,1)
        _NormalStrength ("Wave Height", Range(0,2)) = 1.0
        _WaveSpeed ("Wave Speed", Range(0,2)) = 1.0
        _ReflectionStrength ("Reflection Strength", Range(0,1)) = 0.5
    }
   
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewDir : TEXCOORD1;
            };
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float4 _WaterColor;
            float4 _ReflectionColor;
            float _NormalStrength;
            float _WaveSpeed;
            float _ReflectionStrength;
            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _NormalMap);
               
                float3 worldViewDir = normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex).xyz);
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBitangent = cross(worldNormal, worldTangent) * v.tangent.w;
               
                o.viewDir = float3(
                    dot(worldViewDir, worldTangent),
                    dot(worldViewDir, worldBitangent),
                    dot(worldViewDir, worldNormal)
                );
               
                return o;
            }
            fixed4 frag (v2f i) : SV_Target {
                // Animate UVs for wave movement
                float2 uv1 = i.uv + _Time.y * _WaveSpeed * float2(1, 0);
                float2 uv2 = i.uv + _Time.y * _WaveSpeed * float2(-0.7, 0.7);
               
                // Sample and combine normal maps
                float3 normal1 = UnpackNormal(tex2D(_NormalMap, uv1));
                float3 normal2 = UnpackNormal(tex2D(_NormalMap, uv2));
                float3 normal = normalize(float3(
                    normal1.xy + normal2.xy,
                    normal1.z * normal2.z
                ));
               
                normal.xy *= _NormalStrength;
                normal = normalize(normal);
               
                // Fake reflection based on normal direction
                float3 viewDir = normalize(i.viewDir);
                float fresnel = pow(1.0 - max(0, dot(normal, viewDir)), 2);
                float reflection = fresnel * _ReflectionStrength;
               
                // Mix water color with reflection color
                return lerp(_WaterColor, _ReflectionColor, reflection);
            }
            ENDCG
        }
    }
}