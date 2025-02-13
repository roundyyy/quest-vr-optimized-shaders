// Made with Amplify Shader Editor v1.9.6.3
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Roundy/FakeShadowVertex"
{
	Properties
	{
		_LightDirection("Light Direction", Vector) = (30,30,30,0)
		_ShadowStrength("Shadow Strength", Float) = 0.01
		_Color0("Color 0", Color) = (0.4716981,0.4716981,0.4716981,0)
		_MainTex("Albedo", 2D) = "white" {}
		_Max("Max", Float) = 0.6
		_Min("Min", Float) = -0.05
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+0" "IsEmissive" = "true"  }
		Cull Back
		CGPROGRAM
		#pragma target 3.0
		#pragma surface surf Unlit keepalpha noshadow noambient novertexlights nolightmap  nodynlightmap nodirlightmap nometa noforwardadd vertex:vertexDataFunc 
		struct Input
		{
			float2 uv_texcoord;
			half4 vertexToFrag28;
		};

		uniform sampler2D _MainTex;
		uniform half4 _MainTex_ST;
		uniform half4 _Color0;
		uniform half _Min;
		uniform half _Max;
		uniform half3 _LightDirection;
		uniform half _ShadowStrength;

		void vertexDataFunc( inout appdata_full v, out Input o )
		{
			UNITY_INITIALIZE_OUTPUT( Input, o );
			half3 normalizeResult2 = normalize( _LightDirection );
			half3 ase_worldNormal = UnityObjectToWorldNormal( v.normal );
			half3 normalizeResult45 = normalize( ase_worldNormal );
			half dotResult3 = dot( normalizeResult2 , normalizeResult45 );
			half smoothstepResult30 = smoothstep( _Min , _Max , dotResult3);
			half4 lerpResult8 = lerp( v.color , half4( _Color0.rgb , 0.0 ) , ( smoothstepResult30 + _ShadowStrength ));
			o.vertexToFrag28 = lerpResult8;
		}

		inline half4 LightingUnlit( SurfaceOutput s, half3 lightDir, half atten )
		{
			return half4 ( 0, 0, 0, s.Alpha );
		}

		void surf( Input i , inout SurfaceOutput o )
		{
			float2 uv_MainTex = i.uv_texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
			o.Emission = ( half4( tex2D( _MainTex, uv_MainTex ).rgb , 0.0 ) * i.vertexToFrag28 ).rgb;
			o.Alpha = 1;
		}

		ENDCG
	}
}
/*ASEBEGIN
Version=19603
Node;AmplifyShaderEditor.Vector3Node;1;-1248,-112;Inherit;False;Property;_LightDirection;Light Direction;0;0;Create;True;0;0;0;False;0;False;30,30,30;30,30,30;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.WorldNormalVector;27;-1280,112;Inherit;False;False;1;0;FLOAT3;0,0,1;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.NormalizeNode;2;-1056,-96;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.NormalizeNode;45;-1040,128;Inherit;False;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DotProductOpNode;3;-896,-96;Inherit;False;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;18;-576,256;Inherit;False;Property;_Max;Max;4;0;Create;True;0;0;0;False;0;False;0.6;0.94;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;17;-784,256;Inherit;False;Property;_Min;Min;5;0;Create;True;0;0;0;False;0;False;-0.05;-0.07;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;6;-544,384;Inherit;False;Property;_ShadowStrength;Shadow Strength;1;0;Create;True;0;0;0;False;0;False;0.01;0.01;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode;30;-432,-32;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.VertexColorNode;9;-736,-368;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;10;-512,-464;Inherit;False;Property;_Color0;Color 0;2;0;Create;True;0;0;0;False;0;False;0.4716981,0.4716981,0.4716981,0;0.4943396,0.4943396,0.4943396,0;True;True;0;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.SimpleAddOpNode;13;-304,176;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;8;-192,-112;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.VertexToFragmentNode;28;-48,16;Inherit;False;False;False;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SamplerNode;14;-256,-416;Inherit;True;Property;_MainTex;Albedo;3;0;Create;False;0;0;0;False;0;False;-1;None;dd05bca8882cec741a2e8626967e6df5;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;6;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT3;5
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;23;384,-160;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;0;448,48;Half;False;True;-1;2;;0;0;Unlit;FakeShadowVertex;False;False;False;False;True;True;True;True;True;False;True;True;False;False;False;False;False;False;False;False;False;Back;0;False;;0;False;;False;0;False;;0;False;;False;0;Opaque;0.5;True;False;0;False;Opaque;;Geometry;All;12;all;True;True;True;True;0;False;;False;0;False;;255;False;;255;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;0;False;;False;2;15;10;25;False;0.5;False;0;0;False;;0;False;;0;0;False;;0;False;;0;False;;0;False;;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;True;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;;-1;0;False;;0;0;0;False;0.1;False;;0;False;;False;16;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;16;FLOAT4;0,0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;2;0;1;0
WireConnection;45;0;27;0
WireConnection;3;0;2;0
WireConnection;3;1;45;0
WireConnection;30;0;3;0
WireConnection;30;1;17;0
WireConnection;30;2;18;0
WireConnection;13;0;30;0
WireConnection;13;1;6;0
WireConnection;8;0;9;0
WireConnection;8;1;10;5
WireConnection;8;2;13;0
WireConnection;28;0;8;0
WireConnection;23;0;14;5
WireConnection;23;1;28;0
WireConnection;0;2;23;0
ASEEND*/
//CHKSM=8F4464A296ABE1809FF979B927E89103285C3A3E