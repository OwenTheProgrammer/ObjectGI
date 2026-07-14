#ifndef OGI_INCLUDED
#define OGI_INCLUDED
#include "UnityCG.cginc"

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

struct inputSig_default
{
    float4 vertex : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

float LinearEyeDepthVR(float2 screenPos, float z)
{
    screenPos = screenPos * 2 - 1;

#ifdef UNITY_REVERSED_Z
    z = 1 - 2 * z;
#else
    z = z * 2 - 1;
#endif //UNITY_REVERSED_Z

    // NDC -> MV
    float4 clip = mul(unity_CameraInvProjection, float4(screenPos, z, 1));
    // Apply perspective division to the homogeneous system
    return -clip.z / clip.w;
}

float3 getModelScale()
{
    return float3(
        length(unity_ObjectToWorld._m00_m10_m20),
        length(unity_ObjectToWorld._m01_m11_m21),
        length(unity_ObjectToWorld._m02_m12_m22)
    );
}

float3 getDepthNormals(float2 screenPos)
{
    float2 ts = 1 / _ScreenParams.xy;
    float2 ndxy = float2(2, 2*_ProjectionParams.x) * ts;
    float dx = ndxy.x, dy = ndxy.y;

    float z1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2(-1,-1) * ts);
    float z2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2( 0,-1) * ts);
    float z3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2(+1,-1) * ts);
    float z4 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2(-1, 0) * ts);
    float z5 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2( 0, 0) * ts);
    float z6 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2(+1, 0) * ts);
    float z7 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2(-1,+1) * ts);
    float z8 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2( 0,+1) * ts);
    float z9 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos + float2(+1,+1) * ts);

    float rad = 0.0009;
    float sigma = 1 / (rad*rad);

    #define expw(n) float w##n = max(exp2(-pow(z##n - z5, 2) * sigma), 1e-6)
    expw(1); expw(2); expw(3);
    expw(4);          expw(6);
    expw(7); expw(8); expw(9);
    #undef expw

    float Mxx = dx * dx * (w1+w3+w4+w6+w7+w9);
    float Myy = dy * dy * (w1+w2+w3+w7+w8+w9);
    float Mxy = dx * dy * (w1-w3-w7+w9);

    float Bx = -dx * (w1*z1 - w3*z3 + w4*z4 - w6*z6 + w7*z7 - w9*z9 + z5 * (-w1+w3-w4+w6-w7+w9));
    float By = -dy * (w1*z1 + w2*z2 + w3*z3 - w7*z7 - w8*z8 - w9*z9 + z5 * (-w1-w2-w3+w7+w8+w9));

    float IdetM = 1 / (Mxx * Myy - Mxy * Mxy);
    float nrm_a = (Myy * Bx - Mxy * By) * IdetM;
    float nrm_b = (Mxx * By - Mxy * Bx) * IdetM;

    float3 nrm = normalize(float3(-nrm_a, -nrm_b, 1));

    float x0 = screenPos.x * 2 - 1;
    float y0 = (screenPos.y * 2 - 1) * _ProjectionParams.x;
    float D = -(nrm.x * x0 + nrm.y * y0 + nrm.z * z5);

    float4 lNDC = float4(nrm, D);
    float4 wsL = mul(transpose(UNITY_MATRIX_VP), lNDC);
    return normalize(wsL.xyz);
}

#endif //OGI_INCLUDED