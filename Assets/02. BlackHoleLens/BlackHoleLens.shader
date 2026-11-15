// 블랙홀 렌즈 셰이더 (URP).
// 구(Sphere)에 끼우면 뒤 배경이 구 중심 주위로 원형으로 휘어 보이고, 가운데는 검은 원(핵)이 된다.
// 원리: URP가 불투명 물체까지 찍어 둔 화면 사진(_CameraOpaqueTexture)을 읽는 주소(화면 UV)를 비틀어 다시 찍는다.
// 전제 조건: 사용하는 URP Asset에서 Opaque Texture 가 켜져 있어야 한다. (m_RequireOpaqueTexture: 1)
// 알파 블렌딩은 쓰지 않는다. 출력 색이 이미 비튼 배경이라, 섞으면 원본 배경과 겹쳐 이중상이 생긴다.
Shader "Custom/BlackHoleLens"
{
    Properties
    {
        _HorizonSize ("검은 핵 크기 (facing 기준)", Range(0, 1)) = 0.6
        _HorizonSoftness ("핵 경계 부드러움", Range(0, 0.2)) = 0.03
        _TwistAngle ("원형 비틀림 정도 (라디안)", Range(0, 6.28)) = 3
        _PullStrength ("중심으로 빨려드는 정도", Range(0, 1)) = 0.3
        _SeamTest ("이음새 테스트용 (확인 후 삭제)", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }

        Pass
        {
            Name "BlackHoleLens"
            Tags { "LightMode"="UniversalForward" }

            Blend Off
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _HorizonSize;
                float _HorizonSoftness;
                float _TwistAngle;
                float _PullStrength;
                float _SeamTest;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 centerUV   : TEXCOORD2; // 오브젝트 원점의 화면 UV. 모든 정점이 같은 값이라 보간해도 그대로다.
            };

            // 정점 셰이더: 표준 변환 + 회전 축(오브젝트 원점의 화면 UV) 계산.
            // centerUV 는 픽셀마다 같은 값이라 frag 대신 정점마다 한 번만 계산해서 넘긴다.
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                // 오브젝트 원점을 클립 -> 화면 UV로 투영. 회전 축이 된다.
                float4 centerCS = TransformWorldToHClip(UNITY_MATRIX_M._m03_m13_m23);
                float2 centerUV = centerCS.xy / centerCS.w * 0.5 + 0.5;
                if (_ProjectionParams.x < 0) centerUV.y = 1 - centerUV.y; // 플랫폼별 상하 뒤집힘 보정 (ComputeScreenPos와 같은 방식)
                output.centerUV = centerUV;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 1. 이 픽셀의 화면 위치 (화면 사진을 읽을 주소)
                float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);

                // 2. 회전 축: 오브젝트 원점의 화면 UV (vert 에서 계산)
                float2 centerUV = input.centerUV;

                // 3. facing: 구 중심 1, 외곽선 0
                float3 N = normalize(input.normalWS);
                float3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float facing = saturate(dot(N, V));

                // 4. 마스크 2개
                float horizonMask = smoothstep(_HorizonSize - _HorizonSoftness, _HorizonSize, facing); // 1 = 검은 핵
                float lensMask = smoothstep(0, _HorizonSize, facing); // 외곽선 0 -> 핵 경계 1
                lensMask = max(lensMask, _SeamTest); // 이음새 실험용 (5단계)

                // 5. 비틀기
                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 offset = screenUV - centerUV;
                offset.x *= aspect; // 정사각 공간으로 보정
                float angle = _TwistAngle * lensMask; // 마스크만큼 회전
                float s, c;
                sincos(angle, s, c);
                offset = float2(c * offset.x - s * offset.y, s * offset.x + c * offset.y);
                offset *= (1 - _PullStrength * lensMask); // 중심 쪽으로 당김
                offset.x /= aspect; // 가로세로비 보정 되돌림
                float2 sampleUV = centerUV + offset;

                // 6. 화면 사진을 비튼 주소로 읽고, 핵 부분을 검게 합성
                float3 color = SampleSceneColor(sampleUV);
                color = lerp(color, 0, horizonMask);

                // 단계별 확인: 지금 단계 하나만 주석을 풀고 나머지는 주석 처리한다.
                // return half4(1, 1, 1, 1); // 1단계: 흰 구가 보임 (안 보임 -> Tags/LightMode/Queue)
                // return half4(facing.xxx, 1); // 2단계: 중심 흰색 -> 외곽 검정, 카메라를 돌려도 원형 (각진 무늬 -> normalize 누락 / 원 아님 -> V 오류)
                // return half4(horizonMask.xxx, 1); // 3단계: 흰 원판, _HorizonSize로 크기 변함 (원판 없음 -> smoothstep 범위 뒤집힘)
                // return half4(SampleSceneColor(screenUV), 1); // 4단계: 구가 투명처럼 안 보임 (회색·검정 -> Opaque Texture 꺼짐 / 상하 뒤집힘 -> 수동 UV 계산)
                // return half4(SampleSceneColor(sampleUV), 1); // 5단계: 뒤 물체가 중심 주위로 휨, 테두리 이음새 없음 (화면 끝 찌그러짐 -> 가로세로비 보정 누락)
                return half4(color, 1); // 6단계: 최종. 휜 고리 + 가운데 검은 원
            }
            ENDHLSL
        }
    }
}
