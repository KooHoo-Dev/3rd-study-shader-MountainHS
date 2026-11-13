// 쏟아지는 모래 커튼 셰이더 (URP).
// 원통 메쉬에 쓰면 모래알이 세로로 늘어난 줄로 아래로 흐른다. 가운데는 밝고 빽빽, 외곽은 어둡고 성기다.
// 원리: 타일링 노이즈를 세로로 늘려 시간에 따라 스크롤 -> smoothstep 으로 알갱이 마스크. 층 2개(앞/먼)를 다른 크기·속도로 겹친다.
//       프레넬(법선·시선)로 외곽을 어둡게 하고, 알갱이 임계값을 올려 외곽에 틈을 늘린다.
// 전제: UV.u = 둘레, UV.v = 세로인 원통(Unity 기본 Cylinder 가능). 평면 Quad 는 법선이 하나라 외곽 어둠이 안 생긴다.
// 투명 정렬: 뒷면 패스(Cull Front) -> 앞면 패스(Cull Back) 순으로 그려 앞뒷면 겹침 순서를 고정한다.
Shader "Custom/SandCurtain"
{
    Properties
    {
        [NoScaleOffset] _NoiseTex ("타일링 노이즈 (회색, 가로 이음매 없음)", 2D) = "gray" {}
        _SandColor ("밝은 모래색", Color) = (0.92, 0.78, 0.5, 1)
        _GapColor ("틈 색 (알파 포함)", Color) = (0.2, 0.1, 0.05, 0)
        _GrainScale ("알갱이 크기 (x 가로 촘촘함, y 작을수록 세로로 긴 줄)", Vector) = (20, 3, 0, 0)
        _FallSpeed ("떨어지는 속도 (UV/초)", Range(0, 5)) = 1.5
        _Density ("밀도 (클수록 틈 적음)", Range(0, 1)) = 0.6
        _GrainSoftness ("알갱이 경계 선명도", Range(0.01, 0.2)) = 0.05
        _FarLayerScale ("먼 층 배율 (클수록 작은 알갱이)", Range(1, 3)) = 1.8
        _FarLayerSpeed ("먼 층 속도 비율", Range(0.3, 1)) = 0.6
        _FarLayerDim ("먼 층 어둡기", Range(0, 1)) = 0.4
        _EdgePower ("외곽 폭 (프레넬 지수)", Range(1, 8)) = 2
        _EdgeDarken ("외곽 어둡기", Range(0, 1)) = 0.7
        _EdgeThinning ("외곽 틈 증가량", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }

        // 두 패스가 공유하는 코드. 패스마다 Cull 만 다르다.
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        CBUFFER_START(UnityPerMaterial)
            half4 _SandColor;
            half4 _GapColor;
            float4 _GrainScale;
            float _FallSpeed;
            float _Density;
            float _GrainSoftness;
            float _FarLayerScale;
            float _FarLayerSpeed;
            float _FarLayerDim;
            float _EdgePower;
            float _EdgeDarken;
            float _EdgeThinning;
        CBUFFER_END

        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS   : NORMAL;
            float2 uv         : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
            float3 positionWS : TEXCOORD1;
            float3 normalWS   : TEXCOORD2;
            float  capFlag    : TEXCOORD3; // |normalOS.y|: 1 에 가까우면 원통 뚜껑
        };

        // 정점 셰이더: 표준 변환만 한다. 정점 변형 없음.
        Varyings vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
            output.normalWS = TransformObjectToWorldNormal(input.normalOS);
            output.uv = input.uv;
            output.capFlag = abs(input.normalOS.y);
            return output;
        }

        // 노이즈 한 층을 세로로 늘려 아래로 스크롤하고, 노이즈 값 n 을 돌려준다.
        // x 는 정수 배로 반올림 -> 둘레 u=0/1 에서 노이즈 주기가 맞아 이음매가 없다.
        // 시간 오프셋은 frac -> 텍스처 주기(1)와 같아 이어지고, 오래 켜도 float 정밀도가 깨지지 않는다.
        float GrainNoise(float2 uv, float scaleX, float scaleY, float speed)
        {
            float2 p;
            p.x = uv.x * max(1.0, round(scaleX));
            p.y = uv.y * scaleY + frac(_Time.y * speed * scaleY); // 오프셋이 커질수록 무늬는 v 가 작은 쪽(아래)으로 흐른다
            return SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, p).r;
        }

        // 노이즈 n -> 알갱이 마스크(1 = 모래알). 경계 폭은 화면 변화량(fwidth)보다 좁아지지 않게 해서 멀리서 지글거림을 줄인다.
        float GrainMask(float n, float threshold)
        {
            float soft = max(_GrainSoftness, fwidth(n));
            return smoothstep(threshold - soft, threshold + soft, n);
        }

        half4 frag(Varyings input) : SV_Target
        {
            clip(0.99 - input.capFlag); // 원통 뚜껑 버림 (뚜껑 UV 는 방사형이라 무늬가 깨진다)

            // 프레넬: 가운데 facing 1, 외곽 0. 뒷면 패스에서는 법선이 시선 반대라 abs 로 보정.
            float3 N = normalize(input.normalWS);
            float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
            float facing = abs(dot(N, V));
            float edge = pow(saturate(1.0 - facing), _EdgePower); // 0 = 가운데, 1 = 외곽

            // 알갱이 임계값: 외곽일수록 올려 틈을 늘린다.
            float threshold = saturate(1.0 - _Density + edge * _EdgeThinning);

            // 앞 층 / 먼 층
            float nearN = GrainNoise(input.uv, _GrainScale.x, _GrainScale.y, _FallSpeed);
            float farN = GrainNoise(input.uv, _GrainScale.x * _FarLayerScale, _GrainScale.y * _FarLayerScale, _FallSpeed * _FarLayerSpeed);
            float nearMask = GrainMask(nearN, threshold);
            float farMask = GrainMask(farN, threshold);

            // 단계별 확인: 지금 단계 하나만 주석을 풀고 나머지는 주석 처리한다.
            // return half4(input.uv, 0, 1); // 1단계: 위 -> 아래 v 증가 방향 확인, 둘레(u) 0/1 경계에 색 이음매는 정상(UV 자체는 불연속). 노이즈 이음매와는 별개
            // return half4(nearN.xxx, 1); // 2단계: 노이즈 1층이 아래로 흐름 (위로 흐름 -> frac 안 부호 반전 / 둘레 이음매 -> 텍스처 Wrap Mode 가 Repeat 아님)
            // return half4(nearMask.xxx, 1); // 3단계: 세로로 긴 흑백 알갱이 (_GrainScale.y 작게 -> 더 길게, _Density 크게 -> 흰색 증가)
            // return half4(max(nearMask, farMask).xxx, 1); // 4단계: 작고 느린 먼 층이 겹쳐 깊이감
            // return half4(facing.xxx, 1); // 5단계: 가운데 흰색 -> 외곽 검정, 카메라를 돌려도 기둥 가장자리에 유지 (Quad 에서는 균일 -> 원통 사용)

            // 6단계: 최종. 색 + 외곽 어둡게 + 외곽 틈 증가(임계값) + 알파
            half3 nearColor = _SandColor.rgb;
            half3 farColor = _SandColor.rgb * (1.0 - _FarLayerDim);
            half3 grainColor = lerp(farColor, nearColor, nearMask); // 앞 층이 있으면 앞 층 색, 없으면 먼 층 색
            grainColor *= 1.0 - _EdgeDarken * edge;

            float grain = max(nearMask, farMask); // 어느 층이든 알갱이가 있으면 1
            half3 rgb = lerp(_GapColor.rgb, grainColor, grain);
            half alpha = lerp(_GapColor.a, 1.0, grain);
            return half4(rgb, alpha);
        }
        ENDHLSL

        // 1패스: 뒷면 (원통 안쪽 벽). 먼저 그린다.
        Pass
        {
            Name "SandBack"
            // LightMode 없음 = SRPDefaultUnlit. URP 가 UniversalForward 패스보다 먼저 그린다.

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }

        // 2패스: 앞면. 뒷면 위에 덮는다.
        Pass
        {
            Name "SandFront"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}
