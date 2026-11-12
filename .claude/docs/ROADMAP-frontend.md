# [ROADMAP] 웹 프론트엔드 개발 로드맵

> **기준 문서:** `.claude/docs/PRD.md` v1.1 (단계 요약은 PRD §18의 F0~F6, 이 문서가 상세 태스크)
> **📅 최종 업데이트:** 2026-11-12
> **📊 진행 상황:** Phase 0~5 완료, Phase 6 대기 중 — 전체 docker 스택·E2E 시크릿 필요 (26/29 Tasks 완료)
> **독자:** 서브 에이전트. 태스크 하나와 "서브 에이전트 공통 규칙"만 읽어도 작업할 수 있도록 작성했습니다.

## 진행 현황판

`/docs:update-roadmap`이 아래 체크박스와 각 태스크 본문의 완료 조건 체크박스를 함께 갱신합니다.

### Phase 0: 프로젝트 골격 (PRD F0)

- [x] **T0-1** Vite + React 19 + TS strict 골격, 런타임 고정 (선행: -)
- [x] **T0-2** ESLint·Prettier, npm 스크립트, 문서 명령 갱신 (선행: T0-1)
- [x] **T0-3** Vite 설정: proxy, 빌드 출력, 환경변수 모듈 (선행: T0-1)
- [x] **T0-4** 테스트 기반: Vitest + RTL + MSW (선행: T0-2)
- [x] **T0-5** API 계약 타입, axios 클라이언트, 에러 정규화 (선행: T0-4)
- [x] **T0-6** 앱 셸: QueryClient 정책, 라우터, ErrorBoundary, 토스트 (선행: T0-5)
- [x] **T0-7** 디자인 토큰, 글로벌 스타일, 4영역 레이아웃 셸 (선행: T0-6)
- [x] **T0-8** 공통 컴포넌트: Modal, IconButton, Slider (선행: T0-7)

### Phase 1: 인증 (PRD F1)

- [x] **T1-1** JWT exp 디코드, 토큰 저장소 이벤트 (선행: T0-5)
- [x] **T1-2** AuthProvider·useAuth (선행: T1-1, T0-6)
- [x] **T1-3** `/auth/callback` 라우트 (선행: T1-2)
- [x] **T1-4** 로그인 모달, 헤더 아바타, 프로필 팝오버 (선행: T1-2, T0-8)

### Phase 2: 목록·검색 (PRD F2)

- [x] **T2-1** tracks API, useTracksQuery, 시간 포맷 (선행: T0-6)
- [x] **T2-2** TrackList·TrackRow·StatusBadge, 무한 스크롤 (선행: T2-1, T0-7)
- [x] **T2-3** SearchBar, useDebouncedValue (선행: T2-1)
- [x] **T2-4** 변환 상태 폴링 (선행: T2-2)

### Phase 3: 업로드 (PRD F3)

- [x] **T3-1** readAudioTags, 업로드 사전 검증, FormData 빌더 (선행: T0-5)
- [x] **T3-2** UploadModal UI (선행: T3-1, T1-4, T0-8)
- [x] **T3-3** useUploadTrack: 진행률, 취소, 결과 처리 (선행: T3-2, T2-1)

### Phase 4: 플레이어 (PRD F4)

- [x] **T4-1** attachHlsStream, 정리 함수 (선행: T0-4)
- [x] **T4-2** PlayerProvider·usePlayer (선행: T4-1, T2-1)
- [x] **T4-3** BottomPlayerBar: 재생·진행·시간 (선행: T4-2, T0-8)
- [x] **T4-4** 볼륨·음소거·반복·키보드·Media Session (선행: T4-3)

### Phase 5: 다운로드·마감 (PRD F5)

- [x] **T5-1** 원본 다운로드 `<a download>` (선행: T2-2, T4-3)
- [x] **T5-2** 접근성·반응형 마감 (선행: T5-1, T3-3)
- [x] **T5-3** 안정성·보안·번들 점검 (선행: T5-2)

### Phase 6: E2E·통합 (PRD F6)

- [ ] **T6-1** Playwright 설정, JWT 주입 헬퍼 (선행: T5-3)
- [ ] **T6-2** Milestone 1 시나리오 (선행: T6-1)
- [ ] **T6-3** 통합 확인·수동 테스트 기록 (선행: T6-2)

## 서브 에이전트 공통 규칙

모든 태스크에 적용됩니다. 태스크별 "주의"는 이 규칙에 더해지는 항목입니다.

1. **시작 전 읽기:** `CLAUDE.md`와 태스크의 "참조"에 적힌 PRD 절을 읽습니다. 선행 태스크가 모두 체크되어 있는지 현황판에서 확인하고, 아니면 시작하지 않고 보고합니다.
2. **PRD와 충돌하면 멈춥니다.** 임의로 판단하지 말고 사용자에게 확인한 뒤 PRD §16에 기록합니다. 문서 우선순위는 `API.md` > `PRD-05.md` > `PRD-04.md` > `PRD.md` > `PRD-02.md`입니다.
3. **라이브러리 API는 Context7로 확인합니다.** 대상: hls.js, TanStack Query v5, music-metadata, MSW, Vite 8, React Router, Vitest, Playwright. 학습 데이터로 시그니처를 추측하지 않습니다.
4. **완료 정의:** 태스크의 완료 조건을 **모두** 만족하고, `npm run lint`·`npm run typecheck`·`npm run test`가 통과해야 합니다(T0-2 이후에 적용. 그 전 태스크는 해당 태스크의 완료 조건만 확인).
5. **범위:** 이 저장소는 SPA 소스만 다룹니다. 백엔드·Nginx·`docker-compose.yml`은 변경하지 않습니다. 필요한 변경은 PRD §15에 요청으로만 추가합니다.
6. **금지 사항:**
   - `dangerouslySetInnerHTML` 사용
   - 토큰을 `console`·URL·에러 리포트에 남기는 것
   - 서버가 보낸 `message`를 화면에 그대로 노출하는 것(PRD §3.4의 클라이언트 메시지만 사용)
   - 시크릿을 `VITE_*`나 저장소에 두는 것
   - `rm -r`, `git push`, `git restore` 등 `.claude/settings.json`이 막는 명령을 우회하는 것(삭제는 `git rm`)
7. **코딩 규칙:** 들여쓰기 4칸, 변수·함수 camelCase, 함수명은 동사로 시작(`getTracks`, `handleClick`), 컴포넌트 PascalCase, 코드 주석·문서·커밋 메시지는 한국어, 식별자는 영어.
8. **범위 밖 발견 사항**은 고치지 말고 최종 보고의 "후속 메모"에 적습니다. 태스크는 원자적으로 유지합니다.
9. **종료 절차:** 완료 조건 증거(명령 출력 요약)를 보고하고, `/git:commit`으로 커밋한 뒤 `/docs:update-roadmap`으로 현황을 갱신합니다. 커밋 메시지에 Claude 서명을 넣지 않습니다.
10. **단계별 주의 표기:** 태스크의 "주의"는 `탐색`(읽고 확인할 것) → `계획`(구현 전에 정할 것) → `구현`(코딩 중 함정) → `검토`(끝나고 점검할 것) 순서로 적었습니다. 해당 단계만 적혀 있습니다.

## 의존 관계 요약

```text
P0(골격) ─┬─> P1(인증) ──────────────┐
          ├─> P2(목록·검색) ─┬─> P4(플레이어) ─┤
          │                  └─> P3(업로드; T1-4 필요) ┤
          └─ T4-1은 T0-4 직후 시작 가능          └─> P5(마감) ─> P6(E2E)
```

- **병렬 가능:** P1과 P2는 서로 독립입니다. T4-1(`attachHlsStream`)은 UI 없이 T0-4 직후 시작할 수 있습니다. P3는 T1-4(프로필 팝오버)와 T2-1이 끝나야 시작합니다.
- **파일 충돌 주의:** 병렬로 진행할 때 `App.tsx`·`components/`·`styles/`를 동시에 수정하지 않도록 태스크 단위로 담당 파일을 나눕니다.

---

## Phase 0: 프로젝트 골격 (PRD F0)

목표: 이후 모든 Phase가 의존하는 빌드·테스트·API·셸 기반을 만든다. 이 Phase가 끝나면 빈 화면이라도 `npm run dev`, `lint`, `typecheck`, `test`, `build`가 모두 동작한다.

#### T0-1. Vite + React 19 + TS strict 골격, 런타임 고정

- **목표:** 저장소 루트에 Vite 8 + React 19 + TypeScript(strict) 프로젝트를 만들고, Node 26을 `.node-version`으로 고정한다.
- **선행:** -
- **참조:** PRD §2, §10, §11
- **산출물:** `package.json`, `vite.config.ts`, `tsconfig*.json`, `index.html`, `src/main.tsx`, `src/App.tsx`(빈 화면), `.node-version`, `.gitattributes`, `.gitignore`, `.env.example`
- **완료 조건**
  - [x] `npm install` 후 `npm run dev`가 `http://localhost:5173`에서 기동한다.
  - [x] `npx tsc --noEmit`이 오류 없이 통과하고 `tsconfig`에 `"strict": true`가 있다.
  - [x] `.node-version`의 값이 `26`이고, `.gitattributes`에 `* text=auto eol=lf`, `.gitignore`에 `.env`가 있으며 `.env.example`이 존재한다.
  - [x] 폴더 뼈대(`src/api`, `features/{auth,upload,tracks,player}`, `components`, `hooks`, `lib`, `styles`)가 PRD §10과 일치한다.
- **주의**
  - 탐색: Node 26의 LTS 전환 여부(공식 일정)와 React Router·axios의 설치 시점 안정판을 확인하고, 확정 버전을 PRD §2 표의 "확인 버전" 칸에 기록한다. `package.json`은 정확한 버전으로 고정한다.
  - 구현: 템플릿이 만드는 샘플 코드·자산은 제거한다. React Router는 library mode로 쓴다.
  - 검토: `.gitattributes`를 추가해도 이미 커밋된 파일의 줄바꿈은 자동으로 바뀌지 않는다. 정규화(`git add --renormalize .`)는 사용자 확인 후에만 한다.

#### T0-2. ESLint·Prettier, npm 스크립트, 문서 명령 갱신

- **목표:** 코딩 규칙을 도구로 강제하고, 이후 태스크가 쓰는 표준 스크립트를 만든다.
- **선행:** T0-1
- **참조:** PRD §2(품질, 코딩 규칙), `CLAUDE.md` "계획된 명령"
- **산출물:** `eslint.config.*`, `.prettierrc`, `package.json` scripts
- **완료 조건**
  - [x] `npm run lint`, `npm run typecheck`, `npm run format`, `npm run build`가 존재하고 `lint`가 0 errors로 끝난다.
  - [x] Prettier 설정이 4칸 들여쓰기·작은따옴표다(포맷 후 샘플 파일 확인).
  - [x] `CLAUDE.md`의 "계획된 명령" 절이 실제 스크립트에 맞게 갱신되고 "현재 상태" 절의 "아직 소스 코드가 없다" 문구가 사실에 맞게 고쳐진다.
- **주의**
  - 구현: `typecheck`는 `tsc --noEmit`(프로젝트 참조를 쓰면 `tsc -b`)이다. `.claude/settings.json`이 허용하는 명령 이름(`npm run test|build|lint|typecheck`)과 스크립트 이름을 일치시킨다.
  - 검토: ESLint 설정이 `src/`와 설정 파일을 모두 대상으로 하되 `../frontend-dist`와 `node_modules`는 제외하는지 확인한다.

#### T0-3. Vite 설정: proxy, 빌드 출력, 환경변수 모듈

- **목표:** 개발 서버가 전체 docker 스택(`http://localhost`)과 같은 구조로 동작하게 하고, 빌드 결과물을 `../frontend-dist`로 낸다.
- **선행:** T0-1
- **참조:** PRD §11, §12.2, §12.3
- **산출물:** `vite.config.ts`, `src/lib/env.ts`, `src/lib/env.test.ts`(테스트 기반은 T0-4에서 완성되므로 이 태스크에서는 함수 단위로 작성하고 T0-4 이후 실행해도 된다)
- **완료 조건**
  - [x] `server.proxy`에 `/api`, `/oauth2`, `/login/oauth2`, `/stream`, `/artwork` 5개가 모두 `target: 'http://localhost'`, `changeOrigin: true`로 있다.
  - [x] `npm run build`가 `../frontend-dist`에 `index.html`과 번들을 출력한다(`emptyOutDir: true` 명시).
  - [x] `getRedirectUri()`가 `VITE_OAUTH_REDIRECT_URI`가 있으면 그 값을, 없으면 `${location.origin}/auth/callback`을 반환하는 단위 테스트가 통과한다.
  - [x] `getApiBaseUrl()`이 `VITE_API_BASE_URL`이 비어 있으면 빈 문자열을 반환한다.
- **주의**
  - 구현: `emptyOutDir: true`는 **저장소 바깥 폴더(`../frontend-dist`)의 기존 내용을 삭제**한다. 경로 오타가 없는지 두 번 확인하고, 처음 빌드 전에 해당 폴더 상태를 `ls`로 본다. `/login` 전체가 아니라 `/login/oauth2`만 프록시한다(SPA 라우트와 충돌 방지).
  - 검토: `changeOrigin`을 빼면 Google `redirect_uri` 계산이 어긋나 로그인이 실패한다. 이 이유를 설정 파일 주석(한국어)으로 남긴다.

#### T0-4. 테스트 기반: Vitest(jsdom) + RTL + MSW

- **목표:** 백엔드 없이 컴포넌트·API를 테스트할 수 있는 기반을 만든다.
- **선행:** T0-2
- **참조:** PRD §13
- **산출물:** `vitest` 설정, `src/test/setup.ts`, `src/test/renderWithProviders.tsx`, `src/test/server.ts`(MSW), 샘플 테스트
- **완료 조건**
  - [x] `npm run test`가 통과하고, 단일 파일 실행(`npx vitest run <경로>`)이 동작한다.
  - [x] 샘플 컴포넌트 테스트(RTL)와 MSW 핸들러를 쓰는 테스트가 각각 1개 이상 통과한다.
  - [x] `renderWithProviders`가 `QueryClientProvider`(`retry: false`)와 `MemoryRouter`를 제공한다.
  - [x] MSW가 `onUnhandledFrame: 'error'`(MSW 3, PRD §16 #21)로 동작해 처리되지 않은 요청이 테스트를 실패시킨다(검증용 테스트 포함).
  - [x] 테스트 사이에 `localStorage`와 쿼리 캐시가 초기화된다.
- **주의**
  - 탐색: MSW 최신 API(`http`, `HttpResponse`)와 Vitest 설정 방식은 Context7로 확인한다. 구버전 `rest` API를 쓰지 않는다.
  - 구현: `npm run test`는 watch가 아니라 단발 실행(`vitest run`)으로 정의한다(CI·에이전트 환경에서 멈추지 않게).
  - 검토: jsdom에 없는 API(`IntersectionObserver`, `HTMLMediaElement.play`, `URL.createObjectURL`)는 setup에서 한 번만 모킹해 이후 태스크가 재사용하게 한다.

#### T0-5. API 계약 타입, axios 클라이언트, 에러 정규화

- **목표:** 백엔드 계약을 타입으로 고정하고, 모든 오류를 하나의 `ApiError`로 정규화하는 공통 응답·예외 계층을 만든다.
- **선행:** T0-4
- **참조:** PRD §3.2~§3.4, §4.3
- **산출물:** `src/api/types.ts`, `src/api/client.ts`, `src/lib/errorMessages.ts`, `src/lib/tokenStorage.ts`, 테스트
- **완료 조건**
  - [x] `types.ts`의 타입이 PRD §3.3과 일치한다(필드명·nullable·`ErrorCode` 8종).
  - [x] 토큰이 있으면 요청에 `Authorization: Bearer {jwt}`가 붙고, 없으면 붙지 않는다(MSW로 헤더 검증).
  - [x] 정규화 테스트가 통과한다: ① `ErrorResponse` JSON 400, ② Nginx HTML 413 → `PAYLOAD_TOO_LARGE`, ③ HTML 502 → `INTERNAL_ERROR`, ④ 그 외 HTML 4xx → `INVALID_REQUEST`, ⑤ 네트워크 오류 → `NETWORK_ERROR`, ⑥ 알 수 없는 `code` → `INTERNAL_ERROR`와 동일 처리.
  - [x] `errorMessages.ts`의 문구가 PRD §3.4 표와 글자 단위로 일치한다.
  - [x] `tokenStorage`가 키 `auth.token`으로 읽기·쓰기·삭제를 제공하고 localStorage 접근 실패(throw)에도 앱이 죽지 않는다.
- **주의**
  - 계획: 토큰 접근은 `tokenStorage` 한 곳으로 일원화한다. 이후 T1의 인증·탭 동기화가 이를 재사용한다.
  - 구현: `timestamp`는 Asia/Seoul(+09:00), `createdAt`은 UTC라 표기가 다르다. 타입 주석에 남긴다.
  - 검토: 서버 `message`를 UI 경로에서 쓰는 곳이 없는지 확인한다(`ApiError.message`는 클라이언트 메시지다).

#### T0-6. 앱 셸: QueryClient 정책, 라우터, ErrorBoundary, 토스트

- **목표:** 라우팅·재시도 정책·전역 오류 격리·토스트라는 이후 모든 Phase가 쓰는 앱 뼈대를 만든다.
- **선행:** T0-5
- **참조:** PRD §3.4(재시도), §9.3, §14
- **산출물:** `src/App.tsx`, `src/main.tsx`, `src/components/Toast*`, `src/components/ErrorBoundary.tsx`, `src/api/queryClient.ts`
- **완료 조건**
  - [x] 4xx 오류는 재시도하지 않고(호출 1회), 5xx·네트워크 오류는 최대 2회 재시도한다(MSW 호출 횟수로 검증).
  - [x] 라우트 `/`와 `/auth/callback`이 렌더링되고(`MemoryRouter` 테스트), 그 밖의 경로는 `/`로 처리한다.
  - [x] `showToast`(또는 동등한 훅)로 띄운 토스트가 `aria-live="polite"` 영역에 나타나고 자동으로 사라진다.
  - [x] `ErrorBoundary`가 하위 컴포넌트의 렌더 오류를 격리하고 대체 UI를 보여준다(테스트).
  - [x] `StrictMode`로 감싸져 있다.
- **주의**
  - 계획: 토스트 API 시그니처(예: `showToast({ message, type })`)는 이후 거의 모든 태스크가 쓰므로 먼저 확정하고 문서 주석에 남긴다.
  - 구현: `/auth/callback`·`/`의 실제 화면은 이후 태스크에서 채운다. 이 태스크에서는 자리표시 컴포넌트만 둔다.

#### T0-7. 디자인 토큰, 글로벌 스타일, 4영역 레이아웃 셸

- **목표:** YouTube Music 다크 테마의 토큰과 헤더·본문·하단 플레이어 슬롯 레이아웃을 만든다.
- **선행:** T0-6
- **참조:** PRD §9.1, §9.2, §9.3
- **산출물:** `src/styles/tokens.css`, `src/styles/global.css`, `src/components/Header`(자리표시), 레이아웃 컴포넌트
- **완료 조건**
  - [x] `tokens.css`가 PRD §9.2의 7개 토큰 값과 일치한다(`--color-warning`은 새로 정의하고 값을 PRD에 기록).
  - [x] 헤더·본문·하단 플레이어 슬롯이 배치되고, 플레이어 슬롯이 비어 있을 때 본문 하단 여백이 과하지 않다.
  - [x] 폭 360px에서 가로 스크롤이 생기지 않는다(Playwright MCP로 `scrollWidth <= clientWidth` 확인과 스크린샷).
  - [x] 텍스트·배경 대비가 WCAG AA(4.5:1)를 만족한다(`--color-text-muted` 포함, 계산값 기록).
- **주의**
  - 구현: UI 프레임워크 없이 CSS Modules + 토큰만 쓴다. 플러그인 `frontend-design`, 스킬 `premium-frontend-ui`·`anti-ui-slop`의 지침을 참고하되 PRD의 팔레트를 우선한다.
  - 검토: `#AAAAAA` on `#030303`은 대비가 충분하지만 `#212121` 위에서도 확인한다.

#### T0-8. 공통 컴포넌트: Modal, IconButton, Slider

- **목표:** 접근성 계약을 갖춘 재사용 컴포넌트 3종을 만든다.
- **선행:** T0-7
- **참조:** PRD §7.3(슬라이더), §9.3
- **산출물:** `src/components/{Modal,IconButton,Slider}/`, 각 RTL 테스트
- **완료 조건**
  - [x] Modal: `role="dialog"`, `aria-modal="true"`, 열면 포커스가 안으로 이동하고 Tab이 모달 안에서 순환한다(포커스 트랩), 닫으면 이전 포커스로 복귀한다.
  - [x] Modal: `ESC`와 배경 클릭으로 닫히되, `onRequestClose`가 `false`를 반환하면(전송 중 확인용) 닫히지 않는다.
  - [x] IconButton: `aria-label` prop이 타입상 필수다(`// @ts-expect-error` 테스트로 확인).
  - [x] Slider: `aria-valuenow/min/max`를 노출하고, 드래그 중에는 `onChange`(로컬 값)만, 놓을 때 `onCommit`을 한 번 호출한다(분리 테스트). 키보드 화살표로도 조작된다.
- **주의**
  - 계획: Slider의 "드래그 중 로컬 값 / 놓을 때 커밋" 계약은 T4-3(진행)과 T4-4(볼륨)이 그대로 쓴다. 여기서 확정하고 사용 예를 주석으로 남긴다.
  - 구현: 모달은 포털로 렌더링한다. 배경 스크롤 잠금은 닫을 때 반드시 해제한다.

---

## Phase 1: 인증 (PRD F1)

목표: Google 로그인 → JWT 보관 → 사용자 표시 → 만료·탭 동기화·로그아웃까지 동작한다. 백엔드 없이 MSW로 검증하고, 실제 로그인 확인은 T6-3에서 한다.

#### T1-1. JWT exp 디코드, 토큰 저장소 이벤트

- **목표:** 서명 검증 없이 `exp`를 읽는 유틸과, 다른 탭의 토큰 변경을 구독하는 기능을 만든다.
- **선행:** T0-5
- **참조:** PRD §4.3
- **산출물:** `src/lib/jwt.ts`, `src/lib/tokenStorage.ts`(구독 추가), 테스트
- **완료 조건**
  - [x] `decodeJwtExp(token)`이 정상 토큰(base64url 패딩이 없는 것 포함, 한글 클레임 포함)의 `exp`(초)를 반환하고, 형식 오류·`exp` 없음 입력에서 `null`을 반환한다(throw하지 않음).
  - [x] `isTokenExpired(token, now)`가 경계(`exp === now`)를 만료로 처리한다.
  - [x] `subscribeToken(callback)`이 `storage` 이벤트(키 `auth.token`)에만 반응하고, 해제 함수가 리스너를 제거한다.
- **주의**
  - 구현: base64url(`-`, `_`)을 `+`, `/`로 바꾸고 패딩을 보정한다. 한글 클레임이 있어도 깨지지 않도록 UTF-8로 디코드한다.
  - 검토: 토큰 원문이 로그·테스트 출력에 찍히지 않는지 확인한다(테스트용 토큰은 더미 값).

#### T1-2. AuthProvider·useAuth

- **목표:** 앱 전역 로그인 상태(사용자 조회, 401 처리, 만료 타이머, 탭 동기화, 로그아웃)를 제공한다.
- **선행:** T1-1, T0-6
- **참조:** PRD §3.2, §4.3
- **산출물:** `src/features/auth/AuthProvider.tsx`, `useAuth.ts`, `src/api/auth.ts`(`getMe`, `getLoginUrl`), 테스트
- **완료 조건**
  - [x] 토큰이 있으면 `GET /api/auth/me`를 호출하고 200이면 `user`(이메일, `profileImageUrl`)를 노출한다. 토큰이 없으면 호출하지 않는다.
  - [x] `/api/auth/me`가 401이면 토큰을 삭제하고 비로그인 상태가 되며 `UNAUTHORIZED` 토스트가 한 번 나온다.
  - [x] 가짜 타이머로 `exp` 시각이 되면 자동 로그아웃된다.
  - [x] 다른 탭에서 `storage` 이벤트(로그인·로그아웃)가 오면 즉시 상태에 반영된다.
  - [x] `logout()`은 서버를 호출하지 않고 토큰 삭제 + `['me']` 쿼리만 제거한다(`['tracks']` 캐시는 유지됨을 테스트).
  - [x] `getLoginUrl()`이 `${VITE_API_BASE_URL}/oauth2/authorization/google?redirect_uri=${encodeURIComponent(redirectUri)}` 형식이다.
- **주의**
  - 계획: 401 전환 로직을 axios 인터셉터가 아니라 `['me']` 쿼리 오류 처리에 둔다. 다른 API는 401을 반환하지 않기 때문이다.
  - 구현: 타이머 지연이 `setTimeout` 최대값(약 24.8일)을 넘으면 오버플로로 즉시 실행되므로 상한을 둔다.
  - 검토: 토큰 갱신(재로그인)·로그아웃 시 이전 타이머가 해제되는지 확인한다.

#### T1-3. `/auth/callback` 라우트

- **목표:** 백엔드가 `?token=` 또는 `?error=`로 돌려보내는 콜백을 안전한 순서로 처리한다.
- **선행:** T1-2
- **참조:** PRD §4.2, §4.4, §13
- **산출물:** `src/features/auth/AuthCallbackPage.tsx`, `loginErrorMessages.ts`, 테스트
- **완료 조건**
  - [x] `?token=abc`: 쿼리를 읽은 뒤 `history.replaceState`로 주소 쿼리를 제거하고, 토큰을 저장하고, `['me']`를 무효화하고, `/`로 `replace` 이동한다(호출 순서를 테스트로 검증).
  - [x] `?error=access_denied` 등 PRD §4.4의 모든 코드가 해당 문구 토스트로 표시되고, 알 수 없는 코드는 `login_failed` 문구가 나온다. 토큰은 저장되지 않는다.
  - [x] `token`과 `error`가 모두 없으면 토스트 없이 `/`로 이동한다.
  - [x] `StrictMode`(이중 effect 실행)에서도 토큰이 저장되고 토스트가 한 번만 나온다.
  - [x] 처리 후 `window.location.search`가 비어 있다.
- **주의**
  - 구현: 순서는 **쿼리 읽기 → replaceState → 저장 → navigate**다. `useRef` 가드로 한 번만 실행한다(두 번째 실행에서는 쿼리가 이미 지워져 토큰을 잃는다).
  - 검토: 토큰이 라우터 `state`·로그·토스트에 새지 않는지 확인한다. 실제 로그인 수동 확인은 PRD §15 #1(백엔드 허용 콜백 `http://localhost:5173/auth/callback` 등록)이 선행 조건이다.

#### T1-4. 로그인 모달, 헤더 아바타, 프로필 팝오버

- **목표:** 헤더의 로그인 진입 UI와 로그인 후 아바타·메뉴를 만든다.
- **선행:** T1-2, T0-8
- **참조:** PRD §4.1, §5(첫 문단), §9
- **산출물:** `src/features/auth/{LoginModal,ProfileMenu}.tsx`, `src/components/{Header,Avatar}`, 테스트
- **완료 조건**
  - [x] 비로그인: 헤더에 `로그인` 버튼. 클릭하면 모달이 열리고 `Sign with Google` 버튼이 있다.
  - [x] `Sign with Google` 클릭이 `window.location.assign(getLoginUrl())`을 호출한다(`assign` 모킹으로 URL 검증).
  - [x] 로그인: 아바타가 `profileImageUrl`을 표시하고, 이미지 로드 실패 또는 `null`이면 이메일 첫 글자 이니셜을 표시한다.
  - [x] 아바타 클릭 시 팝오버에 `업로드`, `로그아웃` 두 항목이 있고, 키보드(Enter/Esc/화살표)로 조작되며 바깥 클릭·Esc로 닫힌다.
  - [x] `로그아웃` 클릭이 `logout()`을 호출한다.
- **주의**
  - 계획: `업로드` 항목은 T3-2가 연결하기 전까지 `onUploadClick` 콜백 prop으로 비워 둔다.
  - 구현: 구글 로고는 로컬 SVG로 둔다(외부 요청 없음).

---

## Phase 2: 목록·검색 (PRD F2)

목표: 최신순 무한 스크롤 목록, 디바운스 검색, 변환 상태 뱃지와 자동 갱신. P1과 병렬 가능하다.

#### T2-1. tracks API, useTracksQuery, 시간 포맷

- **목표:** 목록·단건 조회 API 래퍼와 무한 쿼리 훅, 재생 시간 포맷터를 만든다.
- **선행:** T0-6
- **참조:** PRD §3.2(쿼리 규칙), §6.1, §6.2
- **산출물:** `src/api/tracks.ts`(`getTracks`, `getTrack`), `src/features/tracks/useTracksQuery.ts`, `src/lib/format.ts`, 테스트
- **완료 조건**
  - [x] `getTracks({ keyword, page, size })`가 `keyword`를 `trim`하고 빈 값이면 파라미터를 보내지 않는다(MSW로 쿼리스트링 검증). `status` 파라미터는 보내지 않는다.
  - [x] `useTracksQuery`가 키 `['tracks', keyword]`, `size=20`, `initialPageParam=0`, `getNextPageParam = last => last.hasNext ? last.page + 1 : undefined`로 동작한다(2페이지 MSW 시나리오).
  - [x] 검색어가 바뀌어도 이전 목록이 유지된다(`placeholderData: keepPreviousData`).
  - [x] `formatDuration`: `0→0:00`, `59→0:59`, `75→1:15`, `3599→59:59`, `3600→1:00:00`, `3725→1:02:05`.
- **주의**
  - 탐색: TanStack Query v5의 `useInfiniteQuery` 옵션(`initialPageParam` 필수)과 `keepPreviousData` import 위치를 Context7로 확인한다.
  - 검토: 응답을 변환하지 않고 `TrackResponse` 그대로 쓰는지 확인한다(`artworkUrl`을 임의로 가공하지 않는다, PRD §7.1).

#### T2-2. TrackList·TrackRow·StatusBadge, 무한 스크롤

- **목표:** 목록 UI와 하단 센티널 기반 무한 스크롤을 만든다.
- **선행:** T2-1, T0-7
- **참조:** PRD §6.1, §6.3(뱃지 표), §9
- **산출물:** `src/features/tracks/{TrackList,TrackRow,StatusBadge}.tsx`, `src/hooks/useIntersectionObserver.ts`, 테스트
- **완료 조건**
  - [x] 행이 썸네일, 제목(굵게), 가수, 재생 시간을 표시한다. `artworkUrl`이 `null`이거나 이미지 `onError`면 기본 썸네일이 보인다.
  - [x] 뱃지: `PENDING`/`PROCESSING` → `변환 중...`, `FAILED` → `변환 실패`(경고색 + 텍스트), `READY` → 없음.
  - [x] 첫 로딩은 스켈레톤, 결과가 0건이면 "검색 결과 없음"(키워드 있음)과 "업로드된 곡 없음"(키워드 없음) 문구가 구분되어 나온다.
  - [x] 센티널이 보이면(IntersectionObserver 모킹) 다음 페이지를 로드하고, `hasNext=false`면 더 로드하지 않는다. 같은 페이지를 중복 요청하지 않는다.
  - [x] 제목에 `<script>` 같은 문자열이 와도 텍스트로 렌더링된다.
- **주의**
  - 구현: 다운로드·재생 버튼 자리는 prop(콜백)으로 두고, 실제 연결은 T4·T5가 한다. `fetchNextPage`는 `isFetchingNextPage` 중에는 호출하지 않는다.
  - 검토: 행 전체가 클릭 영역이면서 내부 버튼이 있으므로 키보드 접근(Enter/Space)과 중첩 인터랙티브 요소 경고가 없는지 확인한다.

#### T2-3. SearchBar, useDebouncedValue

- **목표:** 300ms 디바운스 검색 입력을 목록 쿼리에 연결한다.
- **선행:** T2-1
- **참조:** PRD §6.2
- **산출물:** `src/features/tracks/SearchBar.tsx`, `src/hooks/useDebouncedValue.ts`, 테스트
- **완료 조건**
  - [x] 가짜 타이머로 입력 후 299ms에는 쿼리 키가 바뀌지 않고 300ms에 바뀐다.
  - [x] 앞뒤 공백은 제거되어 쿼리에 반영되고, 공백만 입력하면 전체 조회(키워드 없음)가 된다.
  - [x] 입력창에 `maxLength=200`이 있고 placeholder가 `노래 제목 또는 가수를 검색하세요...`이다.
  - [x] 입력창에 접근 가능한 이름(`aria-label` 또는 label)이 있다.
- **주의**
  - 구현: 한글 IME 조합 중(`compositionstart`~`compositionend`)에 중간 값으로 검색하지 않도록 확인한다.

#### T2-4. 변환 상태 폴링

- **목표:** 변환 중인 곡의 상태를 5초마다 갱신하고 목록 뱃지에 즉시 반영한다.
- **선행:** T2-2
- **참조:** PRD §6.3, §3.2
- **산출물:** `src/features/tracks/useTrackStatusPolling.ts`, `TrackRow` 연결, 테스트
- **완료 조건**
  - [x] `PENDING`/`PROCESSING` 행만 5초마다 `GET /api/tracks/{id}`를 호출하고(가짜 타이머), `READY`·`FAILED` 행은 호출하지 않는다.
  - [x] 응답의 상태가 바뀌면 `setQueriesData({ queryKey: ['tracks'] })`로 캐시를 갱신해 뱃지가 즉시 바뀌고, 목록 전체를 다시 요청하지 않는다(MSW 호출 횟수 검증).
  - [x] `READY`/`FAILED` 도달 시 폴링이 멈춘다. 행이 언마운트되면 멈춘다.
  - [x] `404`면 폴링을 멈추고 `['tracks']`를 무효화한다.
  - [x] 폴링 시작 후 30분이 지나면 멈추고 `상태 새로고침` 버튼이 나타나며, 누르면 1회 조회 후 폴링을 재개한다.
- **주의**
  - 탐색: v5에서 `refetchInterval`의 콜백은 `query`만 받는다(구버전의 `(data, query)`가 아님). Context7로 시그니처를 확인한다.
  - 구현: `refetchIntervalInBackground`는 기본값(false)을 유지한다. 새로고침 후에도 목록의 `status`로 폴링이 자동 재개되어야 한다.
  - 검토: 행마다 `useQuery`가 생기므로 `READY` 행은 `enabled: false`로 쿼리가 만들어지지 않는지, 메모리 누수 없이 정리되는지 확인한다.

---

## Phase 3: 업로드 (PRD F3)

목표: 로그인 사용자가 음원을 업로드하고(태그 자동 채우기, 진행률, 취소) 목록에 `변환 중...`으로 나타난다.

#### T3-1. readAudioTags, 업로드 사전 검증, FormData 빌더

- **목표:** 브라우저 태그 추출, 클라이언트 사전 검증, 빈 값을 보내지 않는 FormData 생성 로직을 UI 없이 만든다.
- **선행:** T0-5
- **참조:** PRD §5.1~§5.3
- **산출물:** `src/features/upload/{readAudioTags,validateUpload,buildUploadForm}.ts`, 테스트
- **완료 조건**
  - [x] `readAudioTags`가 태그 있음(값 trim), 태그 없음(전부 `null`), 파싱 예외(빈 결과, throw 안 함) 3가지를 `vi.mock('music-metadata')`로 검증한다.
  - [x] `validateUpload`: 음원 100MB 초과, 확장자 `.mp3/.wav/.flac/.m4a` 외, `title` 200자·`artist` 150자·`album` 200자 초과, 앨범자켓 10MB 초과·JPEG/PNG 외를 각각 오류로 반환한다.
  - [x] `buildUploadForm`이 `file`과 **값이 있는** `title/artist/album/artworkFile`만 추가한다(공백만 있는 값은 제외, 테스트로 키 목록 검증).
  - [x] `music-metadata`를 정적 import하는 코드가 없다(`grep`으로 확인).
- **주의**
  - 구현: 동적 import(`await import('music-metadata')`)만 쓴다. 내장 커버는 `selectCover` → `Blob`으로 만들되 **전송 대상으로 반환하지 않고 미리보기용 필드로만** 둔다.
  - 검토: `npm run build` 후 초기 진입 청크에 music-metadata가 포함되지 않았는지 산출물로 확인한다(최종 점검은 T5-3).

#### T3-2. UploadModal UI

- **목표:** 파일 선택 → 태그 채움 → 미리보기가 있는 업로드 모달 화면을 만든다(전송 로직은 T3-3).
- **선행:** T3-1, T1-4, T0-8
- **참조:** PRD §5.1, §5.2, §5.3
- **산출물:** `src/features/upload/UploadModal.tsx`(+ `React.lazy` 래퍼), 프로필 팝오버 `업로드` 연결, 테스트
- **완료 조건**
  - [x] 업로드 모달 컴포넌트가 `React.lazy`로 분할되어 있고, 프로필 팝오버의 `업로드`를 눌렀을 때만 로드된다.
  - [x] 파일을 고르면 태그가 있는 필드는 **값으로 채워지고**, 태그가 없는 필드는 **비어 있고 placeholder만** 보인다(제목: 파일명(확장자 제외), 가수: `Unknown Artist`).
  - [x] 태그 파싱 실패여도 오류 표시 없이 위 "값 없음"과 동일하게 동작하고 저장은 막히지 않는다.
  - [x] 내장 커버가 있으면 미리보기로 표시되고, 모달을 닫으면 `URL.revokeObjectURL`이 호출된다. 커버가 없으면 음표 플레이스홀더가 보인다.
  - [x] 사용자가 커버 영역에서 JPEG/PNG를 직접 고른 경우에만 `artworkFile`이 전송 대상이 되고, 내장 커버는 전송 대상이 아니다(`buildUploadForm` 입력 검증 테스트).
  - [x] 검증 오류(크기·형식)가 해당 필드 근처에 인라인으로 표시된다.
- **주의**
  - 계획: **내장 커버를 `artworkFile`로 보내지 않는다**(PRD §5.2, §16 #11). 서버가 음원에서 직접 추출하고, 보내면 서버의 우선순위(사용자 첨부 > 내장)를 어긴다. 가장 놓치기 쉬운 부분이다.
  - 구현: 빈 칸에 `'Unknown Artist'`를 **값으로** 채우지 않는다(PRD §16 #10, 서버 ID3 fallback 보존).

#### T3-3. useUploadTrack: 진행률, 취소, 결과 처리

- **목표:** 업로드 전송, 진행률 표시, 취소, 성공·오류 처리를 완성한다.
- **선행:** T3-2, T2-1
- **참조:** PRD §5.4, §3.4
- **산출물:** `src/features/upload/useUploadTrack.ts`, `src/api/tracks.ts`(`uploadTrack` 추가), 모달 연결, 테스트
- **완료 조건**
  - [x] 전송 중 진행률(%)이 표시되고 `[저장]`이 비활성화된다.
  - [x] 취소 버튼이 `AbortController`로 요청을 중단하고 모달이 편집 상태로 돌아온다.
  - [x] 전송 중 모달 닫기 시도(ESC·배경 클릭·닫기 버튼)는 확인 절차를 거친다(T0-8의 `onRequestClose`).
  - [x] `202` 수신 시 모달이 닫히고 `['tracks']`가 무효화되어 새 곡이 `변환 중...`으로 나타난다(MSW).
  - [x] `400 INVALID_AUDIO_FORMAT`, `400 INVALID_ARTWORK`, `413`이 PRD §3.4 문구로 모달 안에 인라인 표시되고 입력값이 유지된다.
  - [x] 업로드 요청에 시간 제한이 없다(`apiClient` 기본 30초를 요청별 `timeout: 0`으로 해제, axios에서 0은 무제한).
- **주의**
  - 구현: 진행률 이벤트(`onUploadProgress`)는 jsdom에서 흉내 내기 어렵다. 어려우면 axios 어댑터를 테스트에서 교체해 이벤트를 직접 발생시킨다. `Content-Type`은 axios가 `multipart` 경계를 붙이도록 직접 지정하지 않는다.
  - 검토: 취소·실패 후 재시도가 가능한지, 성공 후 모달 상태가 초기화되는지 확인한다.

---

## Phase 4: 플레이어 (PRD F4)

목표: 하단 고정 플레이어로 HLS 곡을 재생한다. T4-1은 UI 없이 T0-4 직후 시작할 수 있다.

#### T4-1. attachHlsStream, 정리 함수

- **목표:** hls.js 연결과 fatal 에러 복구, Safari 네이티브 분기, 정리 함수를 UI와 분리해 만든다.
- **선행:** T0-4
- **참조:** PRD §7.2
- **산출물:** `src/features/player/attachHlsStream.ts`, 테스트
- **완료 조건**
  - [x] 미디어 fatal 에러가 오면 `recoverMediaError`를 호출하고, 5초 이내에 다시 오면 호출하지 않고 `destroy` + `onFatalError`로 간다(가짜 타이머).
  - [x] 네트워크 fatal 에러는 `startLoad`를 정확히 1회 시도하고, 두 번째에는 `destroy` + `onFatalError`를 호출한다.
  - [x] 비치명(`fatal: false`) 에러는 아무것도 하지 않는다.
  - [x] `Hls.isSupported()`가 false이고 `canPlayType('application/vnd.apple.mpegurl')`가 참이면 `audio.src`를 직접 설정하고 `null`을 반환한다. 둘 다 아니면 `onFatalError`를 호출한다.
  - [x] `detachStream(audio, hls)`가 `hls.destroy()`, `removeAttribute('src')`, `load()`를 순서대로 호출한다.
- **주의**
  - 탐색: hls.js 1.7의 `Hls.Events.ERROR`, `ErrorTypes`, `recoverMediaError`, `startLoad` 사용법을 Context7로 확인한다. 네트워크 에러 직후 즉시 재개를 반복하면 루프 위험이 있다는 문서 경고가 있다(PRD §16 #13).
  - 구현: `maxBufferLength: 30`. PRD §7.2의 코드를 기준으로 하되 테스트 가능하게 `Hls`를 주입 가능하게 만들어도 된다.

#### T4-2. PlayerProvider·usePlayer

- **목표:** 앱 루트에서 `<audio>` 하나를 소유하고 재생 상태 머신, `/play` 호출 규칙, 경합 처리를 제공한다.
- **선행:** T4-1, T2-1
- **참조:** PRD §7.1, §7.2, §3.4(409)
- **산출물:** `src/features/player/{PlayerProvider.tsx,usePlayer.ts}`, `src/api/tracks.ts`(`getPlayInfo` 추가), 테스트
- **완료 조건**
  - [x] `READY` 곡의 재생 시작 1회당 `GET /api/tracks/{id}/play`가 정확히 1번 호출된다. 일시정지·재개·시크·반복재생·재렌더에서는 호출되지 않는다(MSW 호출 횟수).
  - [x] 곡을 연속 클릭하면 마지막 요청의 결과만 사용되고 늦게 도착한 이전 응답은 폐기된다(`requestId`, 지연 응답 테스트).
  - [x] `409 TRACK_NOT_READY`면 토스트가 나오고 해당 트랙이 재조회(`['track', id]` 무효화)된다.
  - [x] `audio.play()`가 `NotAllowedError`로 거부되면 오류 토스트 없이 `paused` 상태가 된다.
  - [x] `isPlaying`은 `audio`의 `play`/`pause` 이벤트로만 갱신된다(단일 출처).
  - [x] 곡을 바꾸거나 언마운트하면 이전 Hls 인스턴스가 `destroy`된다.
  - [x] `streamUrl`은 상대경로·절대 URL 모두 가공 없이 그대로 사용된다.
- **주의**
  - 계획: `<audio>`는 `PlayerProvider`가 소유하는 단 하나이며 라우트 이동에 영향받지 않아야 한다. 상태는 `idle|loading|playing|paused|error`.
  - 구현: 재생 시작은 `MANIFEST_PARSED`(hls.js) 또는 `loadedmetadata`(Safari) 이후 `play()`를 호출한다. 호출마다 `STREAM` 이력이 서버에 쌓이므로 `/play` 호출 위치는 코드 한 곳으로 제한한다.
  - 검토: `audio`와 `Hls`는 모킹한다. 실제 재생 확인은 T6-2에서 한다.

#### T4-3. BottomPlayerBar: 재생·진행·시간

- **목표:** 하단 고정 플레이어의 기본 컨트롤(재생/일시정지, 진행 슬라이더, 시간)과 행 연결을 만든다.
- **선행:** T4-2, T0-8
- **참조:** PRD §7.1, §7.3, §6.3, §9.1
- **산출물:** `src/features/player/BottomPlayerBar.tsx`, `TrackRow` 재생 연결, 테스트
- **완료 조건**
  - [x] 곡이 선택되기 전에는 바가 렌더링되지 않고, 표시 중에는 본문 하단 패딩이 확보되어 마지막 행이 가려지지 않는다.
  - [x] 곡 정보(썸네일·제목·가수), 재생/일시정지 토글, `01:15 / 03:40` 형식의 시간이 표시된다.
  - [x] 진행 슬라이더는 드래그 중에는 `audio.currentTime`을 바꾸지 않고, 놓을 때 한 번 반영한다.
  - [x] 길이는 `durationSeconds`로 초기화하고 `loadedmetadata` 이후 `audio.duration`으로 보정한다.
  - [x] `READY` 행 클릭은 재생을 시작하고 재생 중 행이 강조된다. `PENDING`/`PROCESSING` 행 클릭은 `/play` 호출 없이 안내 토스트, `FAILED` 행은 "변환에 실패한 곡입니다" 토스트가 나온다.
  - [x] `status='error'`이면 재생 버튼이 비활성화된다.
- **주의**
  - 구현: `audio`의 `timeupdate`를 상태로 올리면 렌더가 잦으므로 진행 표시만 구독하는 구조를 고려한다.
  - 검토: 모든 아이콘 버튼에 `aria-label`이 있는지 확인한다.

#### T4-4. 볼륨·음소거·반복·키보드·Media Session

- **목표:** 나머지 플레이어 컨트롤을 완성한다.
- **선행:** T4-3
- **참조:** PRD §7.3, §9.3
- **산출물:** `BottomPlayerBar` 확장, `src/features/player/playerPreferences.ts`, 테스트
- **완료 조건**
  - [x] 볼륨(0.0~1.0)·음소거가 `localStorage`(`player.volume`, `player.muted`)에 저장되고 새로 마운트할 때 복원된다. 저장된 값이 손상(숫자 아님·범위 밖)이면 기본값을 쓴다.
  - [x] 스피커 아이콘 클릭이 음소거를 토글한다(`aria-pressed` 등 상태 노출).
  - [x] 반복재생 토글이 `audio.loop`을 바꾸고 활성 시 강조색이 된다. 반복 중 `/play`는 다시 호출되지 않는다.
  - [x] 포커스가 입력창(`input`, `textarea`, `contenteditable`)이 아닐 때만 `Space`가 재생/일시정지를 토글하고, 입력창에서는 동작하지 않는다.
  - [x] 폭 360px에서 볼륨 슬라이더가 숨겨진다(CSS 또는 컴포넌트, 확인 방법 기록).
  - [x] (선택) `navigator.mediaSession.metadata`에 제목·가수·아트워크를 설정한다. 미지원 환경에서도 오류가 나지 않는다.
- **주의**
  - 구현: `localStorage` 읽기·쓰기는 항상 `try/catch`로 감싸 실패해도 앱이 동작하게 한다. 버튼 위에서 `Space`를 누르면 버튼 기본 동작과 충돌하지 않게 한다.

---

## Phase 5: 다운로드·마감 (PRD F5)

#### T5-1. 원본 다운로드 `<a download>`

- **목표:** 행과 플레이어에서 원본 파일을 브라우저 네이티브 방식으로 내려받는다.
- **선행:** T2-2, T4-3
- **참조:** PRD §8
- **산출물:** `src/lib/download.ts`, 행·플레이어 다운로드 버튼 연결, 테스트
- **완료 조건**
  - [x] `downloadTrack(id)`가 `href`가 `${API_BASE}/api/tracks/{id}/download`이고 `download` 속성이 있는 숨김 앵커를 만들어 클릭한 뒤 DOM에서 제거한다(테스트로 href 검증).
  - [x] 행의 다운로드 버튼 클릭은 `stopPropagation`으로 재생을 시작하지 않는다(`/play` 미호출 테스트).
  - [x] `PENDING`, `PROCESSING`, `READY`, `FAILED` 모든 상태에서 버튼이 활성화되어 있다.
  - [x] 플레이어 바의 다운로드 버튼이 현재 곡을 내려받는다.
  - [x] 코드에 `iframe`·`fetch`/`axios`로 파일을 읽는 다운로드 구현이 없다.
- **주의**
  - 계획: iframe·`Blob` 방식은 쓰지 않는다. Spring 기본 `X-Frame-Options: DENY`가 iframe을 막을 수 있고, 100MB 파일을 JS 메모리에 올리게 된다(PRD §8).
  - 검토: 이 방식은 `Authorization` 헤더를 실을 수 없어 `DOWNLOAD` 이력이 익명으로 남는다. 이는 의도된 MVP 한계이니 "고치지" 않는다(PRD §17).

#### T5-2. 접근성·반응형 마감

- **목표:** 접근성·반응형 요구사항을 전수 점검하고 보정한다.
- **선행:** T5-1, T3-3
- **참조:** PRD §9.3, §14
- **산출물:** 보정 코드, 접근성 테스트
- **완료 조건**
  - [x] RTL 테스트가 앱의 모든 아이콘 버튼을 `getByRole('button', { name })`으로 찾을 수 있다(이름 없는 버튼 0개).
  - [x] 모달을 닫으면 모달을 연 요소로 포커스가 돌아간다(로그인·업로드 둘 다).
  - [x] 폭 360px에서 헤더·목록·플레이어 바·모달이 가로 스크롤 없이 사용 가능하다(Playwright MCP 스크린샷으로 확인).
  - [x] 상태가 색상만으로 전달되지 않는다(뱃지에 텍스트 포함).
  - [x] 키보드만으로 로그인 모달 열기, 목록 행 재생, 플레이어 제어가 가능하다.
- **주의**
  - 검토: 스킬 `web-design-reviewer`, `anti-ui-slop`을 활용해 화면을 점검하고, 발견 사항 중 이 태스크 범위 밖은 "후속 메모"로 남긴다.

#### T5-3. 안정성·보안·번들 점검

- **목표:** 오류 격리, 보안 규칙, 번들 분할이 의도대로인지 점검하고 부족하면 고친다.
- **선행:** T5-2
- **참조:** PRD §14, §5.3
- **산출물:** 보정 코드, 점검 결과 기록
- **완료 조건**
  - [x] 플레이어 바와 목록이 각각 `ErrorBoundary`로 감싸져 한쪽이 렌더 오류를 내도 나머지가 동작한다(테스트).
  - [x] `src/`에서 `dangerouslySetInnerHTML`이 0건이다(`grep`).
  - [x] 토큰을 `console.*`에 넘기는 코드가 0건이고, 토큰이 URL·토스트·에러 메시지에 나타나는 경로가 없다(코드 점검 + `grep`).
  - [x] `target="_blank"` 외부 링크에 `rel="noopener noreferrer"`가 있다.
  - [x] `npm run build` 산출물에서 초기 진입 청크에 `music-metadata`와 `UploadModal`이 없고 별도 청크로 분리되어 있다(청크 파일 목록 기록).
- **주의**
  - 검토: 스킬 `security-review`, `secret-scanning`을 활용한다. `VITE_*`에 시크릿성 값이 없는지 확인한다.

---

## Phase 6: E2E·통합 (PRD F6)

전제: 전체 docker 스택(Nginx 80, 백엔드, RustFS, PostgreSQL)이 `http://localhost`에서 실행 중이어야 한다. 에이전트가 스택을 띄울 수 없으면 사용자에게 요청한다.

#### T6-1. Playwright 설정, JWT 주입 헬퍼

- **목표:** 전체 스택을 대상으로 한 E2E 환경과 로그인 상태 주입을 만든다.
- **선행:** T5-3
- **참조:** PRD §13(E2E)
- **산출물:** `playwright.config.ts`, `e2e/helpers/auth.ts`, 스모크 테스트, `.env.example`에 E2E 변수 추가
- **완료 조건**
  - [ ] `npx playwright test`가 실행되고 스모크 1건(메인 화면 로드, 목록 영역 표시)이 통과한다.
  - [ ] 헬퍼가 환경변수 `E2E_JWT_SECRET_KEY`(테스트 스택의 `JWT_SECRET_KEY`)로 JWT를 발급해 `localStorage['auth.token']`에 주입하고, 주입 후 아바타가 보인다.
  - [ ] 시크릿 값이 저장소의 어떤 파일에도 없다(`grep`, `.env`는 `.gitignore` 대상).
- **주의**
  - 계획: 빌드 산출물(`../frontend-dist`)을 Nginx가 서빙하므로 E2E 전에 `npm run build`가 필요하다. 이 의존을 README·스크립트에 명시한다.
  - 구현: JWT 서명용 라이브러리는 `devDependencies`에만 둔다. 만료 시각을 충분히 길게 발급한다.

#### T6-2. Milestone 1 시나리오

- **목표:** 업로드부터 다운로드까지 핵심 사용자 흐름을 E2E로 검증한다.
- **선행:** T6-1
- **참조:** PRD §13(E2E), §6.3, §7, §8
- **산출물:** `e2e/milestone1.spec.ts`, 샘플 음원 파일
- **완료 조건**
  - [ ] 샘플 MP3 업로드 → 목록에 `변환 중...` 표시 → 폴링으로 뱃지 소멸(`READY`)이 확인된다.
  - [ ] 재생 클릭 후 `/stream/` 청크 요청이 관찰되고 `audio.currentTime`이 증가한다.
  - [ ] 반복재생 토글 후 곡이 끝나도 계속 재생되고 `/play`가 추가로 호출되지 않는다(네트워크 로그).
  - [ ] 다운로드가 한글 포함 원본 파일명으로 저장되고 바이트 크기가 업로드한 파일과 같다.
- **주의**
  - 구현: FFmpeg 변환을 실제로 거치므로 `READY` 대기 상한을 넉넉히 둔다(소형 샘플은 수 초). 샘플 음원은 직접 만든 무음·톤 파일 등 라이선스 문제가 없는 것만 쓰고 크기를 작게 유지한다.
  - 검토: 테스트가 업로드한 곡이 DB·스토리지에 남는다. 정리 방법이 없으면 사용자에게 알린다(백엔드 삭제 API는 없다).

#### T6-3. 통합 확인·수동 테스트 기록

- **목표:** 문서만으로 확정할 수 없는 항목을 실제 스택에서 확인하고 결과를 기록한다.
- **선행:** T6-2
- **참조:** PRD §17, §15
- **산출물:** PRD §17 갱신, 필요한 경우 PRD §15 요청 추가
- **완료 조건**
  - [ ] PRD §17의 확인 항목마다 결과(통과/실패/미확인과 근거)를 기록한다: ① Nginx 경유 다운로드의 `Content-Disposition` 한글 파일명과 presigned 쿼리 보존, ② `changeOrigin` 개발 서버 로그인의 `redirect_uri` 계산, ③ 시크 시 `Range`·캐시 정상 여부와 반복재생 끊김, ④ Safari 네이티브 HLS, ⑤ 모바일 폭 레이아웃, ⑥ Google 로그인 5회 이상 반복.
  - [ ] 실패·미확인 항목은 원인을 적고, 백엔드·인프라 변경이 필요한 것은 PRD §15에 요청으로 추가한다(이 저장소에서 고치지 않는다).
  - [ ] 확인 불가능했던 항목(환경 부재 등)은 "미확인"으로 명시하고 사유를 적는다.
- **주의**
  - 계획: Google 로그인 전체 흐름과 Safari는 사람이 직접 해야 한다. 에이전트는 체크리스트와 기록 틀을 만들고 사용자에게 수행을 요청한다.
  - 검토: 결과를 지어내지 않는다. 직접 확인하지 못한 것은 통과로 적지 않는다.

---

## 부록: 외부 선행 조건 (PRD §15, 이 저장소에서 구현하지 않음)

| 요청 | 담당 | 막히는 태스크 |
|---|---|---|
| 백엔드 `OAUTH2_ALLOWED_REDIRECT_URIS`에 `http://localhost:5173/auth/callback` 추가 | 백엔드 환경변수 | T1-3, T6-3의 개발 서버 로그인 수동 확인 |
| Nginx 접근 로그에서 `/auth/callback`의 `token` 쿼리 마스킹 | 인프라 | 운영 배포 전(개발 태스크는 막히지 않음) |
| 다운로드 응답의 `X-Accel-Redirect`·`Content-Disposition` 유지 확인 | 인프라 통합 테스트 | T6-2의 다운로드 검증, T6-3 ① |
| SPA 정적 서빙 시 CSP·보안 헤더 검토(`media-src blob:`) | 인프라 | T6-2의 재생 검증(CSP 적용 시) |
| `../frontend-dist` 마운트와 `try_files … /index.html` 유지 | 인프라 | T6-1, T6-2(콜백 경로 새로고침) |
| 전체 docker 스택 기동 | 사용자 | Phase 6 전체 |
