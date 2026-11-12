# [PRD] 웹 프론트엔드 (React SPA) 상세 설계 (v1.1)

> **작성일:** 2026-11-12 · **v1.1 변경 요약 (2026-11-12):** `PRD-frontend.md` → `PRD.md` 개명(이 저장소의 메인 기준 문서). 백엔드 문서(인덱스·ROADMAP) 참조를 내용으로 대체하고, 런타임을 로컬 환경(Node 26, fnm)에 맞춤. 상세는 §16 #17.
> **목적:** 구현이 끝난 백엔드(PRD-05, 2026-11-12 백엔드 스모크 테스트까지 검증)의 **실제 계약**에 맞춘 웹 프론트엔드의 단일 기준 문서입니다. `PRD-02`(웹페이지 초안)를 대체하며, `PRD-02`와 달라진 점은 §16에 기록합니다. `PRD-02`는 수정하지 않습니다.
> **문서 우선순위:** API 명세(`.claude/docs/API.md`, 구 백엔드 README) > `PRD-05.md`(백엔드) > `PRD-04.md`(Nginx 경로) > 이 문서 > `PRD-02.md`. 충돌이 발견되면 임의로 판단하지 말고 사용자에게 확인한 뒤 §16에 기록합니다.
> **참조 표기 주의:** `PRD-01`~`PRD-07` 머리말의 "`PRD.md` §7 참조"는 **이 문서가 아니라 구 백엔드 인덱스**의 결정 이력을 뜻합니다. 원본은 백엔드 저장소의 `.claude/docs/PRD.md`에 있습니다. 프론트엔드에 필요한 내용은 이 문서 §15·§17에 옮겨 두었습니다.

## 1. 개요 및 범위

### 1.1. 제품 범위

온프레미스 음원 스트리밍·아카이빙 MVP의 **웹 클라이언트(SPA)**입니다. 단일 오리진(Nginx `80`)에서 백엔드 API, HLS 스트림, 앨범아트와 함께 서빙됩니다. 디자인 레퍼런스는 YouTube Music 다크 테마입니다(PRD-02 §2).

| 영역 | 기능 |
|---|---|
| 인증 | Google 로그인(리다이렉트), JWT 보관, 프로필 아바타, 로그아웃 |
| 업로드 | 로그인 사용자의 음원 업로드(태그 자동 채우기, 앨범자켓 교체, 진행률) |
| 목록·검색 | 최신순 무한 스크롤, 제목·가수 키워드 검색(300ms 디바운스), 변환 상태 뱃지·자동 갱신 |
| 재생 | 하단 고정 플레이어(hls.js), 시크·볼륨·반복재생 |
| 다운로드 | 원본 파일 다운로드(브라우저 네이티브) |

### 1.2. 이 저장소가 하는 일과 하지 않는 일

* **한다:** SPA 소스 구현, 빌드 결과물(`dist`)을 PRD-04가 마운트하는 `../frontend-dist`로 출력, 단위·컴포넌트·E2E 테스트.
* **하지 않는다:** Nginx 설정·`docker-compose.yml`(인프라 소관), 백엔드 코드 변경, 모바일 앱(PRD-03). 필요한 인프라·백엔드 변경은 구현하지 않고 §15에 요청 사항으로만 기록합니다.

## 2. 기술 스택

대중성 > 사용 난이도 > 성능 순으로 선정하며, 정확한 버전은 `package.json`에 고정합니다. Context7로 확인한 항목은 확인 버전을 적었고, 나머지는 T0-1(골격 태스크)에서 설치 시점의 안정판을 확인한 뒤 기록합니다.

| 구분 | 선정 | 확인 버전 | 역할 및 선정 사유 |
|---|---|---|---|
| 런타임 | **Node.js 26** | 26 (LTS, 로컬 v26.13.0) | fnm으로 관리하고 `.node-version`으로 고정. PRD-02의 Node 20은 지원 종료(2026-04)되어 상향. Vite 요구(20.19+ / 22.12+)도 충족. **2026-10-28 LTS(Lithium) 전환 확인**(공식 릴리스 일정: 유지보수 2027-10-20, 지원 종료 2029-04-30) |
| 프레임워크 | **React 19 + TypeScript(strict)** | react 19.3.1, react-dom 19.3.1, TypeScript **6.0.3** | 백엔드 DTO·에러 코드를 타입으로 고정해 계약 변경을 컴파일 단계에서 검출. TypeScript는 npm `latest`가 7.0.2(네이티브 구현)이지만 `typescript-eslint`의 peer 범위가 `<6.1.0`이라 T0-2의 ESLint와 충돌하므로 6.x 최신인 6.0.3으로 고정(§16 #18) |
| 빌드 | **Vite** | 8.3.8 (`@vitejs/plugin-react` 6.3.0) | HMR, `server.proxy`, 정적 번들 |
| 서버 상태 | **TanStack Query v5** | 5.107.1 | 무한 스크롤(`useInfiniteQuery`), 변환 상태 폴링(`refetchInterval`), 업로드 후 무효화 |
| 라우팅 | **React Router** (library mode) | 7.18.5 (`react-router` 패키지 하나만 사용, `react-router-dom` 금지) | 라우트는 `/`, `/auth/callback` 2개. npm `latest`는 8.5.1이나 Context7 문서가 7.x까지만 있어 library mode 사용법을 검증할 수 없고 Node `>=22.22`·React `>=19.2.7`을 요구하므로 7.x 최신(`version-7` 태그)을 선택(§16 #19) |
| HTTP | **axios** | 1.21.1 | 인터셉터(Bearer), 업로드 진행률(`onUploadProgress`), 취소(`AbortController`) |
| HLS | **hls.js** | 1.7.4 (`npm view`로 1.7.x 최신 확인, 정확한 버전 고정) | 크롬·엣지·파이어폭스에서 `.m3u8` 재생 |
| 태그 파서 | **music-metadata** | 12.4.0 (ESM, node >=22, peer 없음을 `npm view`로 확인) | `parseBlob`으로 브라우저에서 MP3/WAV/FLAC/M4A 태그·내장 커버 추출. 동적 import(§5.3). PRD-02의 `jsmediatags`를 대체 |
| 아이콘 | **lucide-react** | 1.72.0 (React 19 peer 허용 확인) | 재생·일시정지·볼륨·반복·다운로드·검색 |
| 스타일 | **CSS Modules + CSS 변수 토큰** | - | 별도 UI 프레임워크 없이 다크 팔레트를 토큰으로 관리 |
| 단위·컴포넌트 테스트 | **Vitest + React Testing Library + MSW** | vitest 5.1.0, jsdom 31.0.0, msw 3.0.5, @testing-library/react 16.3.3·dom 10.4.2·jest-dom 7.0.1·user-event 14.6.10 (peer가 TS 6.0.3·Vite 8.3.8·React 19.3.1을 허용함을 `npm view`로 확인) | 백엔드 없이 API 응답을 모킹 |
| E2E | **Playwright** | - | 전체 docker 스택에서 Milestone 1 시나리오 검증 |
| 품질 | **ESLint + Prettier** | eslint 10.14.0, typescript-eslint 8.72.2, eslint-plugin-react-hooks 7.1.1, eslint-plugin-react-refresh 0.5.7, eslint-config-prettier 10.1.8, prettier 3.10.1 (peer 범위가 TS 6.0.3·ESLint 10을 허용함을 `npm view`로 확인) | 들여쓰기 4칸, 작은따옴표 |

**코딩 규칙:** 들여쓰기 4칸, 변수·함수 camelCase, 함수명은 동사로 시작(`getTracks`, `handleClick`), 컴포넌트는 PascalCase, 코드 주석·문서는 한국어, 식별자는 영어.

## 3. 백엔드 계약 요약

### 3.1. 경로와 Nginx 라우팅 (PRD-04)

| 경로 | 처리 | 프론트엔드 사용 |
|---|---|---|
| `/api/*`, `/oauth2/*`, `/login/oauth2/*` | 백엔드 | REST 호출, 로그인 진입 |
| `/stream/*` | Nginx → RustFS(`hls/`) | hls.js 재생 (`streamUrl`) |
| `/artwork/*` | Nginx → RustFS(`artwork/`) | `<img src={artworkUrl}>` |
| `/internal-storage/*` | Nginx 내부 전용 | **직접 호출 금지** (`404`) |
| 그 외 | SPA 정적 파일 (`try_files ... /index.html`) | `/`, `/auth/callback` |

**SPA 라우트로 쓸 수 없는 경로:** `/api`, `/oauth2`, `/login/oauth2`, `/stream`, `/artwork`, `/internal-storage` 접두 경로. 웹 로그인 콜백이 `/oauth2/...`가 아닌 `/auth/callback`인 이유가 이것입니다(PRD-05 §6.1).

### 3.2. 엔드포인트

| 메서드 | 경로 | 인증 | 성공 | 프론트엔드 용도 |
|---|---|:---:|:---:|---|
| GET | `/oauth2/authorization/google?redirect_uri=` | - | 302 | 로그인 진입 (페이지 이동) |
| GET | `/api/auth/me` | **필수** | 200 | 로그인 사용자·아바타 |
| POST | `/api/tracks/upload` | 선택 | 202 | 업로드 (UI는 로그인 사용자만 노출) |
| GET | `/api/tracks` | 선택 | 200 | 목록·검색 |
| GET | `/api/tracks/{trackId}` | 선택 | 200 | 변환 상태 폴링 |
| GET | `/api/tracks/{trackId}/play` | 선택 | 200 | 스트리밍 진입점 (`STREAM` 이력 기록) |
| GET | `/api/tracks/{trackId}/download` | 선택 | 200 | 원본 다운로드 (`DOWNLOAD` 이력 기록) |

* `/api/auth/me`를 제외한 모든 API는 `permitAll`입니다. 무효·만료 토큰이어도 **차단되지 않고 익명으로 처리**되므로, 401은 `/api/auth/me`에서만 발생합니다.
* 목록 쿼리: `keyword`(trim 후 200자 초과 `400`, 빈 값은 전체), `page`(0 이상, 기본 0), `size`(1 이상, 기본 20, 100 초과는 100으로 보정), `status`(대소문자 구분 enum, 잘못된 값 `400`). 정렬은 `createdAt DESC` 고정입니다.
* 프론트엔드는 `status` 필터를 사용하지 않으며 모든 상태의 트랙이 목록에 포함됩니다.
* `/download`는 상태와 무관하게(`PENDING` 포함) 허용됩니다. `/play`는 `READY`만 성공하고 그 외는 `409 TRACK_NOT_READY`입니다.

### 3.3. 타입 정의 (`src/api/types.ts`)

```ts
export type TrackStatus = 'PENDING' | 'PROCESSING' | 'READY' | 'FAILED';

export interface TrackResponse {
    trackId: string; // UUID
    title: string;
    artist: string;
    album: string | null;
    durationSeconds: number; // 최소 1
    status: TrackStatus;
    artworkUrl: string | null; // 상대경로 또는 절대 URL (MEDIA_PUBLIC_BASE_URL)
    originalFilename: string;
    fileExtension: 'mp3' | 'wav' | 'flac' | 'm4a';
    fileSizeBytes: number;
    createdAt: string; // UTC ISO-8601 (...Z)
}

export interface TrackPageResponse {
    content: TrackResponse[];
    page: number;
    size: number;
    totalElements: number;
    totalPages: number;
    hasNext: boolean;
}

export interface StreamPlayResponse {
    trackId: string;
    streamUrl: string; // HLS 매니페스트. 상대경로 또는 절대 URL
    title: string;
    artist: string;
    durationSeconds: number;
    artworkUrl: string | null;
}

export interface UserResponse {
    userId: number;
    email: string;
    profileImageUrl: string | null;
    role: string; // 'ROLE_USER'
}

export type ErrorCode =
    | 'INVALID_AUDIO_FORMAT'
    | 'INVALID_ARTWORK'
    | 'INVALID_REQUEST'
    | 'UNAUTHORIZED'
    | 'TRACK_NOT_FOUND'
    | 'TRACK_NOT_READY'
    | 'PAYLOAD_TOO_LARGE'
    | 'INTERNAL_ERROR';

export interface ErrorResponse {
    code: ErrorCode;
    message: string;
    timestamp: string; // Asia/Seoul (+09:00). createdAt(UTC)과 표기가 다름
}
```

* `errorMessage`(내부 진단용)는 응답에 없습니다. 실패 여부는 `status === 'FAILED'`로만 판단합니다.
* 서버가 보내는 `message`는 그대로 노출하지 않고, 아래 표의 **클라이언트 메시지**를 사용합니다(문구 일관성, 향후 다국어 대비). 알 수 없는 `code`는 `INTERNAL_ERROR`와 같이 처리합니다.

### 3.4. 에러 → 사용자 메시지 매핑

| 상태 | `code` | 표시 메시지 | 표시 위치 |
|:---:|---|---|---|
| 400 | `INVALID_AUDIO_FORMAT` | 지원하지 않거나 손상된 음원 파일입니다. MP3, WAV, FLAC, M4A 파일을 선택해 주세요. | 업로드 모달 인라인 |
| 400 | `INVALID_ARTWORK` | 앨범자켓은 10MB 이하의 JPEG 또는 PNG 이미지만 사용할 수 있습니다. | 업로드 모달 인라인 |
| 400 | `INVALID_REQUEST` | 요청 내용을 확인해 주세요. (입력 길이 초과 등) | 업로드 모달 인라인 / 토스트 |
| 401 | `UNAUTHORIZED` | 로그인이 만료되었습니다. 다시 로그인해 주세요. | 토스트 + 비로그인 전환 |
| 404 | `TRACK_NOT_FOUND` | 존재하지 않는 곡입니다. 목록을 새로고침합니다. | 토스트 + 목록 무효화 |
| 409 | `TRACK_NOT_READY` | 아직 변환 중인 곡입니다. 잠시 후 다시 시도해 주세요. | 토스트 |
| 413 | `PAYLOAD_TOO_LARGE` | 파일이 너무 큽니다. 음원은 100MB, 앨범자켓은 10MB 이하여야 합니다. | 업로드 모달 인라인 |
| 500 | `INTERNAL_ERROR` | 서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요. | 토스트 |
| - | (네트워크 오류·타임아웃) | 서버에 연결할 수 없습니다. 네트워크를 확인해 주세요. | 토스트 |
| - | (hls.js 치명 오류·`audio` 오류·`play()` 거부(`NotAllowedError` 제외)) | 재생 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요. | 토스트 (`errorMessages.ts`의 `playbackErrorMessage`, §16 #34) |

axios 응답 인터셉터가 모든 오류를 `ApiError { status: number; code: ErrorCode | 'NETWORK_ERROR'; message: string }`로 정규화합니다. 본문이 `ErrorResponse` 형식이 아니면(예: Nginx `413`·`502` HTML) 상태 코드로 `code`를 추정합니다(`413 → PAYLOAD_TOO_LARGE`, 그 외 4xx → `INVALID_REQUEST`, 5xx → `INTERNAL_ERROR`).

**TanStack Query 재시도 정책:** `4xx`는 재시도하지 않고, `5xx`·네트워크 오류만 최대 2회 재시도합니다.

## 4. 인증 (Google 로그인 + JWT)

### 4.1. 로그인 진입

1. 헤더의 `[로그인]` 버튼 → 로그인 모달(구글 로고 + `"Sign with Google"` 버튼 1개).
2. 버튼 클릭 시 `window.location.assign(`${VITE_API_BASE_URL}/oauth2/authorization/google?redirect_uri=${encodeURIComponent(redirectUri)}`)`로 이동합니다.
3. `redirectUri` = `VITE_OAUTH_REDIRECT_URI`가 있으면 그 값, 없으면 `${window.location.origin}/auth/callback`.
4. **`redirectUri`는 백엔드 `OAUTH2_ALLOWED_REDIRECT_URIS`와 문자열 완전 일치**해야 합니다(대소문자·끝 슬래시·포트 포함). 불일치하면 토큰 없이 `?error=invalid_redirect_uri`로 돌아옵니다.

### 4.2. 콜백 라우트 (`/auth/callback`)

백엔드는 로그인 성공 시 `{redirect_uri}?token={jwt}`, 실패 시 `{redirect_uri}?error={code}`로 `302`합니다.

처리 순서(순서가 중요합니다):

1. `window.location.search`에서 `token`/`error`를 **먼저 읽는다**.
2. 즉시 `history.replaceState(null, '', '/auth/callback')`로 주소창에서 쿼리를 제거한다(주소 히스토리·화면 공유·Referer 노출 방지).
3. `token`이 있으면 `AuthContext.login(token)`을 호출한다(`localStorage`(`auth.token`) 저장 → `AuthProvider` 내부 토큰 상태 갱신 → `['me']` 무효화). 같은 탭은 `storage` 이벤트가 없어 직접 갱신해야 한다. `error`가 있으면 §4.4 표의 메시지로 토스트를 띄운다.
4. `navigate('/', { replace: true })`.

* **React StrictMode 대응:** 개발 모드는 effect를 두 번 실행하므로, 1~3단계는 `useRef` 가드로 **한 번만** 실행합니다(두 번째 실행에서는 이미 쿼리가 지워져 토큰을 잃는 문제 방지).
* `token`과 `error`가 모두 없으면(주소 직접 입력) 조용히 `/`로 이동합니다.

### 4.3. 토큰 사용과 세션 관리

| 항목 | 규칙 |
|---|---|
| 보관 | `localStorage` (`auth.token`). XSS 시 탈취 가능하다는 한계를 인지하고 MVP에서 수용(PRD-02 유지). Refresh Token 없음 |
| 전송 | axios 요청 인터셉터가 토큰이 있으면 `Authorization: Bearer {jwt}`를 모든 `/api` 요청에 부착 |
| 사용자 조회 | 앱 기동 시 토큰이 있으면 `GET /api/auth/me`(`useQuery(['me'])`). 성공하면 아바타 표시 |
| 401 처리 | `/api/auth/me`가 `401`이면 토큰 삭제 → 비로그인 전환 → `UNAUTHORIZED` 토스트. (다른 API는 401을 반환하지 않음) |
| 만료 | 토큰 payload의 `exp`(초)를 디코드(서명 검증 없이 표시용)해 만료 시각에 맞춰 타이머로 자동 로그아웃. 서버가 최종 기준이므로 클라이언트 시계 오차는 `/auth/me` 401로 보정 |
| 로그아웃 | 서버 호출 없음. 토큰 삭제 + `queryClient.removeQueries(['me'])` (목록·플레이어는 유지) |
| 탭 동기화 | `storage` 이벤트로 다른 탭의 로그인·로그아웃을 즉시 반영 |
| 로그 | 토큰을 `console`, 에러 리포트, URL에 남기지 않음 |

### 4.4. 로그인 오류 메시지 (`?error={code}`)

| `error` | 표시 메시지 |
|---|---|
| `access_denied` | 로그인이 취소되었습니다. |
| `invalid_request` | 로그인 요청이 올바르지 않습니다. 다시 시도해 주세요. |
| `authorization_request_not_found` | 로그인 시간이 초과되었습니다(3분). 다시 시도해 주세요. |
| `invalid_state_parameter` | 로그인 검증에 실패했습니다. 다시 시도해 주세요. |
| `invalid_user_info` | 구글 계정 정보를 확인할 수 없습니다. 이메일이 인증된 계정으로 로그인해 주세요. |
| `server_error`, `temporarily_unavailable` | 로그인 서버에 문제가 있습니다. 잠시 후 다시 시도해 주세요. |
| `invalid_redirect_uri` | 로그인 설정 오류입니다. (개발 환경이면 §12의 허용 콜백 등록을 확인하세요) |
| `login_failed` 및 그 외 | 로그인에 실패했습니다. 다시 시도해 주세요. |

## 5. 업로드 모달

로그인 상태에서만 프로필 팝오버의 `"업로드"` 메뉴가 노출됩니다(백엔드는 익명 업로드도 허용하지만 UI 정책은 PRD-02를 유지). 팝오버에는 `"업로드"`, `"로그아웃"` 두 항목이 있습니다.

### 5.1. 입력과 사전 검증

| 필드 | 제약 (백엔드와 동일) | 클라이언트 검증 |
|---|---|---|
| `file` (필수) | MP3/WAV/FLAC/M4A, 최대 100MB. **실제 내용(Tika)으로 서버가 최종 검증** | `accept=".mp3,.wav,.flac,.m4a"`, 크기 100MB 초과 시 즉시 안내 (확장자·MIME은 힌트일 뿐) |
| `title` | 최대 200자, 선택 | `maxLength=200` |
| `artist` | 최대 150자, 선택 | `maxLength=150` |
| `album` | 최대 200자, 선택 | `maxLength=200` |
| `artworkFile` | JPEG/PNG, 최대 10MB, 선택 | `image/jpeg`·`image/png`, 크기 10MB 초과 시 안내 |

* 요청 전체 한도는 110MB입니다(음원 100MB + 자켓 10MB). 한도 초과는 서버 `413`으로도 처리합니다(§3.4).
* 사전 검증 경계: 음원 100MB·자켓 10MB(1024 단위)와 글자 수(trim 후)는 **초과일 때만** 오류입니다. 글자 수 초과 문구는 `validateUpload.ts`에 둡니다(제목 200자·가수 150자·앨범 200자 "이하로 입력해 주세요."). 음원 형식·크기·자켓 오류는 §3.4 문구를 재사용합니다.
* 공백만 있는 값은 서버가 "비어 있음"으로 취급합니다. 클라이언트도 `trim()` 후 빈 값은 **필드를 보내지 않습니다.**

### 5.2. 태그 자동 채우기 정책 (PRD-02 대비 변경)

파일 선택 직후 브라우저에서 `music-metadata`로 태그를 읽습니다.

| 상황 | 동작 |
|---|---|
| 태그 값 있음 | 해당 입력칸에 **값으로 채움** (사용자가 수정 가능) |
| 태그 값 없음(예: 무태그 WAV) | 입력칸은 **비워 두고 placeholder만 표시** — 제목: 원본 파일명(확장자 제외), 가수: `Unknown Artist` |
| 파싱 실패·타임아웃 | 오류를 띄우지 않고 위 "값 없음"과 동일하게 처리(업로드 자체는 막지 않음) |

* **빈 칸은 서버로 보내지 않아** 서버 fallback(요청값 → ID3 → 파일명/`Unknown Artist`)이 동작합니다. PRD-02처럼 클라이언트가 `'Unknown Artist'`를 값으로 채워 보내면, 클라이언트 파싱이 실패했을 때 서버가 읽을 수 있는 ID3 태그를 덮어쓰게 되므로 채택하지 않습니다.
* **앨범자켓:** 내장 커버는 **미리보기 용도로만** 사용합니다(`selectCover(metadata.common.picture)` → `Blob` → `URL.createObjectURL`, 모달을 닫을 때 `revokeObjectURL`). 내장 커버는 서버가 음원에서 직접 추출하므로 **전송하지 않습니다.** 사용자가 커버 영역을 클릭해 직접 고른 JPEG/PNG만 `artworkFile`로 전송합니다(서버 우선순위: 사용자 첨부 > 내장 > 없음).
* 커버가 없으면 기본 음표 플레이스홀더를 표시합니다.

### 5.3. 파서 로딩 (코드 분할)

`music-metadata`는 업로드 모달을 처음 열 때 **동적 import**합니다(초기 번들에 포함하지 않음). 업로드 모달 컴포넌트 자체도 `React.lazy`로 분할합니다.

```ts
// 선택된 파일에서 태그·내장 커버를 추출한다 (실패 시 빈 결과 반환)
export async function readAudioTags(file: File): Promise<AudioTags> {
    try {
        const { parseBlob, selectCover } = await import('music-metadata');
        const metadata = await parseBlob(file);
        const cover = selectCover(metadata.common.picture);
        return {
            title: metadata.common.title?.trim() || null,
            artist: metadata.common.artist?.trim() || null,
            album: metadata.common.album?.trim() || null,
            cover: cover ? new Blob([cover.data], { type: cover.format }) : null,
        };
    } catch {
        return { title: null, artist: null, album: null, cover: null };
    }
}
```

### 5.4. 전송과 결과 처리

* `FormData`에 `file`과 값이 있는 `title`/`artist`/`album`/`artworkFile`만 추가해 `POST /api/tracks/upload`.
* `onUploadProgress`로 진행률(%)을 표시하고, `AbortController`로 취소 버튼을 제공합니다. axios 업로드 `timeout`은 두지 않습니다(대용량·저속망 대응. Nginx 전송 타임아웃은 연속 쓰기 간격 기준 120초).
* 전송 중에는 `[저장]` 버튼 비활성화·모달 닫기 확인 처리. 닫기 시도(ESC·배경·`취소`)는 모달 안 인라인 확인(`role="alertdialog"`, `계속 업로드`/`전송 취소하고 닫기`)을 거치고, `전송 취소` 버튼은 전송만 중단해 편집 상태로 돌아간다. 진행률이 100%여도 서버 응답 전까지는 전송 중이며 `서버에서 처리 중...` 안내(클라이언트 문구)를 덧붙인다. `timeout`은 요청별 `timeout: 0`(무제한)으로 해제한다.
* `202` 수신 → 모달 닫기 → `queryClient.invalidateQueries(['tracks'])`. 응답은 `status: "PENDING"`이며 목록에 `변환 중...` 뱃지로 나타나고 §6.3 폴링이 시작됩니다.
* 오류는 §3.4 표대로 모달 안에 인라인 표시하고 입력값은 유지합니다.

## 6. 목록·검색·변환 상태 갱신

### 6.1. 목록

* `useInfiniteQuery(['tracks', keyword])`, `size=20`, `initialPageParam=0`, `getNextPageParam = last => last.hasNext ? last.page + 1 : undefined`.
* 하단 센티널 + `IntersectionObserver`로 다음 페이지를 로드합니다(`size`를 100까지 올리지 않음).
* 검색어 변경 시 이전 목록을 유지(`placeholderData: keepPreviousData`)해 깜빡임을 줄입니다.
* 행 구성: 앨범자켓 썸네일(`artworkUrl`, `null`이거나 `onError`면 기본 썸네일), 제목(굵게)·가수·재생 시간, 상태 뱃지, 다운로드 버튼. `createdAt DESC`는 서버 정렬을 그대로 사용합니다.
* 재생 시간 표기: `mm:ss`, 1시간 이상은 `h:mm:ss`.
* 빈 상태: 검색 결과 없음 / 업로드된 곡 없음 문구. 로딩은 스켈레톤.

### 6.2. 검색

* 히어로 검색창(`노래 제목 또는 가수를 검색하세요...`), 입력 후 **300ms 디바운스**.
* 전송 전 `trim()`, **200자 초과 입력은 입력 단계에서 제한**(`maxLength=200`, 서버는 초과 시 `400`). 빈 값은 `keyword` 파라미터를 보내지 않습니다(전체 조회).

### 6.3. 변환 상태 뱃지와 폴링

| `status` | 뱃지 | 행 동작 |
|---|---|---|
| `PENDING`, `PROCESSING` | `변환 중...` | 재생 클릭 시 안내 토스트(409 방지, §7.1), 다운로드는 가능 |
| `READY` | 없음 | 재생 가능 |
| `FAILED` | `변환 실패` (신규, 경고색) | 재생 불가(클릭 시 "변환에 실패한 곡입니다" 토스트), 다운로드는 가능 |

* 변환 중인 행마다 `useQuery(['track', trackId], getTrack, { refetchInterval })`로 **5초마다** `GET /api/tracks/{trackId}`를 조회합니다. `refetchInterval`은 `query => 상태가 PENDING/PROCESSING일 때만 5000, 아니면 false`(v5는 콜백이 `query`만 받습니다).
* 행 클릭 안내 문구: `PENDING`/`PROCESSING`은 §6.3에 별도 문구가 없어 §3.4의 `TRACK_NOT_READY` 문구를 재사용하고(토스트 id `track-not-ready`), `FAILED`는 `변환에 실패한 곡입니다`(id `track-failed`)를 쓴다. 두 토스트 모두 error 타입이다.
* 응답을 받으면 `queryClient.setQueriesData({ queryKey: ['tracks'] }, …)`로 무한 쿼리 캐시의 해당 트랙을 갱신해 뱃지가 즉시 바뀌게 합니다(목록 전체 재조회 없음).
* **중단 조건:** `READY`/`FAILED` 도달, 행이 화면에서 사라짐(언마운트), `404`(목록 무효화), 폴링 시작 후 **30분 경과**(큐 대기가 길 수 있으나 무한 폴링 방지 → 뱃지에 "상태 새로고침" 버튼 표시).
* 페이지를 새로고침해도 목록 응답의 `status`로 폴링이 자동 재개됩니다. 탭이 백그라운드이면 `refetchIntervalInBackground=false`(기본값)로 일시 중지합니다.

## 7. 플레이어

### 7.1. 구조

* `<audio>` 요소 **하나**를 앱 루트의 `PlayerProvider`가 소유합니다(라우트 이동에 영향받지 않음). 상태: `currentTrack`, `isPlaying`, `currentTime`, `duration`, `volume`, `isMuted`, `isLooping`, `status('idle'|'loading'|'playing'|'paused'|'error')`.
* 행 클릭(`READY`만) → `GET /api/tracks/{id}/play` → `streamUrl`로 재생 시작. **재생 시작 클릭 1회당 `/play`를 1번만 호출**합니다(호출마다 `STREAM` 이력이 쌓이므로 재렌더·반복재생·시크·일시정지 때는 호출하지 않음).
* `409 TRACK_NOT_READY`면 토스트 + 해당 트랙 상태 재조회.
* **연속 클릭 경합:** 요청마다 증가하는 `requestId`를 두고, 응답 도착 시 최신 `requestId`가 아니면 폐기합니다.
* `streamUrl`·`artworkUrl`은 **상대경로·절대 URL 모두 수정 없이 그대로** 사용합니다(`MEDIA_PUBLIC_BASE_URL` 설정에 따라 달라짐).
* **같은 곡 재클릭:** `playing`/`paused` 상태의 같은 곡을 다시 클릭하면 `/play`를 호출하지 않고 재생/일시정지를 토글합니다. `ended` 이후나 `error` 상태에서의 재클릭은 재시작이므로 `/play`를 다시 호출합니다. 응답 대기 중(`loading`)인 같은 곡의 중복 클릭은 무시합니다(§16 #33).
* 하단 바는 곡 선택 전에는 숨기고, 표시 중에는 본문 하단 패딩을 확보합니다. 재생 중인 곡의 행은 강조합니다. 다음 곡 자동 재생·재생목록은 MVP 범위 밖이며, 곡이 끝나고 반복재생이 꺼져 있으면 정지합니다.

### 7.2. HLS 연결 (`attachHlsStream`)

```ts
import Hls from 'hls.js';

// 곡을 바꿀 때 이전 인스턴스를 반드시 destroy하고 audio를 비운 뒤 연결한다
export function attachHlsStream(audio: HTMLAudioElement, streamUrl: string, onFatalError: () => void): Hls | null {
    if (Hls.isSupported()) {
        const hls = new Hls({ maxBufferLength: 30 }); // 6초 청크 약 5개 선버퍼링
        let lastMediaRecoveryAt = 0;
        let hasRetriedNetwork = false;

        hls.on(Hls.Events.ERROR, (_event, data) => {
            if (!data.fatal) return; // 비치명 오류는 hls.js가 자체 복구
            if (data.type === Hls.ErrorTypes.MEDIA_ERROR && Date.now() - lastMediaRecoveryAt > 5000) {
                lastMediaRecoveryAt = Date.now(); // 5초 쿨다운으로 복구 루프 방지
                hls.recoverMediaError();
            } else if (data.type === Hls.ErrorTypes.NETWORK_ERROR && !hasRetriedNetwork) {
                hasRetriedNetwork = true; // 재시도가 소진된 상태이므로 1회만 재개 시도
                hls.startLoad();
            } else {
                hls.destroy();
                onFatalError(); // 정지 + "재생 중 오류가 발생했습니다" 토스트
            }
        });
        hls.loadSource(streamUrl);
        hls.attachMedia(audio);
        return hls;
    }
    if (audio.canPlayType('application/vnd.apple.mpegurl')) {
        audio.src = streamUrl; // Safari 네이티브 HLS
        return null;
    }
    onFatalError();
    return null;
}
```

* 구현 시그니처는 `attachHlsStream(audio, streamUrl, { onFatalError, onReady?, HlsClass? })`(테스트용 `Hls` 주입, `onReady`는 `MANIFEST_PARSED`/`loadedmetadata` 알림만 하고 `play()`는 호출하지 않음, `destroy` 이후 이벤트 무시)이며 정리 함수는 `detachStream(audio, hls)`입니다(§16 #32).
* 재생 시작은 `MANIFEST_PARSED`(hls.js) 또는 `loadedmetadata`(Safari) 이후 `audio.play()`를 호출합니다.
* `play()`가 `NotAllowedError`(자동재생 정책)로 거부되면 오류 토스트 없이 일시정지 상태로 두고 재생 버튼을 활성화합니다.
* 정리: 곡 변경·언마운트 시 `hls.destroy()`, `audio.removeAttribute('src')`, `audio.load()`.
* 최종 실패 시 `status='error'`로 두고 재생 버튼을 비활성화합니다.

### 7.3. 컨트롤

| 컨트롤 | 동작 |
|---|---|
| 재생/일시정지 | `isPlaying`과 동기화되는 토글 (`audio` 이벤트 `play`/`pause`가 상태의 단일 출처) |
| 진행 슬라이더 | `0 ~ duration`. 드래그 중에는 `onChange`(로컬 값)만 호출하고 **놓을 때(`onCommit` 1회)** `audio.currentTime`에 반영. `01:15 / 03:40` 표기(바 전용 `formatClock`, 목록의 `formatDuration`은 `1:15`로 유지, §16 #35) |
| 길이 | 응답의 `durationSeconds`로 초기화하고 `loadedmetadata`에서 보정 |
| 볼륨 | `0.0 ~ 1.0` (`audio.volume`), 스피커 아이콘 클릭 시 음소거(`aria-pressed`). 값은 `localStorage`(`player.volume`, `player.muted`)에 저장하고 바가 열릴 때 `audio`에 복원(손상 값은 기본값 1·해제). 드래그 중에는 `onChange`에서 `audio.volume`을 즉시 반영하고 `onCommit`에서 저장. 음소거 중 볼륨을 0보다 크게 올리면 음소거 해제(§16 #36). 360px 이하(`max-width: 480px`)에서는 슬라이더만 숨기고 음소거 버튼은 유지 |
| 반복재생 | `audio.loop` 토글(활성 시 강조색). 반복은 `/play`를 다시 호출하지 않음 |
| 다운로드 | 현재 곡의 원본 다운로드 (§8) |
| 키보드 | 포커스가 입력창이 아닐 때 `Space`로 재생/일시정지. 바 안의 `window` keydown으로 처리하며 `input`·`textarea`·`select`·`contenteditable`·`button`·`a`·`role=slider/button/checkbox`에 포커스가 있거나 수식키·`repeat`이면 무시한다. 즉 **버튼에 포커스가 있을 때 `Space`는 전역 토글이 아니라 그 버튼의 기본 동작**을 따른다(이중 토글 방지, §16 #36) |
| Media Session | `navigator.mediaSession.metadata`에 제목·가수·아트워크를 설정(미지원 환경은 가드, 언마운트 시 `null`). 재생/일시정지 액션 핸들러는 MVP 범위 밖 |

## 8. 원본 다운로드 (브라우저 네이티브)

* 숨겨진 `<a href="{API_BASE}/api/tracks/{id}/download" download>`를 프로그램으로 클릭합니다. Body 없이 `X-Accel-Redirect`로 Nginx가 파일을 내려주며, `Content-Disposition: attachment; filename*=UTF-8''...`가 한글 파일명을 그대로 적용합니다.
* 파일을 JS 메모리에 올리지 않으므로 최대 100MB 파일에서도 메모리 문제가 없고, 진행률은 브라우저 다운로드 관리자가 표시합니다.
* 행의 다운로드 버튼은 `e.stopPropagation()`으로 재생이 시작되지 않게 합니다. 모든 상태(`PENDING`/`FAILED` 포함)에서 가능합니다.
* **구현(T5-1):** `src/lib/download.ts`의 `downloadTrack(trackId)`가 `encodeURIComponent`로 인코딩한 숨김 앵커를 `append → click → remove`한다. 행 버튼의 접근성 이름은 `원본 다운로드`, 플레이어 바(볼륨 오른쪽 끝) 버튼은 `현재 곡 원본 다운로드`다.
* **iframe 대신 `<a download>`를 쓰는 이유:** Spring Security 기본 응답 헤더(`X-Frame-Options: DENY`)가 Nginx를 통과해 그대로 전달되면 iframe 방식이 막힐 수 있습니다. 앵커 방식은 이 영향을 받지 않으며, 서버 오류(404·500) 시 브라우저가 다운로드 실패로 표시합니다.
* **한계(MVP 수용):** ① 브라우저 이동 방식은 `Authorization` 헤더를 실을 수 없어 **`DOWNLOAD` 이력의 `user_id`가 `NULL`(익명)**로 남습니다. ② 오류 시 앱 토스트가 아닌 브라우저 UI로만 알려집니다. 이력의 사용자 귀속이 필요해지면 백엔드와 협의해 단기 다운로드 토큰 방식을 검토합니다(§17).

## 9. UI·디자인·접근성

### 9.1. 레이아웃 (4영역)

① 상단 헤더(로고·검색 영역·로그인/아바타) ② 중앙 모달(로그인·업로드) ③ 히어로 검색창 + 트랙 리스트 ④ 하단 고정 플레이어 바.

### 9.2. 디자인 토큰 (`styles/tokens.css`, PRD-02 팔레트)

| 토큰 | 값 | 용도 |
|---|---|---|
| `--color-bg` | `#030303` | 페이지 배경 |
| `--color-bg-elevated` | `#121212` | 헤더·플레이어 바 |
| `--color-surface` | `#212121` | 입력창·모달·행 hover |
| `--color-accent` | `#FF0000` | 포인트(활성 토글·진행바) |
| `--color-text` / `--color-text-muted` | `#FFFFFF` / `#AAAAAA` | 텍스트 |
| `--color-warning` | `#FFB300` (T0-7에서 정의) | `변환 실패` 뱃지 |

**추가 토큰** (PRD-02에 없고 T0-7에서 정의, 위 7개 값은 변경 없음)

| 토큰 | 값 | 용도 |
|---|---|---|
| `--color-success` | `#4CAF50` | 토스트 success 표식 |
| `--color-error` | `#FF5252` | 토스트 error 표식 |

**대비 계산값** (WCAG 2.x 상대 휘도 기준, 스크립트로 계산, `src/styles/contrast.test.ts`가 회귀 방지)

| 전경 | `#030303` (bg) | `#121212` (elevated) | `#212121` (surface) |
|---|---|---|---|
| `#FFFFFF` text | 20.62 | 18.73 | 16.10 |
| `#AAAAAA` muted | 8.88 | 8.06 | 6.93 |
| `#FFB300` warning | 11.49 | 10.44 | 8.97 |
| `#4CAF50` success | 7.42 | 6.74 | 5.79 |
| `#FF5252` error | 6.46 | 5.87 | 5.05 |
| `#FF0000` accent | 5.16 | 4.69 | 4.03 |

텍스트·상태 색은 모두 4.5:1 이상이다. `--color-accent`는 `#212121` 위에서 4.03:1이라 **텍스트에 쓰지 않는다**(행 hover·focus 배경 `#212121` 위 4.03:1, `#030303` 위 5.16:1; 현재 재생 행은 제목 대신 좌측 accent 바로 표시. 진행바·활성 토글 같은 비텍스트 UI는 3:1 기준 충족). 토스트 error를 `#F44336`(surface 위 4.37)에서 `#FF5252`로 올린 이유도 4.5:1 때문이다.

### 9.3. 반응형·접근성

* 최소 지원 폭 **360px**. 좁은 화면에서는 플레이어 바의 볼륨 슬라이더를 숨기고, 행의 보조 정보를 줄입니다.
* 모달: 포커스 트랩, `ESC`·배경 클릭으로 닫기(업로드 전송 중에는 확인), `role="dialog"`, `aria-modal`.
* 모든 아이콘 버튼에 `aria-label`(예: `재생`, `일시정지`, 행 다운로드는 곡 제목을 포함한 `{title} 원본 다운로드`, 플레이어 바는 `현재 곡 원본 다운로드`), 슬라이더는 `aria-valuenow/min/max`, 상태 변경 토스트는 `aria-live="polite"`.
* 색상만으로 상태를 전달하지 않습니다(뱃지는 텍스트 포함, 현재 재생 행은 `aria-current`와 accent 바, 반복·음소거는 `aria-pressed`와 아이콘 변화 `Repeat1`/`Repeat`, `VolumeX`/`Volume2`).
* 모달이 열려 있는 동안 `#root`에 `inert`를 걸고(닫을 때 이전 값 복원, `#root`가 없으면 무시) 모달과 토스트 영역은 `document.body` 직속 포털이라 대상에서 제외한다(§16 #37). 업로드 전송이 끝나 편집 상태로 돌아오면 포커스를 제목 입력으로 되돌린다.

## 10. 폴더 구조

```text
frontend/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── .node-version                # fnm이 읽는 Node 버전 (26)
├── .env.example
└── src/
    ├── main.tsx
    ├── App.tsx                      # 라우트(/, /auth/callback), Provider 구성
    ├── api/
    │   ├── client.ts                # axios 인스턴스, Bearer·에러 정규화 인터셉터
    │   ├── types.ts                 # §3.3 타입
    │   ├── tracks.ts                # getTracks, getTrack, getPlayInfo, uploadTrack, getDownloadUrl
    │   └── auth.ts                  # getMe, getLoginUrl
    ├── features/
    │   ├── auth/                    # AuthProvider, useAuth, LoginModal, ProfileMenu, AuthCallbackPage
    │   ├── upload/                  # UploadModal, readAudioTags, useUploadTrack
    │   ├── tracks/                  # TrackList, TrackRow, StatusBadge, SearchBar, useTracksQuery, useTrackStatusPolling
    │   └── player/                  # PlayerProvider, usePlayer, BottomPlayerBar, attachHlsStream
    ├── components/                  # Header, Modal, Toast, Avatar, IconButton, Slider
    ├── hooks/                       # useDebouncedValue, useIntersectionObserver
    ├── lib/                         # jwt.ts(exp 디코드), format.ts(mm:ss), download.ts, errorMessages.ts
    └── styles/                      # tokens.css, global.css
```

## 11. 환경변수와 빌드·배포

| 이름 | 설명 | 기본값 |
|---|---|---|
| `VITE_API_BASE_URL` | API·로그인 진입 기준 URL. 단일 오리진이면 비움(상대경로) | (빈 값) |
| `VITE_OAUTH_REDIRECT_URI` | 로그인 `redirect_uri`. 백엔드 화이트리스트와 완전 일치해야 함 | (빈 값 → `${location.origin}/auth/callback`) |

* 시크릿은 프론트엔드에 두지 않습니다(`VITE_*`는 번들에 노출됨). `.env`는 `.gitignore`, `.env.example`만 커밋합니다.
* **빌드 출력:** `npm run build` → `../frontend-dist`(저장소 상위의 `frontend-dist`, PRD-04의 Nginx 마운트 대상). 출력 경로가 프로젝트 밖이므로 Vite가 안전상 `emptyOutDir`을 명시하도록 요구하며, 의도를 명확히 하기 위해 `emptyOutDir: true`를 설정합니다(**해당 폴더의 기존 내용이 삭제됨**에 유의).
* **단일 오리진이 기본**입니다. 웹을 별도 오리진(CDN 등)으로 분리하면 백엔드·인프라 설정이 필요합니다.

| 필요 설정 | 담당 | 값 |
|---|---|---|
| `CORS_ALLOWED_ORIGINS` | 백엔드 | 웹 오리진(`scheme://host[:port]`) |
| `OAUTH2_ALLOWED_REDIRECT_URIS`·`OAUTH2_DEFAULT_REDIRECT_URI` | 백엔드 | 웹 `…/auth/callback` |
| `MEDIA_PUBLIC_BASE_URL` | 백엔드 | 미디어 오리진 (이때 `streamUrl`·`artworkUrl`이 절대 URL로 옴) |
| Google Console | 인프라 | 리디렉션 URI는 **백엔드 호스트**의 `/login/oauth2/code/google` |

## 12. 개발 환경 (Windows 11)

### 12.1. 실행

```bash
fnm use                 # Node 26 (.node-version)
npm install
npm run dev             # http://localhost:5173
```

전제: 전체 docker 스택(Nginx `80`, 백엔드, RustFS, PostgreSQL)이 `http://localhost`에서 실행 중이어야 합니다.

### 12.2. `vite.config.ts` 프록시

```ts
server: {
    port: 5173,
    proxy: {
        // changeOrigin 필수: Host 헤더가 localhost:5173이면 백엔드가 계산하는
        // Google redirect_uri가 달라져 로그인이 실패한다
        '/api': { target: 'http://localhost', changeOrigin: true },
        '/oauth2': { target: 'http://localhost', changeOrigin: true },
        '/login/oauth2': { target: 'http://localhost', changeOrigin: true },
        '/stream': { target: 'http://localhost', changeOrigin: true },
        '/artwork': { target: 'http://localhost', changeOrigin: true },
    },
},
```

* PRD-02는 `/login` 전체를 프록시했으나, SPA 라우트와 겹치지 않도록 `/login/oauth2`로 좁힙니다.
* Google이 로그인 후 브라우저를 `http://localhost/login/oauth2/code/google`(포트 80)로 돌려보내므로 이 구간은 Vite 프록시를 거치지 않습니다. 이후 백엔드가 `redirect_uri`로 `302`하는 곳이 개발 서버입니다.

### 12.3. 개발 서버에서 로그인하기

개발 서버의 콜백 `http://localhost:5173/auth/callback`은 기본 화이트리스트에 없습니다. 백엔드 `OAUTH2_ALLOWED_REDIRECT_URIS`에 `http://localhost:5173/auth/callback`을 **추가해야** 하며(코드 수정 없음, 환경변수·컨테이너 재시작 — §15), 그렇지 않으면 `?error=invalid_redirect_uri`가 표시됩니다. 쿠키는 포트를 구분하지 않으므로 인가 요청 쿠키는 정상 동작합니다. 토큰은 `localhost:5173` 오리진의 `localStorage`에 저장되어 `localhost`(80)와 별개입니다.

## 13. 테스트 전략

| 계층 | 도구 | 검증 대상 |
|---|---|---|
| 단위 | Vitest | `jwt.ts`(exp 디코드·만료 판정), `format.ts`(mm:ss·h:mm:ss), 에러 정규화·메시지 매핑, 업로드 사전 검증, 빈 값 필드 생략 |
| 컴포넌트 | Vitest + RTL + MSW | 콜백 라우트(`token`/`error`/없음, StrictMode 이중 실행에서도 토큰 보존, 주소 쿼리 제거), 로그인 모달·프로필 팝오버, 업로드 모달(태그 채움·placeholder·오류 인라인), 목록(무한 스크롤·검색 디바운스), 폴링(`PROCESSING → READY` 전환 시 중단, `FAILED`, 30분 상한), 플레이어 상태(`audio`·`Hls`는 모킹: 연속 클릭 경합, 409, `NotAllowedError`, 반복재생 시 `/play` 미호출) |
| E2E | Playwright | 전체 스택에서 **Milestone 1**: 업로드(샘플 MP3) → `PENDING` → `READY` 뱃지 갱신 → 재생(청크 요청 확인, `currentTime` 증가) → 반복재생 → 다운로드(파일명·바이트 확인). 로그인 상태는 테스트에서 JWT를 주입해 생성 |
| 수동 | - | Google 로그인 전체 흐름(5회 이상 반복해 멀티노드 분산 확인, PRD-04 §6-7), Safari 네이티브 HLS, 모바일 폭 레이아웃 |

* 업로드 E2E는 실제 FFmpeg 변환을 거치므로 폴링 대기 상한을 넉넉히 둡니다(소형 샘플은 수 초).
* E2E의 JWT 주입은 테스트 환경의 `JWT_SECRET_KEY`로 발급한 토큰을 사용하며, 실제 시크릿은 저장소에 넣지 않습니다.

## 14. 비기능 요구사항

* **성능:** 초기 번들에서 `music-metadata`·업로드 모달 제외(지연 로드). 목록은 페이지 단위 로드. 미디어 바이트는 백엔드를 거치지 않고 Nginx가 전송하므로 프론트엔드는 URL만 사용합니다.
* **브라우저 지원:** Chrome·Edge·Firefox·Safari 최신 2개 버전. 모바일 브라우저는 반응형 수준만 보장하며 백그라운드 재생은 앱(PRD-03) 소관입니다.
* **보안:** `dangerouslySetInnerHTML` 금지(제목·가수는 사용자 입력이므로 항상 텍스트로 렌더링), 토큰은 URL·로그·에러 리포트에 남기지 않음, 외부 링크는 `rel="noopener noreferrer"`, 서버 `message` 대신 클라이언트 메시지 사용.
* **안정성:** 오류 경계(`ErrorBoundary`)로 플레이어·목록의 렌더 오류가 앱 전체를 중단시키지 않게 합니다. 플레이어 바 경계가 오류를 잡으면 `stop()`으로 재생을 멈추고 토스트로 알리며(`<audio>`가 바 없이 계속 재생되는 것을 막음), 목록 경계는 바에 영향을 주지 않습니다(§16 #38). 네트워크 오류는 토스트로 알리고 재시도 정책(§3.4)을 따릅니다.

**점검 결과 (T5-3, 2026-11-12)**

| 항목 | 결과 |
|---|---|
| `dangerouslySetInnerHTML` | `src/` 전체(테스트 포함) 0건 |
| `console.*` | 비테스트 코드 0건(`ErrorBoundary.test.tsx`·`AppBoundaries.test.tsx`의 `console.error` 억제 mock만 존재). 토큰은 `Authorization` 헤더로만 전송되고 `ApiError`는 `errorMessages` 고정 문구만 사용 |
| 토큰 경로 | `/auth/callback`은 쿼리 읽기 → `replaceState` → `login` 순서이며, 테스트가 console·DOM에 토큰이 없음을 확인 |
| `target=`·`window.open` | 0건(외부 링크 없음, `rel` 요구 대상 없음) |
| `VITE_*` | `VITE_API_BASE_URL`, `VITE_OAUTH_REDIRECT_URI`만 사용(둘 다 비시크릿). `.env.example`은 읽지 못해 사용자 확인 필요 |
| 초기 청크 | `index.html`은 `index-*.js`(972KB)와 `rolldown-runtime`만 로드. `UploadModal-*.js`(8.6KB)·`music-metadata`(`core-*.js` 89KB와 각 Parser 청크)는 별도 청크 |
| `npm audit` | moderate 10건, 모두 devDependencies의 lint 체인(`minimatch` DoS GHSA-g3hv-75wg-m249), 프로덕션 번들 영향 없음. 수정은 `eslint` 주 버전 변경이 필요해 보류 |

## 15. 백엔드·인프라 요청 사항 (이 저장소에서 구현하지 않음)

| # | 요청 | 담당 | 비고 |
|---|---|---|---|
| 1 | `OAUTH2_ALLOWED_REDIRECT_URIS`에 `http://localhost:5173/auth/callback` 추가 (개발 전용, 운영에는 넣지 않음) | 백엔드 환경변수 | §12.3 |
| 2 | Nginx 접근 로그 포맷에서 `/auth/callback`의 `token` 쿼리 제외·마스킹 | 인프라(PRD-04) | JWT가 URL 쿼리(`{redirect_uri}?token=`)로 전달되어 웹 콜백 요청이 접근 로그에 남을 수 있음(백엔드 구현 시 확인된 위험) |
| 3 | 다운로드 응답에서 `X-Accel-Redirect`·`Content-Disposition` 유지 확인 | 인프라 통합 테스트 | 백엔드 인덱스 §7.1(통합 테스트 확인 항목), 이 문서 §8 |
| 4 | SPA 정적 서빙 시 CSP·보안 헤더 검토 (hls.js는 `blob:` 미디어 소스 사용) | 인프라 | 도입 시 `media-src blob:` 필요 여부 확인 |
| 5 | `../frontend-dist` 마운트 경로와 `try_files … /index.html` 유지 | 인프라(PRD-04) | `/auth/callback` 새로고침 404 방지 |

## 16. 결정 이력 (PRD-02 대비 변경점)

| # | PRD-02 | 변경 | 사유 |
|---|---|---|---|
| 1 | JavaScript(`.jsx`) + axios 직접 호출 | **TypeScript + TanStack Query** | 백엔드 DTO·에러 코드를 타입으로 고정, 폴링·무한 스크롤·무효화를 라이브러리로 처리 (사용자 확정 2026-11-12) |
| 2 | `jsmediatags` | **`music-metadata`** (동적 import) | 유지보수 중단·Vite 번들 호환 문제, WAV·M4A 지원 (사용자 확정) |
| 3 | 원본 다운로드 방식 미정 | **브라우저 네이티브**(`<a download>`), 이력은 익명 허용 | 메모리 사용 없음(100MB), 한글 파일명은 `Content-Disposition`이 처리 (사용자 확정) |
| 4 | Nginx 컨테이너·빌드 배포 절차 포함 | **SPA 소스 + dist 빌드만** | 인프라 소관 분리 (사용자 확정) |
| 5 | 허용 형식 `.mp3/.wav/.flac` | **`.m4a` 추가** | 백엔드가 M4A 허용(PRD-05 §6.2) |
| 6 | Node.js 20 | **Node.js 26** (fnm) | Node 20 지원 종료, Vite 8 요구 충족, 로컬 개발 환경(v26.13.0)과 일치 (v1.1에서 24 → 26으로 정정) |
| 7 | Vite 프록시 `/login`, `changeOrigin` 없음 | `/login/oauth2`, **`changeOrigin: true`** | Host 불일치 시 Google `redirect_uri` 계산 오류, SPA 라우트 충돌 방지 |
| 8 | `redirect_uri` 하드코딩(`http://localhost/auth/callback`) | `VITE_OAUTH_REDIRECT_URI`(기본 `${origin}/auth/callback`) | 개발 서버·분리 배포 대응 |
| 9 | `[변환 중...]` 뱃지만 정의 | **`FAILED` → `변환 실패` 뱃지** 추가, 폴링 중단·30분 상한 | 실패 상태가 정의되지 않음 |
| 10 | 태그 없음 시 `'Unknown Artist'`를 입력값으로 채움 | **placeholder만 표시, 빈 값은 미전송** | 클라이언트 파싱 실패 시 서버 ID3 fallback 보존 |
| 11 | 내장 커버를 업로드 대상으로 암시 | **미리보기 전용, 전송 안 함** | 서버가 직접 추출(우선순위: 사용자 첨부 > 내장) |
| 12 | 에러 응답 처리 미정의 | `code` 매핑 표(§3.4), 로그인 `?error=` 매핑(§4.4) | 백엔드 계약 정합 |
| 13 | hls.js 에러 처리 없음 | fatal 에러 복구(미디어 쿨다운 5초, 네트워크 1회) 후 정지 | hls.js 문서 권장(네트워크 즉시 재개는 루프 위험) |
| 14 | `/play` 호출 시점 미정 | **재생 시작 클릭당 1회** | 호출마다 `STREAM` 이력이 쌓임 |
| 15 | 콜백 처리 순서 미정 | 쿼리 읽기 → 주소 제거 → 저장 → 이동, StrictMode 가드 | 토큰 노출 최소화·개발 모드 이중 실행 대응 |
| 16 | `<a>`/iframe 미정 | iframe 대신 `<a download>` | Spring 기본 `X-Frame-Options: DENY` 영향 회피 |
| 17 | - | `PRD-frontend.md` → **`PRD.md`** 개명(v1.1). 백엔드 인덱스·ROADMAP 참조를 내용으로 대체 | 이 저장소의 메인 기준 문서를 프론트엔드 PRD로 지정. 백엔드 문서 정리(삭제) 후에도 참조가 끊기지 않게 하기 위함 (사용자 요청 2026-11-12) |
| 18 | TypeScript 버전 미정 | **6.0.3 고정** (7.0.2 미사용) | 7.0.2가 `latest`지만 `typescript-eslint` peer가 `typescript <6.1.0`이라 T0-2에서 충돌. TS 7 지원 후 상향 검토 (T0-1, 2026-11-12) |
| 19 | React Router 버전 미정 | **7.18.5 고정** (8.5.1 미사용), `react-router`만 import | 8.5.1은 library mode를 문서로 검증할 수 없고 요구 사양이 높음. 이후 8.x로 올릴 때는 `BrowserRouter`·`Routes`·`Route` export를 확인 (T0-1, 사용자 결정 2026-11-12) |
| 20 | ESLint·Prettier 버전·옵션 미정 | 위 §2 버전 고정, Prettier `tabWidth 4`·`singleQuote`·`printWidth 100`·`trailingComma all`·`endOfLine lf`, `*.md`·`.claude`는 포맷 제외, `typecheck`는 `tsc -b`, `format:check` 추가 | 4칸·작은따옴표 규칙을 도구로 강제, 문서 대량 변경 방지 (T0-2, 사용자 승인 2026-11-12) |
| 21 | 테스트 도구 버전·MSW 옵션 미정 | 위 §2 버전 고정, `vitest.config.ts` 분리(jsdom, globals), `npm run test`는 `vitest run`. **MSW 3.0.5**는 미처리 요청 옵션이 `onUnhandledRequest`가 아니라 `onUnhandledFrame: 'error'`이고 `http`·`HttpResponse`는 `msw/http`, `setupServer`는 `msw/node`에서 import | MSW 3에는 `onUnhandledRequest`가 없고 동작은 같음 (T0-4, 사용자 확정 2026-11-12) |
| 22 | jsdom 31의 Node 요구 | jsdom 31.0.0은 Node `>=22.22.2`를 요구하나 `package.json` engines `>=22.12.0`은 유지(로컬은 Node 26) | engines 상향 여부는 이후 판단 (T0-4) |
| 23 | axios timeout 미정 | 기본 **30초**, 업로드는 요청별 `timeout: 0`(무제한). 취소(`axios.isCancel`)는 `ApiError`로 정규화하지 않고 그대로 reject | PRD에 수치 없음, 임시 기본값. 업로드 취소(T3-3)가 취소와 오류를 구분해야 함 (T0-5, 사용자 승인 2026-11-12) |
| 24 | mutation 재시도 정책 미정 | `queries`는 §3.4(4xx 안 함, 5xx·네트워크 최대 2회, ApiError 아닌 에러는 안 함), `mutations.retry: false` | PRD §3.4는 queries 기준이며 mutation(업로드)은 비멱등이라 재시도하지 않음 (T0-6, 사용자 승인 2026-11-12) |
| 25 | `--color-warning` 구현 시 정의, 토스트 색 하드코딩 | `--color-warning: #FFB300`, 추가 토큰 `--color-success: #4CAF50`·`--color-error: #FF5252`(§9.2 하단). 레이아웃은 `AppLayout`(grid, sticky 헤더, `playerSlot`), 플레이어 표시 중 `body[data-player="true"]`로 `--layout-bottom-offset`(= `--player-height` + safe-area)을 전환해 본문 하단 패딩·토스트 위치에 사용. `vitest.config.ts`에 `css.include`로 `styles/tokens.css`만 처리(`?raw` 대조용) | 상태색 대비 4.5:1 확보, 토스트가 `AppLayout` 밖이라 body 속성으로 변수 공유 (T0-7, 사용자 승인 2026-11-12) |
| 26 | 슬라이더 커밋 시점 표현이 모호("`onChange` 커밋") | `Slider`는 드래그 중 `onChange`(로컬 값), 놓을 때 `onCommit` 1회(값이 같아도 호출), `pointercancel`은 커밋 없이 시작 값으로 `onChange`, 키보드는 `onChange` 직후 `onCommit`. §7.3 문구 정정. 모달 z-index 500(플레이어 100 < 모달 < 토스트 1000), `Modal`은 `requestClose` render-prop 제공 | ROADMAP T0-8 계약 일치 |
| 27 | 로그인 상태 경계 동작 미정 (`/me` 실패, 초기 만료, 만료·401 토스트) | `/me`가 5xx·네트워크 오류로 최종 실패하면 토큰은 유지하고 토스트 없이 `unauthenticated`로 표시(로그인 버튼이 보이나 창 포커스 시 `refetchOnWindowFocus`로 복구). 초기 토큰이 이미 만료면 `/me` 호출 없이 즉시 로그아웃(토스트 없음). 만료 타이머 로그아웃은 토스트 없음, `UNAUTHORIZED` 토스트는 `/me` 401에만 `id: 'auth-unauthorized'`로 1회. `['me']`는 `staleTime` 5분, 다른 탭의 토큰 변경 시 `['me']`를 항상 제거 | PRD §4.3에 해당 경계 규정 없음 (T1-2, 사용자 승인 2026-11-12) |
| 28 | 같은 탭 로그인 시 `AuthProvider`가 새 토큰을 알 방법 미정 (invalidate만으로는 `enabled:false`라 `/me` 미호출) | `AuthContext`에 `login(token)` 추가: `setToken` → `setTokenState` → `invalidateQueries(['me'])` 순. 콜백은 `쿼리 읽기 → replaceState → login(token) → navigate('/', {replace:true})`. 오류 토스트는 `id: 'login-error'`, 알 수 없는 코드는 `login_failed` 문구. 만료·깨진 토큰으로 로그인하면 타이머가 조용히 비로그인 처리(MVP 수용) | PRD §4.2에 AuthProvider 상태 갱신 규정 없음 (T1-3, 사용자 승인 2026-11-12) |
| 29 | 검색 UI 위치가 §6.2(히어로 검색창)와 §9.1 ①(헤더의 검색 영역) 문구에서 갈림 | 본문 상단 히어로 검색창으로 구현하고 `AppLayout`의 `headerSearchSlot`은 비움. `HomePage`가 `keyword` 상태를 소유하고 `useDebouncedValue(keyword, 300)` 결과를 `TrackList`에 전달. `SearchBar`는 `{value, onChange, className?}`만 받으며 한글 IME 조합 중에는 draft만 갱신하고 `compositionend`에 최종 값을 한 번 올림. 지우기(X) 버튼은 두지 않고 `type=search` 기본 동작에 맡김 | §6.2가 "히어로"로 명시, §9.1 ③도 히어로 검색창 + 리스트 (T2-3, 사용자 승인 2026-11-12) |
| 30 | 변환 상태 폴링의 오류 처리·30분 기준이 미정 (§3.4 "5xx 재시도 2회"와 §6.3) | 폴링 쿼리(`['track', id]`)만 `retry: false`(§3.4 재시도 2회의 예외)로 두고 다음 5초 틱이 재시도 역할을 하며 5xx·네트워크 오류에도 토스트 없이 폴링을 이어간다(404만 중단+목록 무효화). 30분 상한의 기준은 **행이 마운트된 시각**이라 스크롤·검색으로 행이 다시 마운트되면 30분이 초기화되는 한계가 있다(곡 단위 유지가 필요하면 모듈 레벨 Map이 필요). 폴링 쿼리는 `gcTime: 0`, 목록 캐시는 status만 갱신 | 행마다 재시도 3회가 5초 틱과 겹치고 알림이 쌓이는 것을 방지, 상한의 목적(무한 폴링 방지)에는 충분 (T2-4, 사용자 승인 2026-11-12) |
| 31 | 태그 파싱 타임아웃 시간·위치와 업로드 모달 경계 동작이 미정 (§5.2) | 모달 내부에서 `Promise.race([readAudioTags(file), 5초 타이머])`로 처리하고(`readAudioTags`는 수정하지 않음) 시간 초과·실패는 "값 없음"으로 처리하며 늦게 온 결과는 무시한다. 파일 재선택 시 태그 칸·내장 커버는 새 파일 기준으로 초기화하되 사용자가 직접 고른 커버(`userArtwork`)는 음원과 무관해 유지한다. 사용자가 직접 고친 칸은 늦게 도착한 태그로 덮어쓰지 않는다. `UploadModal`은 `open` prop 없이 열려 있을 때만 마운트되어 닫으면 상태가 초기화되고, 닫힘은 부모 `onClose`가 결정한다 | 로컬 파일 앞부분만 읽는 작업이라 5초면 충분하고, 오래 걸려도 입력·저장을 막지 않기 위함 (T3-2, 사용자 승인 2026-11-12) |
| 32 | `attachHlsStream`의 테스트 가능성·재생 시작 책임이 미정 (§7.2) | 세 번째 인자를 `{ onFatalError, onReady?, HlsClass? }` 객체로 확장하고 상태(쿨다운·네트워크 재시도·destroy 여부)는 호출마다의 클로저 지역 변수로 둔다. `destroy` 이후 에러 이벤트는 무시하고, `onReady`로 준비 시점만 알리며 `play()`는 T4-2가 호출한다. 정적 `import Hls`는 유지(분할은 T5-3), 네이티브 경로의 audio `error` 처리는 T4-2 | `Hls` 주입으로 실제 hls.js 없이 가짜 타이머 테스트 가능, 책임 분리 (T4-1, 사용자 승인 2026-11-12) |
| 33 | 같은 곡을 다시 클릭할 때 `/play`를 호출할지 미정 (§7.1) | `playing`/`paused`의 같은 곡은 `/play` 없이 토글, `ended`·`error` 후 재클릭은 재시작으로 `/play` 재호출, `loading` 중 같은 곡 중복 클릭은 무시한다. 연속 클릭 경합은 `requestId`로, 일시정지 상태를 `audio` 이벤트가 단일 출처로 갖는 구조와 맞춘다 | STREAM 이력은 재생 시작 1회당 1건이어야 하고 행 클릭이 토글을 겸하는 것이 자연스러움 (T4-2, 사용자 승인 2026-11-12) |
| 34 | 재생 오류 문구와 `PlayerProvider` 구조·위치가 미정 | 재생 오류는 `playbackErrorMessage` 한 문구로 통일(§3.4 표). `PlayerProvider`는 `ToastProvider > AuthProvider > PlayerProvider > ErrorBoundary > App` 순서로 두고, 컨텍스트는 상태·액션·audio ref 3개로 분리(`usePlayerState`/`usePlayerActions`/`usePlayerAudio`, 합친 `usePlayer`)해 `currentTime`·`duration`은 소비자가 audio ref로 직접 구독한다. `currentTrack`은 `StreamPlayResponse` | 토스트 의존, 오류 경계 교체 시에도 `<audio>` 유지, 시간 갱신으로 인한 전체 리렌더 방지 (T4-2, 사용자 승인 2026-11-12) |
| 35 | 바 시간 표기(`01:15`)가 목록 표기(`1:15`)와 다르고, 바 높이·행 클릭 분기 위치가 미정 (§7.3, T4-3) | 바 전용 `formatClock`(`mm:ss`, 1시간 이상 `h:mm:ss`, 비정상 값 `00:00`)을 추가하고 `formatDuration`은 유지. 진행 표시는 `PlayerProgress`로 분리해 `timeupdate` 리렌더를 격리. 행 클릭 분기(READY 재생, 변환 중·실패 토스트)는 `usePlayTrack`. 바 내용(슬라이더 24px + 컨트롤 48px + 여백)이 72px를 넘어 `--player-height`를 96px로 변경 | 마지막 행이 바에 가려지지 않게 하고 표기 의도를 분리 (T4-3, 사용자 승인 2026-11-12) |
| 36 | 볼륨·음소거·반복·Space·Media Session 세부 동작이 미정 (§7.3, T4-4) | 저장·복원은 `playerPreferences.ts`(기본 볼륨 1·음소거 해제, NaN·빈 문자열·0~1 밖은 기본값, `muted`는 정확히 `'true'`만 true, 모든 접근 try/catch)로 분리하고 `PlayerProvider`는 수정하지 않는다(바 안 `PlayerVolume`이 마운트 시 `useLayoutEffect`로 audio에 적용, 반복의 단일 출처는 `audio.loop`). 음소거 중 볼륨을 올리면 음소거 해제. `Space`는 인터랙티브 요소 포커스에서는 무시(버튼 기본 동작 우선). 볼륨 슬라이더는 `max-width: 480px`에서 CSS로 숨기고 음소거 버튼은 유지(확인: Playwright 360px에서 `getComputedStyle(슬라이더).display === 'none'`). 401 로그아웃 시 재생 정지는 하지 않는다(이미 받은 `streamUrl`은 인증이 필요 없음) | 첫 재생 전에 값이 적용돼야 하고 `audio`는 `detachStream` 뒤에도 volume·muted·loop를 유지함. 버튼 위 Space의 이중 토글 방지 (T4-4, 사용자 승인 2026-11-12) |
| 37 | 접근성 마감 방식이 미정 (§9.3, T5-2) | 모달이 열려 있는 동안 `#root`를 `inert`로 만들고 토스트 영역은 body 포털로 옮겨 제외한다(`<audio>`는 inert여도 재생된다). 행 다운로드 버튼 이름은 `{title} 원본 다운로드`, 반복 토글은 `Repeat1`↔`Repeat`, 현재 재생 행 제목은 흰색+좌측 accent 바(accent 텍스트 4.03:1 위반 제거). 전송이 끝나면 포커스를 제목 입력으로 복귀. 토스트 닫기 버튼은 두지 않는다(WCAG 2.2.1 정보성 알림, 오류는 모달 인라인 alert로 별도 표시) | 스크린리더 가상 커서가 `aria-modal`에만 의존하지 않게 하고 색만으로 상태를 전달하지 않기 위함 (T5-2, 사용자 승인 2026-11-12) |
| 38 | 오류 경계 분할과 번들 분할 여부가 미정 (§14, T5-3) | 최상위 `ErrorBoundary`는 유지하고 목록·플레이어 바를 각각 감싼다(`PlayerProvider`는 바깥). 바 경계가 오류를 잡으면 `stop()`으로 재생을 멈추고 현재 곡을 비워 바를 제거하며 토스트(id `player-crash`)로 알린다. 번들은 **분할하지 않고** `hls.js`를 `attachHlsStream`에서 정적 import하는 현 구조(§7.2)를 유지한다(메인 청크 raw 972KB, gzip 약 308KB, hls.js 기여 gzip 약 181KB). 필요해지면 동적 import(B)를 별도 태스크로 검토한다 | `<audio>`는 `ErrorBoundary` 바깥이라 바가 사라져도 소리만 계속 나면 사용자가 멈출 수 없음. 온프레미스 단일 오리진이라 첫 로드 증가분이 작고 캐시된 재방문엔 비용이 없으며, 동적 import는 `requestId`·`detachStream` 경합 위험을 재생 경로에 추가함 (T5-3, 사용자 승인 2026-11-12) |

## 17. 통합 확인 항목과 MVP 이후 과제

**통합 테스트에서 확인할 항목 (문서만으로 확정 불가)**

* Nginx 경유 다운로드에서 `Content-Disposition`(한글 파일명)이 유지되는지, presigned 서명 쿼리가 Nginx 내부 리다이렉트를 거쳐도 보존되는지, `<a download>`가 `X-Frame-Options` 등 헤더와 무관하게 동작하는지(§8, 백엔드 인덱스 §7.1). 백엔드 단독 스모크에서는 `X-Accel-Redirect`·`Content-Disposition`·`Content-Type` 헤더 생성과 presigned 직접 GET 성공이 확인되었고, Nginx 경유 구간만 미확인입니다.
* 개발 서버(`5173`)를 거친 Google 로그인에서 `redirect_uri`가 `http://localhost/login/oauth2/code/google`로 계산되는지(`changeOrigin`, §12.2)
* hls.js `/stream` 재생에서 시크 시 Nginx 캐시·`Range` 응답이 정상인지, 반복재생 시 `audio.loop`와 HLS 조합의 끊김 여부
* 분리 배포 구성(`allowed-origins` 비어 있지 않음)에서 동일 오리진 요청의 `Origin` 판정. Nginx의 `Host`/`X-Forwarded-*` 전달 설정에 영향을 받을 수 있으며, 단일 오리진 기본 구성(CORS 비활성)에서는 해당하지 않습니다.
* 참고(백엔드 스모크 결과): 생성된 `index.m3u8`에는 `#EXT-X-PLAYLIST-TYPE:VOD`가 없지만 `#EXT-X-ENDLIST`가 있어 hls.js·Safari 모두 VOD로 재생됩니다. 통합 테스트에서 시크·총 길이 표시가 정상인지 함께 확인합니다.

**MVP 이후 과제**

* 로그인 토큰을 URL 쿼리 대신 일회용 코드 교환 방식으로 전환(백엔드와 협의)
* `DOWNLOAD` 이력의 사용자 귀속(단기 다운로드 토큰 등, 백엔드 계약 변경 필요)
* 스트리밍 `auth_request` 통제 시 `/stream` 요청의 인증 처리
* 재생목록·다음 곡 자동 재생, 다중 음질(ABR) 선택 UI, Refresh Token 대응

## 18. 개발 단계 요약

상세 태스크(ID·선행·완료 조건·체크박스)는 `.claude/docs/ROADMAP.md`를 따릅니다(Phase 0~6, 29개 태스크). 단계 순서는 아래와 같습니다. Phase N은 F(N)에 대응합니다.

| 단계 | 내용 | 선행 |
|---|---|---|
| F0 | 골격(Vite·TS·ESLint·Vitest·MSW), `api/client`·`types`·에러 정규화, 토큰·글로벌 스타일 | - |
| F1 | 인증: 로그인 모달, `/auth/callback`, `AuthProvider`, 아바타·프로필 팝오버, 만료·탭 동기화 | F0 |
| F2 | 목록·검색: 무한 스크롤, 디바운스 검색, 상태 뱃지, 폴링 훅 | F0 |
| F3 | 업로드: 모달, `readAudioTags`, 진행률·취소, 오류 인라인 | F1, F2 |
| F4 | 플레이어: `PlayerProvider`, `attachHlsStream`, 하단 바 컨트롤, 볼륨 저장 | F2 |
| F5 | 다운로드, 접근성·반응형 마감, 오류 경계 | F2, F4 |
| F6 | Playwright E2E(Milestone 1)와 §17 통합 확인 | F1~F5, 전체 스택 |
