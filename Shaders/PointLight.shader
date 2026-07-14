Shader "OwenTheProgrammer/OGI/PointLight"
{
    Properties
    {
        [HDR] _Color("Light Color", Color) = (1,1,1,1)
        _Falloff("Light Falloff", Range(1, 32)) = 1.0
        _Bias("Range Bias", Range(0.01, 10)) = 1
        [Space(5)]
        [Toggle(COMPUTE_DEPTH_NORMAL)] _ComputeDepthNormal("Compute depth normals", Int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend", Int) = 2
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend", Int) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Overlay+40"
            "ForceNoShadowCasting"="True"
            "DisableBatching"="True"
        }

        Cull Front
        ZWrite Off
        ZTest Greater
        Blend [_SrcBlend] [_DstBlend]
        ZClip False

        Pass
        {
            Name "ObjectGI/PointLight"
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma shader_feature_local COMPUTE_DEPTH_NORMAL

            #include "UnityCG.cginc"
            #include "OGI.cginc"

            half4 _Color;
            float _Falloff;
            float _Bias;

            struct v2f
            {
                float4 vertex : SV_POSITION;
                half2 screenPos : TEXCOORD0;
                float3 ws_viewRay : TEXCOORD1;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(inputSig_default i)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(i.vertex);
                o.screenPos = ComputeScreenPos(o.vertex).xy;
                o.ws_viewRay = mul(unity_ObjectToWorld, i.vertex) - _WorldSpaceCameraPos;

                return o;
            }

            [earlydepthstencil]
            half4 frag(v2f i) : SV_Target
            {
                // UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 screenPos = i.screenPos.xy / i.vertex.w;
                float3 rayDir = normalize(i.ws_viewRay);

                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos);
                depth = LinearEyeDepthVR(screenPos, depth) * length(i.ws_viewRay) / i.vertex.w;

                float3 ws_scenePos = _WorldSpaceCameraPos + rayDir * depth;
                float3 pivotPos = unity_ObjectToWorld._m03_m13_m23;
                float3 localPos = ws_scenePos - pivotPos;

                float NdotL = 1;

                #ifdef COMPUTE_DEPTH_NORMAL
                float3 normal = getDepthNormals(screenPos);
                NdotL = saturate(dot(normal, normalize(-localPos)));
                #endif //COMPUTE_DEPTH_NORMAL

                float distSqr = dot(localPos, localPos);
                float luma = NdotL / (distSqr * _Falloff + _Bias);

                return float4(luma * _Color.rgb, luma);
            }

            ENDCG
        }
    }
}