Shader "OwenTheProgrammer/OGI/SpotLight"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _TexScale("Texture Scale", Float) = 1
        [IntRange] _MipLevel("Mipmap Level", Range(0, 10)) = 4
        [HDR] _Color("Color", Color) = (1,1,1,1)
        _Angle("Aperture Angle", Range(1, 179)) = 90

        [Toggle(USE_CORRECT_FALLOFF)] _UseCorrectFalloff("Use Correct Falloff", Int) = 0
        _Blend("Soft Edge", Range(0, 1)) = 0

        [Toggle(MASK_TEXTURE)] _UseMaskTexture("Mask Texture", Int) = 0

        [Toggle(COMPUTE_DEPTH_NORMAL)] _ComputeDepthNormal("Compute depth normals", Int) = 0

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend", Int) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Overlay+41"
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
            Name "ObjectGI/Spotlight"
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma shader_feature_local USE_CORRECT_FALLOFF
            #pragma shader_feature_local MASK_TEXTURE
            #pragma shader_feature_local COMPUTE_DEPTH_NORMAL
            #include "UnityCG.cginc"
            #include "OGI.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _TexScale;
            float _MipLevel;
            half4 _Color;
            float _Angle;
            half _Blend;

            struct v2f
            {
                float4 vertex : SV_POSITION;
                half2 screenPos : TEXCOORD0;
                float3 ws_viewRay : TEXCOORD1;
                nointerpolation float3 modelScale : NORMAL;

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
                o.modelScale = getModelScale();

                return o;
            }

            [earlydepthstencil]
            float4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float fovSlope = tan(radians(_Angle * 0.5));
                float3 pivotPos = unity_ObjectToWorld._m03_m13_m23;
                float4x4 minv = unity_WorldToObject;
                minv[0] *= i.modelScale.x;
                minv[1] *= i.modelScale.y;
                minv[2] *= i.modelScale.z;


                float2 screenPos = i.screenPos.xy / i.vertex.w;
                float3 rayDir = normalize(i.ws_viewRay);

                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos);
                depth = LinearEyeDepthVR(screenPos, depth) * length(i.ws_viewRay) / i.vertex.w;

                float3 ws_scenePos = _WorldSpaceCameraPos + rayDir * depth;
                float3 os_scenePos = mul(minv, float4(ws_scenePos, 1));
                float3 ws_objectPos = ws_scenePos - pivotPos;

                if(os_scenePos.z < 0) return 0;

                float ddz = fovSlope * os_scenePos.z;

                float centerDist = length(os_scenePos.xy) / ddz;

                // Smooth Edge Blending
                float B = _Blend + 0.001;
                float atten = saturate((B-1+centerDist)/B);
                atten = pow(atten*atten-1, 2);

                float distSqr = dot(ws_objectPos, ws_objectPos);

            #ifdef USE_CORRECT_FALLOFF
                float intensity = atten / (saturate(distSqr + 1) * ddz);
            #else
                float intensity = atten / saturate(distSqr + 1);
            #endif //USE_CORRECT_FALLOFF

                float NdotL = 1;

                #ifdef COMPUTE_DEPTH_NORMAL
                float3 normal = getDepthNormals(screenPos);
                NdotL = saturate(dot(normal, normalize(-ws_objectPos)));
                #endif //COMPUTE_DEPTH_NORMAL

                intensity *= NdotL;

                float2 uv = os_scenePos.xy / ddz;
                uv = uv * (0.5 + _TexScale) + 0.5;

            #ifdef MASK_TEXTURE
                intensity *= all(saturate(uv) == uv);
            #endif //MASK_TEXTURE

                float4 clr = tex2Dlod(_MainTex, float4(uv, 0, _MipLevel));
                clr.rgb *= intensity;

                return clr * _Color;
            }

            ENDCG
        }
    }
}