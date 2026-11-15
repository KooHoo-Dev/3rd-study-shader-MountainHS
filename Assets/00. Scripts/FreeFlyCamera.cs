using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;

/// <summary>
/// 예시 장면 카메라를 키보드·마우스로 자유롭게 움직인다.
/// WASD = 앞뒤좌우, Q/E = 아래/위, 마우스 우클릭을 누른 채 끌면 시점 회전.
/// 예시가 다시 켜질 때마다(ShaderExampleSwitcher 가 루트를 켤 때) 씬에 놓인 처음 자리로 돌아간다.
/// </summary>
public class FreeFlyCamera : MonoBehaviour
{
    [Header("이동")]
    [Tooltip("이동 속도 (m/초). 장면 크기에 맞춰 카메라마다 다르게 둔다.")]
    [SerializeField] private float moveSpeedMetersPerSecond = 4f;

    [Header("회전")]
    [Tooltip("마우스가 1픽셀 움직일 때 도는 각도 (도)")]
    [SerializeField] private float lookDegreesPerPixel = 0.15f;
    [Tooltip("위아래로 고개를 들 수 있는 최대 각도 (도)")]
    [SerializeField] private float maxPitchDegrees = 89f;

    // ── 처음 자리 (씬에 놓인 값) ──
    private Vector3 startLocalPosition;
    private Quaternion startLocalRotation;

    // ── 현재 시점 각도 (도) ──
    private float yawDegrees;
    private float pitchDegrees;

    /// <summary>
    /// 씬에 놓인 위치·방향을 처음 자리로 기억한다.
    /// </summary>
    private void Awake()
    {
        startLocalPosition = transform.localPosition;
        startLocalRotation = transform.localRotation;
    }

    /// <summary>
    /// 예시가 켜질 때마다 처음 자리로 돌아간다.
    /// </summary>
    private void OnEnable()
    {
        ReturnToStartPose();
    }

    /// <summary>
    /// 우클릭 시점 회전을 먼저 반영하고, 바뀐 방향 기준으로 키보드 이동을 한다.
    /// </summary>
    private void Update()
    {
        RotateWhileRightMouseHeld();
        MoveByKeyboard();
    }

    /// <summary>
    /// 위치·방향을 처음 자리로 되돌리고, 그 방향에서 회전 각도를 다시 읽는다.
    /// </summary>
    private void ReturnToStartPose()
    {
        transform.localPosition = startLocalPosition;
        transform.localRotation = startLocalRotation;

        Vector3 startEuler = startLocalRotation.eulerAngles;
        yawDegrees = startEuler.y;
        pitchDegrees = Mathf.DeltaAngle(0f, startEuler.x);
    }

    /// <summary>
    /// 마우스 우클릭을 누르고 있는 동안 이번 프레임 마우스 이동량만큼 좌우(yaw)·상하(pitch)로 돌린다.
    /// 상하는 maxPitchDegrees 로 막아 화면이 뒤집히지 않게 한다.
    /// </summary>
    private void RotateWhileRightMouseHeld()
    {
        Mouse mouse = Mouse.current;
        if (mouse.rightButton.isPressed == false)
        {
            return;
        }

        Vector2 mouseDeltaPixels = mouse.delta.ReadValue();
        yawDegrees += mouseDeltaPixels.x * lookDegreesPerPixel;
        pitchDegrees -= mouseDeltaPixels.y * lookDegreesPerPixel;
        pitchDegrees = Mathf.Clamp(pitchDegrees, -maxPitchDegrees, maxPitchDegrees);
        transform.localRotation = Quaternion.Euler(pitchDegrees, yawDegrees, 0f);
    }

    /// <summary>
    /// WASD 는 카메라가 보는 방향 기준 앞뒤좌우, Q/E 는 월드 위아래로 움직인다.
    /// </summary>
    private void MoveByKeyboard()
    {
        Keyboard keyboard = Keyboard.current;
        float forwardInput = KeyAxis(keyboard.wKey, keyboard.sKey);
        float rightInput = KeyAxis(keyboard.dKey, keyboard.aKey);
        float upInput = KeyAxis(keyboard.eKey, keyboard.qKey);

        Vector3 moveDirection = transform.forward * forwardInput + transform.right * rightInput + Vector3.up * upInput;
        transform.position += moveDirection * moveSpeedMetersPerSecond * Time.deltaTime;
    }

    /// <summary>
    /// 반대 방향 키 두 개를 -1 ~ 1 한 축 값으로 바꾼다.
    /// </summary>
    /// <param name="positiveKey">누르면 +1 이 되는 키</param>
    /// <param name="negativeKey">누르면 -1 이 되는 키</param>
    /// <returns>positive 만 눌림 = 1, negative 만 눌림 = -1, 둘 다 또는 안 눌림 = 0.</returns>
    private float KeyAxis(KeyControl positiveKey, KeyControl negativeKey)
    {
        float axisValue = 0f;
        if (positiveKey.isPressed)
        {
            axisValue += 1f;
        }

        if (negativeKey.isPressed)
        {
            axisValue -= 1f;
        }

        return axisValue;
    }
}
