# Claude Code Effort Level 설정

## 개요

Claude Code의 **Effort Level**은 Claude가 작업을 수행할 때 얼마나 깊이 사고하는지를 결정한다.

## 설정 값

| 값 | 설명 |
|---|---|
| `low` | 빠른 응답, 간단한 작업에 적합 |
| `medium` | 속도와 품질 균형 (Anthropic 권장) |
| `high` | 깊은 사고, 복잡한 작업에 적합 |
| `max` | 최대 사고, 토큰 제한 없음 (Opus 4.6 전용, 세션 종료 시 리셋) |

## 설정 파일 위치

```
~/.claude/settings.json
```

### 예시 (high)

```json
{
  "effortLevel": "high"
}
```

## 설정 방법

### 1. CLI 메뉴에서 설정

```bash
claude
# 실행 후 /config 입력 → Effort Level 선택
```

### 2. 스크립트로 설정

```bash
./1410_claude-effort-level.sh
```

### 3. 직접 편집

```bash
vi ~/.claude/settings.json
```

## Effort Level vs Model 변경 — 차이점

| | Effort Level | Model 변경 |
|---|---|---|
| **설정** | `effortLevel`: low / medium / high | `model`: opus / sonnet / haiku |
| **바꾸는 것** | 같은 모델의 **사고 깊이** | **모델 자체**를 교체 |
| **비유** | 같은 사람이 얼마나 오래 고민하느냐 | 아예 다른 사람에게 맡기느냐 |
| **설정 방법** | `/config` 또는 `settings.json` | `/model` 또는 `claude --model` |

예: Effort를 `high`로 설정해도 모델은 Opus 4.6 그대로이다. `medium`으로 바꾸면 같은 Opus 4.6이 더 빠르지만 얕게 사고한다.

## 토큰 사용량

Effort Level은 토큰 소비에 **직접적으로** 영향을 준다.

| Effort | 토큰 소비 | 특징 |
|---|---|---|
| `low` | 가장 적음 | thinking 토큰 최소화, 대량/단순 작업에 적합 |
| `medium` | 보통 | 속도와 품질 균형, Anthropic 공식 권장 |
| `high` | 많음 (low 대비 ~10배 이상) | thinking 토큰 대폭 증가, 복잡한 작업에 적합 |

### 영향 범위

- **thinking 토큰**: high일수록 내부 사고 과정이 길어져 토큰 대폭 증가
- **텍스트/도구 호출 토큰**: effort가 높으면 응답도 더 상세해질 수 있음
- **TPM (분당 토큰 한도)**: 요청당 토큰이 늘어나므로 rate limit에 더 빨리 도달
- **비용**: Anthropic 공식 문서에서 비용 절감 전략으로 effort 낮추기를 명시

### 비용 절감 팁

```bash
/effort medium    # 대부분의 작업에 충분
/effort low       # 단순 작업, 빠른 응답 필요 시
```

필요할 때만 `/effort high` 또는 프롬프트에 "ultrathink"를 사용하면 요청 단위로 깊은 사고를 트리거할 수 있다.

## high vs ultrathink vs max

| | `/effort high` | `ultrathink` (키워드) | `/effort max` |
|---|---|---|---|
| **정체** | 전역 설정 | 프롬프트에 쓰는 키워드 | 전역 설정 |
| **적용 범위** | 세션 전체 (모든 턴) | **해당 턴 1회만** | 세션 전체 |
| **사고 깊이** | 깊음 | 깊음 (= high와 동일) | **최대** (제한 없음) |
| **속도** | 보통~느림 | 보통~느림 | 가장 느림 |
| **토큰 소비** | 많음 | 많음 (= high) | 가장 많음 |
| **지원 모델** | 전체 | Opus 4.6 / Sonnet 4.6 | **Opus 4.6만** |
| **설정 유지** | `settings.json`에 저장 | 저장 안 됨 (1회성) | 세션 종료 시 리셋 |

### 사용 예시

```bash
# 전역 설정 — 세션 내 모든 요청에 적용
/effort high
/effort max

# 1회성 — 평소 medium으로 쓰다가 복잡한 질문에만 사용
"ultrathink 이 코드의 메모리 누수 원인을 분석해줘"
```

### 권장 전략

1. 평소에는 `/effort medium` 으로 사용 (속도 + 비용 균형)
2. 복잡한 분석이 필요할 때 프롬프트에 `ultrathink` 키워드로 1회성 deep thinking
3. 정말 어려운 문제에는 `/effort max` (Opus 4.6 전용)

## 참고

- `settings.json` — 사용자 전역 설정 (effort level 등)
- `settings.local.json` — 로컬 전용 설정 (permissions 등, git에 커밋되지 않음)
- Effort Level은 모델을 바꾸는 것이 아니라, 같은 모델(Opus 4.6)이 사고하는 깊이를 조절하는 것이다.
