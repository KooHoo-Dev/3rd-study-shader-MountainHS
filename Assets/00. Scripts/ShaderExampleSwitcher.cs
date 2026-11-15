using System.Collections;
using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>
/// Space 를 누를 때마다 셰이더 예시 장면을 다음 것으로 넘긴다. (마우스는 FreeFlyCamera 시점 회전에 쓴다.)
/// 각 예시는 루트 오브젝트 하나로 묶여 있고, 페이드 아웃 → 루트 활성 교체 → 페이드 인 순서로 전환한다.
/// 루트의 위치는 건드리지 않고 SetActive 만 바꾼다.
/// </summary>
public class ShaderExampleSwitcher : MonoBehaviour
{
    [Header("예시 장면")]
    [Tooltip("전환 순서대로 넣은 예시 루트. 마지막 다음은 처음으로 돌아간다.")]
    [SerializeField] private GameObject[] exampleRoots;

    [Header("페이드")]
    [Tooltip("전체 화면을 덮는 검은 이미지의 CanvasGroup. alpha 0 = 투명, 1 = 완전히 검정.")]
    [SerializeField] private CanvasGroup fadeCanvasGroup;
    [Tooltip("페이드 아웃·인 각각 걸리는 시간 (초)")]
    [SerializeField] private float fadeDurationSeconds = 0.4f;

    // ── 전환 상태 ──
    private int currentIndex;
    private bool isSwitching;

    /// <summary>
    /// 첫 예시만 켜고 화면을 투명하게 시작한다.
    /// </summary>
    private void Start()
    {
        ShowOnly(0);
        fadeCanvasGroup.alpha = 0f;
    }

    /// <summary>
    /// 전환 중이 아니면 입력을 확인하고 다음 예시로 전환을 시작한다.
    /// </summary>
    private void Update()
    {
        if (isSwitching)
        {
            return;
        }

        if (WasNextPressed())
        {
            StartCoroutine(SwitchToNextExample());
        }
    }

    /// <summary>
    /// 이번 프레임에 Space 가 눌렸는지 확인한다.
    /// </summary>
    /// <returns>Space 가 눌렸으면 true.</returns>
    private bool WasNextPressed()
    {
        return Keyboard.current.spaceKey.wasPressedThisFrame;
    }

    /// <summary>
    /// 화면을 검게 덮은 뒤 현재 예시를 끄고 다음 예시를 켜고, 다시 화면을 밝힌다.
    /// 전환이 끝날 때까지 입력을 막는다.
    /// </summary>
    private IEnumerator SwitchToNextExample()
    {
        isSwitching = true;

        yield return Fade(0f, 1f);

        exampleRoots[currentIndex].SetActive(false);
        currentIndex = (currentIndex + 1) % exampleRoots.Length;
        exampleRoots[currentIndex].SetActive(true);

        yield return Fade(1f, 0f);

        isSwitching = false;
    }

    /// <summary>
    /// 페이드 이미지의 알파를 fadeDurationSeconds 동안 선형으로 바꾼다.
    /// Time.timeScale 영향을 받지 않도록 unscaled 시간을 쓴다.
    /// </summary>
    /// <param name="fromAlpha">시작 알파 (0 = 투명, 1 = 검정)</param>
    /// <param name="toAlpha">끝 알파 (0 = 투명, 1 = 검정)</param>
    private IEnumerator Fade(float fromAlpha, float toAlpha)
    {
        float elapsedSeconds = 0f;
        while (elapsedSeconds < fadeDurationSeconds)
        {
            elapsedSeconds += Time.unscaledDeltaTime;
            fadeCanvasGroup.alpha = Mathf.Lerp(fromAlpha, toAlpha, elapsedSeconds / fadeDurationSeconds);
            yield return null;
        }

        fadeCanvasGroup.alpha = toAlpha;
    }

    /// <summary>
    /// 지정한 예시 루트만 켜고 나머지는 모두 끈다.
    /// </summary>
    /// <param name="index">켤 예시의 exampleRoots 인덱스</param>
    private void ShowOnly(int index)
    {
        currentIndex = index;
        for (int i = 0; i < exampleRoots.Length; i++)
        {
            exampleRoots[i].SetActive(i == index);
        }
    }
}
