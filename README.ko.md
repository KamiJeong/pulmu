<p align="center">
  <img src="./assets/pulmu-joseon-forge.png" alt="조선 시대 대장간에서 풀무와 함께 작업하는 대장장이" width="100%">
</p>

# Pulmu 🔥

[English](./README.md) | [한국어](./README.ko.md)

> **명령 하나로 대장간 전체를 시작합니다.**

Pulmu는 작업에 맞춰 실행 방식을 조절하는 Codex CLI 워크플로 스킬입니다. 먼저 저장소 변경이 필요한지 판단하고, 실제 개발이 필요하면 한 명의 작성자가 구현한 뒤 검증·리뷰·로컬 커밋을 수행합니다. GitHub 환경이 준비되어 있으면 PR까지 전달할 수 있습니다.

```text
$pulmu "사용자 검색 기능을 추가하고 테스트도 작성해줘"
```

Ignite, Inspect, Shape, Hammer, Quench, Hone, Ship은 내부 단계입니다. 사용자는 `$pulmu`를 한 번 호출하면 됩니다. 메인 Codex 세션인 Orchestrator가 전체 흐름을 관리합니다.

## 사용 가이드

- [설치하고 시작하기](#빠른-시작)
- [작업 요청과 제안에 응답하기](#작업-요청하기)
- [UI 계획이 없을 때](#ui-계획이-없을-때)
- [실행 방식과 완료 결과 이해하기](#실행-깊이와-완료-결과)
- [진행 상황 확인하기](#진행-상황-표시)
- [로컬 또는 GitHub 납품 설정하기](#git과-github-납품)
- [중단이나 요구사항 변경에 대응하기](#작업이-멈추거나-요구사항이-바뀌면)
- [업데이트·제거·데모 실행하기](#설치-관리와-데모)

## 빠른 시작

필요한 환경:

- Skills를 지원하는 Codex CLI
- Git과 작업할 Git 저장소
- Run Context 엔진을 실행할 Python 3.10 이상
- 대상 프로젝트의 검사에 필요한 런타임과 의존성: Node, Bun, Python, Rust, Go 등
- PR 전달을 원할 경우 설치 및 인증된 GitHub CLI(`gh`)

독립 리뷰나 위임 경로에서는 선택된 에이전트 역할과 지정 모델도 사용할 수 있어야 합니다. 설치 스크립트는 역할 정의를 복사하며 모델 접근 권한을 부여하지는 않습니다. 실제 UI 미리보기를 만들고 검증하려면 브라우저·렌더링 도구가 필요합니다. 사용할 수 없는 검사는 통과했다고 기록하지 않습니다.

1. 터미널에서 Pulmu를 다운로드합니다. 아래 예시는 원본을 `~/tools/pulmu`에 보관하며, 해당 경로가 아직 없다고 가정합니다.

```bash
mkdir -p ~/tools
git clone https://github.com/KamiJeong/pulmu.git ~/tools/pulmu
cd ~/tools/pulmu
```

2. 설치 범위를 **하나 선택**합니다. `~/projects/my-project`는 실제 작업할 기존 Git 저장소 경로로 바꾸세요.

특정 프로젝트에서만 사용:

```bash
./install.sh --local ~/projects/my-project
```

현재 사용자의 모든 프로젝트에서 사용:

```bash
./install.sh --global
```

로컬 설치 후에는 [설치 관리](#설치-관리와-데모)의 Git 준비를 마칩니다. 원본 다운로드 경로와 작업할 프로젝트 경로는 서로 다릅니다.

3. **작업할 프로젝트**에서 Codex를 실행합니다. 스킬이 바로 나타나지 않으면 Codex를 다시 시작합니다.

```bash
cd ~/projects/my-project
codex
```

4. 다음 요청은 셸이 아니라 **Codex 안에서** 입력합니다.

```text
$pulmu "프로필 화면에 다크 모드 전환을 추가하고 테스트도 작성해줘"
```

구현은 기존 커밋이 있고 작업 트리가 깨끗한 저장소에서 시작합니다. 커밋 작성자 정보가 없다면 Git 사용자 정보를 설정하고, 프로젝트 검사에 필요한 의존성을 설치합니다. Pulmu는 작업 준비를 위해 무관한 변경을 임시 저장하거나 버리지 않습니다.

기존 기능으로 이미 해결되거나 설명만 필요한 요청은 Ignite 전에 근거를 설명하고 끝냅니다. 브랜치·상태 파일·빈 커밋을 만들지 않습니다. 실제 개발이 성공하면 검증과 리뷰 방식이 명시된 로컬 커밋을 만들며, GitHub 전달 조건이 충족되면 브랜치를 푸시하고 PR도 만들 수 있습니다.

## 작업 요청하기

원하는 결과, 중요한 제약, 완료 조건을 설명하면 됩니다. 내부 단계나 에이전트 이름, Forge 모드를 직접 고를 필요는 없습니다. 현재 문제, 원하는 동작, 유지해야 할 호환성·디자인 규칙, 납품 선호가 있으면 함께 적어주세요.

Codex 안에서 다음처럼 요청할 수 있습니다.

```text
$pulmu "프로필 폼의 저장 버튼 오탈자를 고쳐줘. 기존 레이아웃은 유지하고 로컬 커밋만 만들어줘. 푸시와 PR 생성은 하지 마."

$pulmu "이름과 이메일로 고객을 검색할 수 있게 해줘. 빈 결과와 오류 상태를 포함하고 필터링 테스트를 작성해줘. 검증을 통과하면 PR을 만들어줘."

$pulmu "두 번째 캐시 계층이 필요한지 검토해줘. 기존 동작과 장단점을 설명하고 파일은 수정하지 마."
```

Pulmu는 먼저 필요한 만큼만 읽고 변경 필요성을 판단합니다. 작고 명확한 변경은 판단을 짧게 알린 뒤 진행합니다. 동작·호환성·비용·범위가 크게 달라지는 대안이 있으면 구현 전에 추천안과 차이를 제시합니다. 기존 기능으로 목적을 달성할 수 있다면 새 구현을 권하지 않을 수도 있습니다.

제안에는 “추천안으로 진행해줘”, “기존 API는 유지해줘”, “디자인은 알아서 선택해줘”처럼 응답하면 됩니다. 중요한 선택이 해결되지 않았으면 답을 기다립니다. 이미 선택했거나 판단을 맡겼다면 같은 승인을 반복해서 요구하지 않습니다.

진행 중에도 제약을 추가할 수 있습니다. 새 요구가 기존 구현 계획을 무효화하면 Shape로 돌아가 영향을 받는 검증과 리뷰를 다시 수행합니다.

## UI 계획이 없을 때

디자인 시스템 이름, 폰트, 색상 값을 몰라도 기능을 요청할 수 있습니다.

```text
$pulmu "매출, 활성 고객 수, 최근 활동을 보여주는 고객 대시보드를 만들어줘. UI 방향은 정해지지 않았어. 구현 전에 추천 디자인과 대안을 보여줘."

$pulmu "같은 대시보드를 만들어줘. 디자인은 적합한 방향으로 알아서 선택하고 진행해줘. 가능한 한 기존 컴포넌트를 활용해줘."
```

디자인 방향이 중요한 작업에서는 다음 흐름으로 진행합니다.

1. 사용자, 주요 업무, 정보 밀도, 플랫폼, 기존 화면 규칙을 파악합니다.
2. 같은 대표 화면·콘텐츠·핵심 동작을 사용한 두 가지 시각적 방향을 보여주고, 추천 이유와 구현 부담을 설명합니다.
3. 작업 브랜치를 만들기 전에 저장소 밖의 임시 미리보기를 사용합니다. 정적 시안은 정적임을 밝히고, 미리보기 도구가 없으면 그 한계를 설명합니다.
4. 판단을 맡긴 경우를 제외하면 선택을 기다립니다. 선택한 정보 위계·시각 규칙·상태·반응형·접근성 기준은 Shape 안의 Pattern에 기록합니다.
5. 구현 후 사용 가능한 브라우저·접근성 도구로 실제 결과를 검사합니다. 시안만으로 상호작용이나 접근성이 검증되었다고 주장하지 않습니다.

CSS 프레임워크나 컴포넌트 라이브러리가 설치되어 있어도 제품의 UI 방향은 없을 수 있습니다. 작은 UI 수정은 보통 기존 규칙을 따르며, 매번 두 가지 시안을 고르게 하지 않습니다. “너무 답답하다”, “너무 휑하다”처럼 피드백해도 됩니다. Pulmu가 구체적인 수정 방향으로 바꿔 제안합니다.

Apple Human Interface Guidelines, Google Material Design, Microsoft Fluent, IBM Carbon, Adobe Spectrum, Shopify Polaris, Salesforce Lightning Design System, SAP Fiori 등을 참고 후보로 명시합니다. 플랫폼 지침·범용 UI 시스템·특정 생태계 시스템·브랜드 참고 사례를 구분하고 제품의 요구에 맞춰 후보를 좁힙니다. 실제 도입을 추천하기 전에는 공식 자료에서 프레임워크 지원·유지보수 상태·사용 조건을 확인합니다. 세부 정책은 [디자인 선택 지침](./.agents/skills/pulmu/references/design-selection.md)에 있습니다.

## 실행 깊이와 완료 결과

Pulmu는 저장소 근거를 바탕으로 두 가지를 별도로 결정합니다.

| 구분 | 선택 | 의미 |
| --- | --- | --- |
| Forge 깊이 | Quick / Standard / Full | 조사와 위험 분석이 얼마나 필요한지 |
| 실행 경로 | Direct / Reviewed / Delegated | 누가 구현하고 리뷰를 별도 맥락에서 수행하는지 |

Quick은 범위가 작고 위험이 낮은 변경, Standard는 일반 기능이나 단순하지 않은 수정, Full은 마이그레이션·보안·호환성 파괴·넓은 영향 범위에 적합합니다. 모드가 에이전트 수를 고정하지는 않습니다.

| 실행 경로 | 작성자 | 리뷰 방식 | 적합한 경우 |
| --- | --- | --- | --- |
| **Direct** | 메인 Orchestrator | 명시적인 자체 점검 | 범위가 명확하고 위험이 낮음. 하위 에이전트 없이 수행 가능 |
| **Reviewed** | 메인 Orchestrator | 새로운 맥락의 독립 리뷰 | 구현 맥락을 유지하면서 별도 검토가 필요함 |
| **Delegated** | 지정된 Orchestrator 또는 Smith | 새로운 맥락의 독립 리뷰 | 분산 조사나 별도 작성자가 실질적으로 도움이 됨 |

중간·높은 위험과 Full Forge는 독립 리뷰가 필수입니다. 보안·호환성 위험이 명시되면 해당 전문 리뷰어도 필요합니다. 필수 리뷰어를 사용할 수 없다고 자체 점검으로 대체하지 않습니다. 설정상 기본 동작으로, 높은 위험의 Full Forge는 GitHub 전달 시 초안 PR을 사용합니다.

메인 세션은 사용자가 선택한 모델을 사용합니다. 호출된 에이전트는 각 역할의 지정 모델을 사용하므로, 메인 모델 선택이 모든 전문 에이전트의 모델을 바꾸지는 않습니다. [에이전트 배치와 모델 기본값](./.agents/skills/pulmu/references/agent-orchestration.md)을 참고하세요. 모델 가용성과 비용은 실행 환경에 따라 다르며, 적응형 구조 자체가 실측된 토큰 절감률을 보장하지는 않습니다.

| 결과 | 전달되는 내용 |
| --- | --- |
| 자문·무변경 | 근거와 설명. 브랜치·개발 단계·커밋 없음 |
| 로컬 개발 완료 | 구현 결과, 검증 결과, 자체 점검 또는 독립 리뷰 여부, 브랜치와 커밋 |
| GitHub 개발 완료 | 로컬 결과에 더해 푸시된 브랜치와 실제 PR URL |
| 작업 중단 | 중단 단계, 구체적인 이유, 보존된 작업, 복구 방법. 성공으로 표시하지 않음 |

완료 보고에는 Forge 깊이·실행 경로·작성자·검사 결과·리뷰 방식·커밋·선택적 PR URL이 포함됩니다. 리뷰 방식은 `self` 또는 `independent`로 구분합니다. **자체 점검은 구현한 세션이 변경을 확인한 것이고, 독립 리뷰는 별도의 새로운 맥락에서 검토한 것입니다.** 어느 쪽도 모든 결함을 발견했다는 보장은 아닙니다. 수행하지 못한 검사는 한계로 표시합니다.

## 진행 상황 표시

실제 개발 실행에서는 Codex의 `update_plan`에 다음 7개 항목을 표시합니다. 표시 문자열은 한국어 환경에서도 동일합니다.

```text
🔥 Ignite — Prepare
🔎 Inspect — Explore
📐 Shape — Design
🔨 Hammer — Implement
🌊 Quench — Verify
🪨 Hone — Review
📦 Ship — Deliver
```

진행 상태는 기본 작업 목록의 상태 표시로 전달합니다. 단계 이름에 `active`, `pending`, `completed`를 붙이지 않으며, 에이전트·재시도·Pattern을 별도 최상위 단계로 추가하지 않습니다.

```text
✔ 🔥 Ignite — Prepare
✔ 🔎 Inspect — Explore
● 📐 Shape — Design
○ 🔨 Hammer — Implement
○ 🌊 Quench — Verify
○ 🪨 Hone — Review
○ 📦 Ship — Deliver
```

일반 진행 메시지에는 전체 목록을 반복하지 않고 현재 단계와 구체적인 작업 하나를 표시합니다.

```text
📐 Shape
  ● 구현 범위와 검증 방법 정리
```

실행 시작 시 워크플로 식별 문구를 한 번 표시합니다. 별도 단계가 아닙니다.

```text
🔥 Pulmu — Starting the forge workflow
```

## 7개 내부 단계

| 단계 | 수행 내용 | 담당 |
| --- | --- | --- |
| 🔥 **Ignite** | 저장소·납품 환경·기준 브랜치를 확인하고 작업 브랜치 준비 | 스크립트와 Orchestrator |
| 🔎 **Inspect** | 관련 코드·규칙·테스트·의존성·위험 조사 | Orchestrator와 필요한 읽기 전용 조사 에이전트 |
| 📐 **Shape** | 완료 조건·범위·검증·실행 경로·필요한 디자인 방향 결정 | Orchestrator와 선택적 Architect/Designer |
| 🔨 **Hammer** | 필요한 코드와 테스트 구현 | 지정된 Orchestrator 또는 `pulmu_smith` |
| 🌊 **Quench** | Shape에서 정한 검증 계획을 제한 시간과 함께 실행 | 스크립트와 필요한 경우 Analyst |
| 🪨 **Hone** | 검증된 동일 변경에 대한 자체 점검 또는 독립 리뷰 기록 | Orchestrator 또는 읽기 전용 리뷰어 |
| 📦 **Ship** | 검토한 변경을 커밋하고 로컬 또는 GitHub 전달 완료 | 스크립트와 Orchestrator |

실제 개발 실행은 모든 단계를 통과합니다. 자문·무변경 결과는 Ignite 전에 끝납니다. 사용자가 각 단계를 별도 명령으로 호출할 필요는 없습니다.

## 작업 조율과 단일 작성자

```text
메인 Codex 세션: Orchestrator
  ├─ 필요한 읽기 전용 Scouts / Architect / Designer
  ├─ 지정된 작성자 한 명: Orchestrator 또는 pulmu_smith
  ├─ 스크립트 기반 Quench
  ├─ 필요한 읽기 전용 Reviewers
  └─ 스크립트 기반 Ship
```

Orchestrator가 단계 전환·에이전트 배치·메타데이터·재시도·증거 취합·납품을 관리합니다. 독립 조사의 가치가 있을 때만 읽기 전용 작업을 분산하며, 한 실행에서 지정한 작성자가 Quench/Hone 수정도 담당합니다.

`🎨 Pattern`은 의미 있는 사용자 UI/UX 변경에 필요하며 Shape 안에 있습니다. Orchestrator가 직접 담당할 수 있어 Designer 호출이 필수는 아닙니다. 제품 디자인 방향이 없으면 앞의 디자인 선택 절차를 적용합니다.

재시도는 같은 작업 목록과 작업 ID를 사용합니다.

```text
Quench 실패 → Hammer → Quench
Hone 지적   → Hammer → Quench → Hone
```

전체 실행에서 Quench 수정은 최대 3회, Hone 개선은 최대 2회입니다. 재시도를 기록하면 Hammer로 돌아가고 이후 단계의 증거가 무효화됩니다. Quench 통과와 정확히 일치하는 필수 리뷰 결과가 없거나 중간·높은 심각도의 미해결 문제가 있으면 Ship은 차단됩니다. `pulmu_self_review` 기록으로 독립 리뷰 요건을 충족할 수 없습니다.

## 작업 상태 기록: Run Context

사용자는 기본 작업 목록으로 진행 상황을 보고, 도구는 Git 메타데이터의 상태 파일을 읽습니다.

```text
$pulmu
   ├─ update_plan: 사용자용 진행 표시
   └─ <git-dir>/pulmu/run.json: 기계가 읽는 실행 상태
        ├─ Codex
        ├─ 향후 재개 기능
        └─ 외부 관측 도구
```

Ignite가 만드는 상태 파일은 일반 저장소에서는 `.git/pulmu/run.json`입니다. 작업 트리에 포함되지 않으며 커밋하지 않습니다. 스키마 v2는 다음 정보를 기록합니다.

- 워크플로와 변경되지 않는 실행 ID
- `running`, `completed`, `failed`, `interrupted` 상태
- 민감 정보가 정리된 요청과 작업 유형
- Forge 깊이, 위험도, 변경 영역, Pattern 여부
- 실행 경로, 작성자, 리뷰 방식과 전문 리뷰 배치
- 현재 단계와 활동 중인 에이전트
- 기준·작업 브랜치와 납품 커밋
- Quench/Hone 재시도 횟수
- 시간 정보, 간결한 오류, 검증된 PR 정보

상태 전환은 작업 목록 갱신과 함께 수행합니다. 스키마 검증·예상 실행 ID 확인·파일 잠금·소유자 전용 권한·원자적 교체를 사용하며, Shape 결정을 다시 추론하지 않고 복사합니다.

종료 기록은 `<git-dir>/pulmu/runs/<runId>.json`에 보관합니다. 이전 실행이 `running`이면 명시적으로 완료·실패·중단 처리하기 전까지 새 Ignite가 이를 대체하지 못합니다. 이전 실행 종료 후 새 작업은 새 ID·요청·브랜치·증거를 사용합니다. 작업 트리 변경 때문에 시작이 차단되어도 이전 실행은 보존합니다. 손상된 상태는 일반 변경 시 거부하고, 명시적인 새 실행 초기화에서만 격리합니다.

**대상 프로젝트 디렉터리에서** 설치된 도구로 상태를 확인합니다.

```bash
bash ~/.agents/skills/pulmu/scripts/run-context.sh show
bash ~/.agents/skills/pulmu/scripts/pulmu-status.sh
```

`--local`로 설치했거나 저장소에 포함된 Pulmu를 사용한다면 `.agents/skills/pulmu/scripts/` 경로로 바꿉니다. 현재 디렉터리는 대상 저장소를, 스크립트 경로는 실행할 Pulmu 사본을 결정합니다. 자세한 계약은 [Run Context 문서](./.agents/skills/pulmu/references/run-context.md)를 참고하세요.

## Git과 GitHub 납품

Pulmu는 기존 저장소의 브랜치 전략을 따르며 Git Flow를 강제하지 않습니다. 현재 브랜치가 저장된 Pulmu 기록과 일치하면 브랜치·기준 브랜치·실행 ID를 검증하고 다음 작업에도 기록된 기준 브랜치를 사용합니다. 그 외에는 명시적 Pulmu 설정, 저장소 지침, 현재 브랜치 관례, 원격 기본 브랜치, 기존 `main` 또는 `develop` 순으로 선택합니다.

작업 브랜치는 `<유형>/<짧은-슬러그>` 형태입니다.

```text
feat/user-search
fix/login-redirect
docs/api-guide
```

이름은 사용자 명시, 저장소의 명시적인 명명 규칙, 위 기본 형식 순으로 선택합니다. 팀에서 요구한다면 `feature/PROJ-123-customer-search` 같은 이름을 요청할 수 있습니다. 기존 브랜치 몇 개로 규칙을 추측하거나 이슈 번호를 만들어 넣지 않습니다. Orchestrator가 완성된 이름을 내부 Ignite 도구의 `--branch`로 전달하며, 사용자는 계속 `$pulmu`만 호출하면 됩니다.

기본값인 `git.branch_prefix = ""`는 이름 공간을 추가하지 않습니다. `"pulmu"`로 설정하면 `pulmu/feat/customer-search` 형식을 유지할 수 있고, 다른 단순한 팀 접두사도 가능합니다. 완성된 이름을 명시하면 접두사 설정보다 우선합니다. 로컬·원격에 같은 이름이 있으면 `-2` 같은 숫자 접미사를 붙이므로, 최종 보고된 이름을 사용하세요.

이 정책은 새로 만드는 브랜치에만 적용하며 기존 이름은 바꾸지 않습니다. 작업 식별과 기준 브랜치 복구는 접두사가 아닌 저장된 기록을 사용합니다. 사람이 만든 `pulmu/...` 브랜치를 자동으로 Pulmu 작업으로 간주하지 않고, 접두사가 없는 기록된 브랜치도 인식합니다. 일치하는 기록이 충돌하면 생성을 차단하며, 기록을 모두 삭제하면 이름만으로 소유권을 복원하지 않습니다.

Inspect와 Shape에서 작업 메타데이터와 검증 명령·실행 디렉터리를 확정합니다. 이 기록으로 리뷰어·커밋·PR 본문·초안 여부·레이블을 결정합니다. Quench 증거는 실행 ID·브랜치·기준 커밋·HEAD·검증 대상 트리에 연결됩니다. 작성자는 실제 Git 인덱스를 변경하지 않습니다. Ship은 미리 스테이징된 내용을 거부하고, 스테이징 및 커밋된 트리가 리뷰 대상과 같은지 확인합니다.

로컬 전달은 검토된 커밋 생성 후 완료됩니다. GitHub 전달은 브랜치 푸시와 실제 PR URL 생성 또는 재사용까지 성공해야 완료됩니다. Pulmu는 병합이나 강제 푸시를 하지 않으며, 리뷰 담당자 배정은 CODEOWNERS와 저장소 자동화에 맡깁니다.

PR 본문에는 Summary, Changes, Pulmu Forge, Verification, Risk, Review Focus, Pulmu Metadata가 포함됩니다. 레이블은 `pulmu`, 작업 유형·Forge·위험 각 1개, 관련 영역 1~3개로 제한합니다. 레이블을 적용하지 못해도 유효한 PR 자체를 실패 처리하지 않습니다.

선택적으로 `.pulmu/config.toml`을 사용할 수 있습니다. 다음은 기본 설정입니다.

```toml
[git]
branch_prefix = ""
conventional_commits = true

[github]
create_pr = true
apply_labels = true
create_missing_labels = false
full_forge_draft = true

[policy]
auto_merge = false
force_push = false
```

`git.base_branch`로 기존 기준 브랜치를 지정할 수 있습니다. 설정은 데이터로만 읽으며 지원하지 않는 키·형식을 거부합니다. `auto_merge = true`와 `force_push = true`도 허용하지 않습니다. [납품 정책](./.agents/skills/pulmu/references/delivery-policy.md)에 상세 내용이 있습니다.

로컬만 원하면 요청에 **“로컬 커밋만 만들어줘. 푸시와 PR 생성은 하지 마.”**라고 적거나 `[github]`의 `create_pr`을 `false`로 설정합니다. 설정 변경은 실행 전에 준비하고 작업 트리를 깨끗하게 유지합니다. 기본 설정에서는 GitHub 환경이 준비되어 있으면 푸시와 PR 생성까지 진행할 수 있습니다.

### GitHub 준비

GitHub 전달에는 다음 조건이 필요합니다.

- `github.create_pr` 활성화: 기본값
- `origin` 원격 존재
- 각각 하나인 fetch/push URL이 동일한 GitHub 저장소를 가리킴
- GitHub CLI 설치 및 인증
- `gh repo view`로 대상 저장소 조회 가능

대상 저장소에서 확인합니다.

```bash
gh --version
gh auth login
gh auth status
git remote -v
gh repo view --json nameWithOwner,defaultBranchRef
```

인증된 계정은 `origin`에 작업 브랜치를 푸시하고 PR을 생성·수정할 수 있어야 합니다. 기본 레이블 동작은 읽기 권한을 사용합니다. 없는 레이블의 생성은 별도 관리 권한과 명시적 설정이 필요합니다.

### 납품 방식 선택

준비 조건을 충족하면 Ignite가 `PULMU_DELIVERY=github`를 선택합니다. GitHub를 명시적으로 요구하지 않았고 준비가 부족하면 `PULMU_DELIVERY=local`로 진행합니다. 요청에 PR이 필수라고 명시했다면 준비 부족 시 복구 안내와 함께 실행이 차단됩니다. `github.create_pr = false`는 로컬 전달을 선택합니다.

### Fork와 upstream의 제한

GitHub 작업과 반환된 PR URL은 `origin`의 fetch/push URL로 확인한 저장소에 고정됩니다. `origin`은 개인 fork이고 `upstream`은 원본인 구성에서 저장소를 가로지르는 PR은 자동화하지 않습니다. 의도한 대상에 쓰기 권한이 있다면 해당 저장소를 `origin`으로 사용하거나, 로컬 전달 후 직접 fork에 푸시하고 upstream PR을 생성합니다.

### PR과 레이블

기존 PR은 head와 base가 모두 맞을 때만 재사용하고, 최종 변경에 맞춰 제목과 본문을 갱신합니다. base가 다른 PR은 재사용하지 않습니다.

레이블은 `pulmu`, `type: feature`, `forge: standard`, `risk: low`, `area: frontend`처럼 저장소에 존재하는 정확한 이름을 사용합니다. 누락된 레이블은 보고하고 넘어갑니다. `github.create_missing_labels = true`로 명시하지 않으면 새로 만들지 않습니다.

### 중단된 GitHub 납품 복구

Ship은 커밋 생성 후 푸시와 PR 작업을 진행합니다. 중간에 실패하면 대상 프로젝트에서 상태를 확인합니다.

```bash
bash ~/.agents/skills/pulmu/scripts/pulmu-status.sh  # --local: .agents/skills/pulmu/scripts/pulmu-status.sh 사용
git status --short --branch
git log -1 --oneline
gh pr list --head "$(git branch --show-current)"
```

Pulmu 상태를 삭제하지 말고 인증이나 원격 접근 문제를 해결합니다.

```bash
gh auth login
gh auth status
git remote -v
gh repo view
```

해결 후 Orchestrator에 Ship 재시도를 요청합니다. 같은 실행에 기록된 커밋·브랜치·base·검증 대상과 깨끗한 작업 트리가 일치할 때만 재개하며, 해당 Ship이 실패 또는 중단 상태여도 중복 커밋을 만들지 않습니다. 납품 복구를 위해 새 Ignite를 시작하거나 `.git/pulmu`, `.git/pulmu-*` 복구 기록을 수동 삭제하지 마세요.

## 작업이 멈추거나 요구사항이 바뀌면

먼저 보고된 단계와 현재 상태를 확인하고, 같은 Codex 세션에 변경 사항이나 해결한 환경 문제를 설명합니다. 내부 도구 실행은 Orchestrator가 담당합니다. 사용자가 7개 명령을 순서대로 입력하거나 상태 파일을 편집할 필요는 없습니다.

| 상황 | 대응 |
| --- | --- |
| Ignite 전에 작업 트리가 변경되어 있음 | 기존 작업을 마무리하거나 별도로 보존한 뒤 깨끗한 트리에서 재시도합니다. Pulmu는 stash·reset·삭제하지 않습니다. |
| 이전 실행이 아직 `running` | 세션이 살아 있는지 확인합니다. 해당 세션에서 계속 진행하거나, 더 이상 활동하지 않음을 확인한 뒤 명시적으로 중단합니다. |
| 도구·의존성·접근 권한 부족 또는 시간 초과 | 보고된 실행 조건을 해결합니다. 환경 문제를 자동으로 코드 수정 문제로 취급하지 않습니다. |
| Quench/Hone에서 코드 문제 발견 | 제한된 재시도 안에서 지정 작성자가 수정합니다. 한도를 소진하면 브랜치를 보존하고 납품을 중단합니다. |
| 진행 중 새로운 범위나 위험 발견 | 변경 내용을 설명합니다. Orchestrator가 Ship 전에 명시적으로 `replan`하여 기존 작업과 실행 ID를 보존하고 이전 계획·증거를 무효화합니다. |
| 필수 독립 리뷰어 사용 불가 | 필요한 역할·모델 접근을 복구합니다. 자체 점검으로 대신하지 않습니다. |
| 커밋 후 GitHub 작업 실패 | [Ship 복구](#중단된-github-납품-복구)에 따라 기존 커밋을 사용합니다. 새 실행으로 시작하지 않습니다. |

Codex에 다음처럼 추가 지시할 수 있습니다.

```text
기존 공개 API와도 호환되어야 해. 현재 계획을 다시 검토하고, 작업을 보존하면서 필요한 검증과 리뷰를 다시 수행해줘.
```

`replan`은 Ship 전의 **활성 실행**에서 동작하며, 모든 실패·중단 상태를 재개하는 범용 명령은 아닙니다. 임의로 중단된 개발 세션의 자동 복구를 보장하지 않습니다. 보고된 보존 브랜치와 복구 방법을 따르세요. GitHub Ship 복구는 같은 커밋을 사용하는 명시적으로 지원된 복구 경로입니다.

## 설치 관리와 데모

**Pulmu를 복제한 디렉터리에서** 설치 범위를 선택합니다.

| 범위 | 설치·업데이트 | 제거 |
| --- | --- | --- |
| 특정 프로젝트 | `./install.sh --local /path/to/project` | `./uninstall.sh --local /path/to/project` |
| 현재 사용자 전역 | `./install.sh --global` | `./uninstall.sh --global` |

인자를 생략하면 기존처럼 현재 사용자 전역에 설치합니다. `--local`에는 이미 존재하는 프로젝트 디렉터리를 지정하며, 대상 저장소의 루트를 권장합니다. 설치 경로는 다음과 같습니다.

```text
<project>/.agents/skills/pulmu/
<project>/.codex/agents/pulmu-*.toml
```

로컬 설치는 프로젝트의 `.codex/config.toml`, 다른 스킬·에이전트, 사용자 전역 설정을 보존합니다. 대상 프로젝트에서 Codex를 실행하세요. 팀과 공유하려면 설치 파일을 커밋하고, 개인용이면 새로 설치된 미추적 경로를 Git의 로컬 exclude 파일에 등록한 뒤 작업을 시작하세요. 이미 추적 중인 파일의 변경은 ignore 규칙으로 숨겨지지 않습니다. 설치 스크립트는 Git ignore 규칙을 변경하지 않습니다.

개인용이며 설치 파일이 아직 Git에서 추적되지 않는 경우, 다음을 한 번 실행합니다. 팀에 공유할 파일이라면 이 단계 대신 설치 파일을 검토하고 커밋하세요.

```bash
cd ~/projects/my-project
printf '\n/.agents/skills/pulmu/\n/.codex/agents/pulmu-*.toml\n' >> "$(git rev-parse --git-path info/exclude)"
git status --short
```

Pulmu 원본 저장소에는 이미 스킬과 에이전트가 포함되어 있습니다. 원본에 대한 로컬 설치는 아무것도 바꾸지 않으며, 원본 삭제를 막기 위해 로컬 제거는 거부합니다.

현재 사용자 전역 설치 경로는 다음과 같습니다.

```text
~/.agents/skills/pulmu/
~/.codex/agents/pulmu-*.toml
```

Codex는 [프로젝트 스킬](https://learn.chatgpt.com/docs/build-skills)과 [프로젝트 에이전트 정의](https://learn.chatgpt.com/docs/agent-configuration/subagents)를 지원합니다. 목록의 표시 이름은 **Pulmu Workflows**이며 호출은 `$pulmu`입니다. 로컬 설치해도 기존 전역 사본은 제거되지 않으며, 같은 이름의 스킬이 함께 표시될 수 있습니다. 프로젝트에서만 사용하려면 `./uninstall.sh --global`로 사용자 전역 사본을 명시적으로 제거하세요.

업데이트는 **Pulmu를 복제한 디렉터리에서** 실행합니다. 아래는 로컬 설치 예시입니다.

```bash
cd ~/tools/pulmu
git pull --ff-only
./install.sh --local ~/projects/my-project
```

전역 설치는 마지막 명령을 `./install.sh --global`로 바꿉니다. 재설치는 설치된 스킬 디렉터리와 동봉된 에이전트 정의를 교체합니다. 새 파일을 먼저 준비하며 교체 실패 시 이전 설치 복구를 시도합니다. 사용자 수정은 관리하는 원본 체크아웃에 보관하고, 로컬 변경이 있으면 정리한 뒤 pull하세요. 저장소 파일만 수정해도 설치된 사본이 자동 갱신되지는 않습니다.

설치한 로컬 사본을 제거하려면 다음을 실행합니다.

```bash
cd ~/tools/pulmu
./uninstall.sh --local ~/projects/my-project
```

전역 사본 제거는 마지막 명령을 `./uninstall.sh --global`로 바꿉니다. 여러 프로젝트에 설치했다면 각 대상마다 로컬 제거를 실행합니다. 제거 후 Codex를 다시 시작하세요. 설치 파일을 Git에서 추적했다면 삭제 변경도 검토하고 커밋합니다. 위에서 수동 추가한 exclude 규칙은 필요에 따라 직접 제거하세요.

제거 명령은 다운로드한 `~/tools/pulmu` 원본과 프로젝트 작업물·커밋·실행 기록을 삭제하지 않습니다. 원본도 필요 없다면 설치 사본을 모두 제거한 뒤, 원본에 보관할 변경이 없는지 확인하고 해당 디렉터리를 삭제하면 됩니다.

저장소에 스킬이 포함된 일회용 데모를 만들 수 있습니다.

```bash
./scripts/create-demo-repo.sh /tmp/pulmu-demo
cd /tmp/pulmu-demo
codex
```

Codex 안에서 요청합니다.

```text
$pulmu "TaskStore에 complete(id)를 추가하고 테스트도 작성해줘"
```

인증된 GitHub CLI로 비공개 데모 저장소도 생성할 수 있습니다. 이 명령은 실제 GitHub 저장소를 만듭니다.

```bash
./scripts/create-demo-repo.sh /tmp/pulmu-demo --github pulmu-demo
```

## 보호 경계

- 한 실행의 작성자는 지정된 Orchestrator 또는 `pulmu_smith` 한 명입니다.
- 나머지 사용자 지정 에이전트는 읽기 전용입니다.
- 무관한 미커밋 변경은 Ignite를 차단하며 자동으로 보관하거나 버리지 않습니다.
- Ship 전에 Quench를 통과해야 합니다.
- 자체 점검과 독립 리뷰 기록은 구분합니다. 중간·높은 심각도의 Hone 지적이 남으면 납품하지 않습니다.
- 작업·실행 메타데이터는 확정 후 재사용하며, 명시적인 재계획 시 이후 증거를 무효화합니다.
- GitHub 전달 완료에는 실제 PR URL이 필요합니다.
- 병합·강제 푸시·파괴적인 정리를 하지 않습니다.
- Run Context에 인증 정보·환경 덤프·원본 로그·모델 응답을 저장하지 않습니다.

## 저장소 구조

```text
pulmu/
├── .github/
│   ├── workflows/ci.yml
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── .agents/skills/pulmu/
│   ├── SKILL.md
│   ├── VERSION
│   ├── scripts/
│   │   ├── ignite.sh
│   │   ├── metadata.sh
│   │   ├── quench.sh
│   │   ├── ship.sh
│   │   ├── run-context.py
│   │   ├── run-context.sh
│   │   └── pulmu-status.sh
│   └── references/
│       ├── stage-contract.md
│       ├── agent-orchestration.md
│       ├── design-pass.md
│       ├── design-selection.md
│       ├── forge-modes.md
│       ├── review-contract.md
│       ├── delivery-policy.md
│       └── run-context.md
├── .codex/agents/pulmu-*.toml
├── examples/task-store/
├── scripts/create-demo-repo.sh
├── tests/test.sh
├── README.md
├── README.ko.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── install.sh
└── uninstall.sh
```

## 개발과 검증

Pulmu 스크립트나 계약을 변경한 뒤 통합 테스트를 실행합니다.

저장소 테스트에는 `tomllib`을 제공하는 Python 3.11 이상과 예제 실행을 위한 Node.js/npm이 필요합니다. 사용자 실행용 Run Context 엔진의 Python 3.10 이상 조건과 구분합니다.

```bash
./tests/test.sh
```

이 테스트는 모델을 호출하지 않습니다. 셸·TOML 문법, 설치·데모 패키징, 작성자와 실행 경로, 7단계 표시, Pattern, 메타데이터·브랜치 정책, Quench/Hone 증거 조건, 로컬·GitHub 전달, Run Context 상태·재시도·재계획, 오래되거나 손상된 상태, 민감 정보 정리, 동시성, 이력, 이전 버전 이관, 연결된 worktree를 검사합니다.

변경·PR 작성 절차는 [기여 가이드](./CONTRIBUTING.md), 비공개 취약점 신고는 [보안 정책](./SECURITY.md), 주요 변경은 [변경 이력](./CHANGELOG.md)을 참고하세요. 내부 계약과 기여 문서는 영어로 제공됩니다.

## 라이선스

MIT
