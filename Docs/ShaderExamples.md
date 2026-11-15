# 셰이더 예시 장면 설명

씬 `Assets/00. Scenes/Study Shader.unity` 의 `Shader Root` 아래 예시 3개를 설명한다.
화면에는 조작 안내만 표시하고, 각 셰이더가 하는 일은 이 문서에 둔다.

## 조작

| 입력 | 동작 |
| --- | --- |
| Space | 다음 장면 (블랙홀 → 모래 → 얼음 소행성대 → 처음) |
| W / A / S / D | 카메라 앞 / 왼쪽 / 뒤 / 오른쪽 이동 |
| Q / E | 카메라 아래 / 위 이동 |
| 마우스 우클릭 누른 채 이동 | 시점 회전 |

- 장면 전환: `Assets/00. Scripts/ShaderExampleSwitcher.cs` (페이드 후 예시 루트 SetActive 교체)
- 자유 카메라: `Assets/00. Scripts/FreeFlyCamera.cs` (각 예시 전용 카메라에 붙어 있음. 장면이 다시 켜지면 처음 자리로 돌아감)

## 1. Black Hole Lens

- 셰이더: `Assets/02. BlackHoleLens/BlackHoleLens.shader`
- 설명: 화면 텍스처(`_CameraOpaqueTexture`)의 UV를 비틀어 뒤 배경을 원형으로 굴절한다.
- 장면: 체커 벽·바닥, 빨강/파랑 기둥, 노란 큐브를 배경으로 두어 굴절이 잘 보이게 했다. 블랙홀 구는 움직이지 않는다. 카메라를 움직여 굴절 위치 변화를 본다.

## 2. Sand Curtain

- 셰이더: `Assets/03. SandCurtain/SandCurtain.shader`
- 설명: 세로로 흐르는 노이즈 알갱이 + 프레넬로 외곽을 어둡고 성기게 만든다 (알파 블렌드 틈).
- 장면: 휘어진 모래 행성 지표에서 올려다본 우주. 별 하늘, 작은 위성, 위쪽 출발 행성에서 아래로 쏟아지는 높이 40 m 모래 기둥. 기둥 밑에는 모래 더미가 쌓여 있다.

## 3. Ice Asteroid Field

- 셰이더: `Assets/04. IceAsteroidField/IceAsteroidField.shader`
- 설명: fBm 얼음 안개가 일렁이고, Point Light 태양 방향으로 밝아지며 HDR 반짝임을 낸다.
- 장면: 위에서 비스듬히 본 항성계. 가운데 태양(Point Light + 발광 구)은 고정이다. 얼음 안개 원반과 소행성들(`Asteroid Belt`)이 태양을 중심으로 돌고, 행성 3개가 궤도선을 따라 공전한다 (`Assets/00. Scripts/OrbitAroundSun.cs`). 소행성대 반지름은 가장 바깥 궤도의 약 0.67배로, 항성계 원반 넓이의 약 45%다.
- 참고: 안개 무늬는 월드 xz 좌표로 계산하므로, 안개 원반이 돌아도 무늬 자체는 제자리에 남는다. 회전은 소행성 배치로 보인다.
