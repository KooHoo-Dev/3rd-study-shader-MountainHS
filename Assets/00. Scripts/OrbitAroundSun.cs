using UnityEngine;

/// <summary>
/// 붙은 오브젝트를 고정된 태양 둘레로 수평(월드 y축) 공전시킨다. 태양은 움직이지 않는다.
/// 행성에 붙이면 궤도를 따라 돌고, 소행성대 루트처럼 태양 위치에 놓인 오브젝트에 붙이면 그 자리에서 통째로 돈다.
/// 얼음 안개 셰이더는 태양(Point Light) 위치를 읽으므로, 태양이 고정이면 밝은 쪽은 늘 태양 쪽에 남는다.
/// </summary>
public class OrbitAroundSun : MonoBehaviour
{
    [Header("공전")]
    [Tooltip("공전 중심이 되는 태양. 이 스크립트는 태양을 움직이지 않는다.")]
    [SerializeField] private Transform sun;
    [Tooltip("한 바퀴 도는 데 걸리는 시간 (초). 위에서 볼 때 양수 = 시계 방향, 음수 = 반시계 방향.")]
    [SerializeField] private float periodSeconds = 30f;

    /// <summary>
    /// 이번 프레임 경과 시간만큼 태양을 지나는 세로축 둘레로 돌린다.
    /// 위치와 함께 자신의 방향도 돌아서, 소행성대는 무늬 배치가 통째로 회전한다.
    /// </summary>
    private void Update()
    {
        float degreesThisFrame = 360f * Time.deltaTime / periodSeconds;
        transform.RotateAround(sun.position, Vector3.up, degreesThisFrame);
    }
}
