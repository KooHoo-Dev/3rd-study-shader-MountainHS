# 3rd-unity-6-templete

> 과제 안내: [작업지시서 — 나만의 셰이더 제작](ASSIGNMENT.md)

## 내가 만든 셰이더 3개

세 셰이더 모두 **URP**용 HLSL 셰이더다. 정점 셰이더는 표준 변환만 하고, 효과는 프래그먼트 셰이더에서 만든다.

### 1. 블랙홀 렌즈 (`Assets/02. BlackHoleLens/BlackHoleLens.shader`)
구 뒤 배경이 중심 주위로 소용돌이처럼 휘고, 가운데는 검은 핵이 된다.
- **파이프라인**: URP가 불투명 물체를 다 그린 뒤 찍은 화면 사진(`_CameraOpaqueTexture`)을 Transparent 큐에서 다시 읽는다. `Blend Off`라 비튼 배경으로 그대로 덮어쓴다.
- **좌표 변환**: 오브젝트 → 클립 → 화면 UV. vert에서 구 원점을 화면 UV(`centerUV`)로 바꾸고, frag에서 `픽셀 화면 UV - centerUV`로 중심 기준 방향을 얻는다.
- **갤러리 조합**: 씬 컬러 굴절 유리(화면 사진 읽기) + 프레넬 림 빛(`dot(N, V)` 마스크) + 충격파 왜곡(중심 기준 UV 이동, 화면비 보정).
- **새로 추가**: UV를 미는 대신 `sincos`로 **회전**시켜 소용돌이를 만든다. `dot(N, V)`로 가운데를 검게 덮고, 외곽선에서는 비틂을 0으로 해 이음새를 없앤다.
- **전제**: URP Asset에서 Opaque Texture가 켜져 있어야 한다.

### 2. 쏟아지는 모래 커튼 (`Assets/03. SandCurtain/SandCurtain.shader`)
원통 표면에 세로로 늘어난 모래알이 계속 흘러내린다. 가운데는 밝고 빽빽하며, 외곽은 어둡고 성기다.
- **파이프라인**: Transparent 큐, `Blend SrcAlpha OneMinusSrcAlpha`. 같은 코드를 원통 안쪽(`Cull Front`) → 바깥(`Cull Back`) 2패스로 그려 겹침 순서를 고정한다.
- **좌표 변환**: 무늬는 메시 UV(u = 둘레, v = 세로)에 시간을 더해 아래로 흘린다. 외곽 판정용 법선·시선은 월드 공간에서 계산한다.
- **갤러리 조합**: 노이즈 불꽃·스크롤 왜곡 에너지(노이즈 2층 흘리기) + 타일 스크롤 패럴랙스(층마다 크기·속도를 달리해 깊이감) + 프레넬 림 빛(`pow(1 - N·V)`) + 껍데기 외곽선(`Cull Front` 2패스).
- **새로 추가**: 노이즈를 `smoothstep` 임계값으로 깎아 알갱이를 만든다. 외곽일수록 임계값을 올려 틈을 늘린다. 둘레 이음매는 `round` 배율로, 오래 켰을 때 끊김은 `frac` 시간으로 막는다.

### 3. 얼음 소행성 구역 (`Assets/04. IceAsteroidField/IceAsteroidField.shader`)
바닥에 눕힌 Quad 한 장에 얼음 가루 안개가 천천히 일렁인다. 태양(Point Light) 쪽이 빛나고 작은 점이 반짝인다.
- **파이프라인**: Transparent 큐, `Blend One OneMinusSrcAlpha`(알파를 색에 미리 곱한 premultiplied). URP 추가 광원 루프로 Point Light를 읽고, Forward+와 Forward 키워드를 모두 넣었다.
- **좌표 변환**: 오브젝트 → 월드 → 클립. 노이즈는 월드 xz 좌표로 계산해 무늬가 세상에 고정된다. UV는 원형 가장자리 마스크에만 쓴다.
- **갤러리 조합**: 물결 수면(높이의 기울기로 법선 만들기) + 스크롤 왜곡 에너지(가장자리 0 마스크, HDR 발광) + 인테리어 매핑(칸 번호 해시) + 램프 툰 조명(`dot(N, L)` 확산).
- **새로 추가**: 해시 → 값 노이즈 → fBm 4옥타브로 텍스처 없는 안개를 만든다. 도메인 워프(노이즈로 좌표 자체를 비틂)로 모양이 바뀌며 일렁인다. 갤러리는 주 광원만 받지만, 여기서는 추가 광원 루프를 직접 돌려 점광원을 받는다.

## 셰이더볼 사용법

셰이더 테스트용 씬과 셰이더볼이 준비되어 있습니다.

| 경로 | 설명 |
| --- | --- |
| `Assets/00. Scenes/Study Shader.unity` | 셰이더볼 3개가 배치된 테스트 씬 |
| `Assets/01. ShaderBall/ShaderBall.prefab` | 셰이더볼 프리팹 |
| `Assets/01. ShaderBall/Materials/ShaderBall_Surface.mat` | 볼 표면에 쓰이는 기본 머티리얼 (흰색 URP Lit) |
| `Assets/01. ShaderBall/Materials/ShaderBall_Base.mat` | 받침대 · 링 · 로고용 머티리얼 (수정하지 않아도 됨) |

### 내 셰이더 적용하기

1. `Study Shader` 씬을 엽니다.
2. 셰이더를 만들고, 그 셰이더로 머티리얼을 만듭니다.
3. Hierarchy에서 `ShaderBalls > ShaderBall_1`(또는 `_2`, `_3`)을 펼칩니다.
4. 표면 파트 4개에 만든 머티리얼을 드래그해서 넣습니다.
   - `Ball/Ball_Part` (구 본체)
   - `Ball/Front_Part`, `Ball/Back_Part_1`, `Ball/Back_Part_2` (앞뒤 패널)
5. 볼 3개에 서로 다른 머티리얼을 넣으면 셰이더끼리 나란히 비교할 수 있습니다.

> 씬에 있는 볼만 바꾸면 프리팹 원본은 그대로 남습니다. 프리팹이나 `ShaderBall_Surface.mat`을 직접 수정하면 모든 볼이 함께 바뀌니 주의하세요.
