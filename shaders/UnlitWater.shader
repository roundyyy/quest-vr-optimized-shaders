Shader "Roundy/UnlitWater"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScrollSpeed ("Normal Scroll Speed", Vector) = (0.1, 0.1, 0.1, 0.1)
        _NormalStrength ("Normal Strength", Range(0, 2)) = 1.0
        _DetailNormalTiling ("Detail Normal Tiling", Float) = 100.0
        [NoScaleOffset] _CubeMap ("Cube Map", CUBE) = "" {}
        _CubeMapStrength ("Cubemap Strength", Range(0, 1)) = 0.5
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100
        Cull [_Cull]
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            
            // Enable built-in fog variations
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBinormal : TEXCOORD4;
                
                // Fog coordinate
                UNITY_FOG_COORDS(5)
            };
            
            fixed4 _Color;
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float4 _NormalScrollSpeed;
            float _NormalStrength;
            float _DetailNormalTiling;
            samplerCUBE _CubeMap;
            float _CubeMapStrength;
            float _Smoothness;
            
            // Helper function to blend normals
            float3 BlendNormals(float3 n1, float3 n2)
            {
                return normalize(float3(n1.xy + n2.xy, n1.z * n2.z));
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _NormalMap);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBinormal = cross(o.worldNormal, o.worldTangent) * v.tangent.w;
                
                // Transfer fog coordinates
                UNITY_TRANSFER_FOG(o, o.vertex);

                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // Calculate scrolled UVs for all three normal layers
                float2 scrolledUV1 = i.uv + _Time.y * _NormalScrollSpeed.xy;
                float2 scrolledUV2 = i.uv - _Time.y * _NormalScrollSpeed.xy;
                float2 scrolledUV3 = i.uv * _DetailNormalTiling + _Time.y * _NormalScrollSpeed.zw;
                
                // Sample all three normal maps
                float3 tangentNormal1 = UnpackNormal(tex2D(_NormalMap, scrolledUV1));
                float3 tangentNormal2 = UnpackNormal(tex2D(_NormalMap, scrolledUV2));
                float3 tangentNormal3 = UnpackNormal(tex2D(_NormalMap, scrolledUV3));
                
                // Blend all three normal maps
                float3 blendedNormal = BlendNormals(tangentNormal1, tangentNormal2);
                blendedNormal = BlendNormals(blendedNormal, tangentNormal3);
                blendedNormal.xy *= _NormalStrength;
                blendedNormal = normalize(blendedNormal);
                
                // Transform normal from tangent to world space
                float3x3 tangentToWorld = float3x3(
                    i.worldTangent,
                    i.worldBinormal,
                    i.worldNormal
                );
                float3 worldNormal = normalize(mul(tangentToWorld, blendedNormal));
                
                // Calculate view direction and reflection vector
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 reflectionVector = reflect(-viewDir, worldNormal);
                
                // Sample cubemap with reflection vector
                float4 cubemapColor = texCUBE(_CubeMap, reflectionVector);
                
                // Blend base color with cubemap reflection
                float reflectionFactor = _CubeMapStrength * _Smoothness;
                fixed4 finalColor = lerp(_Color, cubemapColor, reflectionFactor);
                
                // Apply Unity's built-in fog
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                
                return finalColor;
            }
            ENDCG
        }
    }
}
