# Nginx 리버스 프록시 + 통합 docker 스택

온프레미스 도커 환경의 **음원 스트리밍·아카이빙 MVP**에서 유일한 외부 진입점(`:80`)을 담당하는 Nginx 설정과, 전체 서비스(PostgreSQL, RustFS, 백엔드 2노드, Nginx)를 한 번에 띄우는 `docker-compose.yml`을 관리하는 저장소입니다.

> **상태:** 구현 및 통합 검증 완료 (2026-11-12, ROADMAP 23/23 태스크)

## 개요

웹·모바일 클라이언트는 Nginx로만 요청하고, Nginx가 경로를 보고 백엔드 클러스터, 음원 서버(RustFS), SPA 정적 파일로 분배합니다. 미디어 바이트(HLS 청크, 앨범아트, 원본 다운로드)는 백엔드 스레드를 거치지 않고 Nginx와 RustFS 사이에서 전송됩니다.

| 이 저장소가 하는 일 | 이 저장소가 하지 않는 일 |
|---|---|
| Nginx 설정(envsubst 템플릿, 캐시, 로그 마스킹, 보안 헤더, 속도 제한) | 백엔드·프론트엔드·모바일 코드 수정 (필요 시 PRD §10에 요청 사항으로만 기록) |
| 통합 스택(`docker-compose.yml`, `.env.example`, `db/init.sql`, `scripts/storage-init.sh`) | `init.sql` 스키마·버킷 정책 내용 설계 (각각 PRD-07, PRD-06 소관) |
| 스모크 스크립트와 통합 검증 기록 | TLS 종단, 도메인, 외부 로드밸런서 (MVP는 `http://localhost`) |

## 아키텍처

```text
                         ┌──────────────► backend_cluster (web-server-1/2, 라운드로빈) ─► PostgreSQL
 클라이언트 ──► Nginx :80 ┼──────────────► RustFS (/stream, /artwork 직접 프록시 + 캐시)
                         ├──────────────► RustFS (/internal-storage, X-Accel-Redirect 전용)
                         └──────────────► SPA 정적 파일 (/usr/share/nginx/html)
```

| 요청 경로 | 대상 | 비고 |
|---|---|---|
| `/api`, `/api/*`, `/oauth2/*`, `/login/oauth2/*` | `backend_cluster` | `Host`·`X-Forwarded-*` 전달, 업로드 한도 `110M` |
| `/stream/*` | RustFS `hls/*` | `.m3u8` 5초, `.ts` 24시간 캐시, CORS |
| `/artwork/*` | RustFS `artwork/*` | 7일 `immutable` 캐시 |
| `/internal-storage/*` | RustFS | `internal;` 전용. 백엔드의 `X-Accel-Redirect`로만 진입(직접 호출은 `404`) |
| `/healthz` | Nginx 자체 응답 | 컨테이너 헬스체크, 접근 로그 제외 |
| 그 외 `/` | SPA (`../frontend-dist` 마운트) | `try_files … /index.html` |

SPA가 쓸 수 없는 경로 접두: `/api`, `/oauth2`, `/login/oauth2`, `/stream`, `/artwork`, `/internal-storage`, `/healthz`

## 주요 기능

- **envsubst 템플릿:** `nginx/templates/**/*.template`을 기동 시 치환. `NGINX_ENVSUBST_FILTER=^(BACKEND_|STORAGE_)`로 범위를 제한해 `$uri`, `$1` 같은 Nginx 변수가 지워지지 않게 함
- **HLS 스트리밍:** `.m3u8` 5초 / `.ts` 24시간 캐시, `proxy_cache_lock`, 404·5xx는 캐시하지 않음, `Range` 요청 지원
- **원본 다운로드:** 백엔드가 `X-Accel-Redirect`로 보낸 presigned URL을 쿼리 재인코딩 없이 RustFS에 전달. 한글 `Content-Disposition` 유지 확인
- **JWT 로그 마스킹(필수):** 로그인 콜백 `/auth/callback?token={jwt}`가 접근 로그의 `$request`·`$http_referer`에 남지 않도록 `map`으로 마스킹하고 SPA에 `Referrer-Policy: no-referrer` 적용
- **보안 헤더·CSP:** SPA, `/stream`, `/artwork`에만 적용(`/api`는 Spring Security가 처리). CSP는 Report-Only 검증 후 강제로 전환 완료
- **속도 제한·한도:** 업로드·로그인 진입 각 30r/m(burst 10) → `429`, 업로드 `110M` 초과 → JSON `413`
- **원본 보호 3중:** ① RustFS `original/` 익명 읽기 금지 ② presigned 60초 서명 ③ Nginx `internal;`

## 서비스 구성

| 서비스 | 이미지 | 호스트 노출 | 역할 |
|---|---|---|---|
| `postgres-db` | `postgres:16-alpine` | `127.0.0.1:5432` | 메타데이터 (`db/init.sql` 자동 적용) |
| `rustfs` | `rustfs/rustfs:latest` | `127.0.0.1:9000`, `127.0.0.1:9001` | S3 호환 스토리지 |
| `storage-init` | `amazon/aws-cli:latest` | 없음 | 버킷 생성 + `hls/*`, `artwork/*` 익명 읽기 정책 후 종료 |
| `web-server-1` / `web-server-2` | `music-backend:latest` | 없음 (내부 `8080`) | 백엔드 2노드 |
| `nginx` (`nginx-proxy`) | `nginx:1.30-alpine` | `80:80` | 유일한 외부 공개 포트 |

기동 순서: `postgres-db`·`rustfs` healthy → `storage-init` 정상 종료 → `web-server-1/2` → `nginx`

## 디렉터리 구조

```text
.
├── docker-compose.yml
├── .env.example                  # .env는 .gitignore 대상
├── .gitattributes                # * text=auto eol=lf
├── nginx/templates/
│   ├── nginx.conf.template
│   └── snippets/                 # proxy-backend, proxy-hls, security-headers, csp-spa
├── db/init.sql                   # PRD-07 §6 DDL 그대로
├── scripts/
│   ├── storage-init.sh           # 버킷 + 익명 읽기 정책
│   ├── smoke.sh                  # V-10~V-25 스모크
│   └── integration-checklist.md  # 검증 결과 기록
└── .claude/docs/                 # PRD, ROADMAP, PROGRESS, API 등 기준 문서
```

## 시작하기

### 사전 준비

- Docker Desktop (Windows), 호스트 포트 `80` 비어 있음(IIS 등 점유 확인)
- 백엔드 이미지 `music-backend:latest` 빌드 (백엔드 저장소 소관)
- 프론트엔드 `npm run build` 산출물을 `../frontend-dist`에 배치
- Google Console 승인된 리디렉션 URI: `http://localhost/login/oauth2/code/google`

### 환경변수

`.env.example`을 복사해 `.env`를 만들고 시크릿을 채웁니다. `.env`는 커밋하지 않습니다.

| 변수 | 설명 |
|---|---|
| `DB_NAME` / `DB_USERNAME` / `DB_PASSWORD` | PostgreSQL |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google OAuth2 |
| `JWT_SECRET_KEY` | 32바이트 이상 |
| `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` | 비밀키 8자 이상 |
| `STORAGE_ENDPOINT` / `STORAGE_HOST_HEADER` | **host:port가 반드시 동일**해야 함 (다르면 원본 다운로드 `403`) |
| `STORAGE_UPSTREAM` / `STORAGE_BUCKET_NAME` | `rustfs:9000` / `audio-storage` |
| `BACKEND_UPSTREAM_1` / `BACKEND_UPSTREAM_2` / `BACKEND_IMAGE` / `FRONTEND_DIST_DIR` | 업스트림, 이미지, 정적 파일 경로 |
| `OAUTH2_DEFAULT_REDIRECT_URI` / `OAUTH2_ALLOWED_REDIRECT_URIS` | 개발 서버 콜백(`:5173`)은 개발 `.env`에서만 추가 |
| `MEDIA_PUBLIC_BASE_URL` / `CORS_ALLOWED_ORIGINS` | 단일 오리진이면 빈 값 |

### 실행·운영 명령어

```bash
docker compose up -d                          # 전체 스택 기동
docker compose restart nginx                  # 템플릿 수정 후 재치환
docker compose config --quiet                 # compose 문법 검증
docker exec nginx-proxy nginx -t              # 설정 문법 검증 (V-01)
docker logs nginx-proxy                       # upstream:/cache:/rt= 확인
bash scripts/smoke.sh                         # V-10~V-25 스모크 (BASE_URL 기본 http://localhost)
```

- Git Bash는 `/`로 시작하는 인자를 윈도우 경로로 바꾸므로 `docker exec`는 `sh -c "..."`로 감싸고, `docker run`에는 `MSYS_NO_PATHCONV=1`을 붙입니다.
- CRLF로 체크아웃된 `.conf`·`.sh`·`.sql`은 컨테이너에서 오류가 나므로 `.gitattributes`(LF)를 유지합니다.
- 스모크의 업로드 속도 제한 호출은 실행당 3회라 연속 실행해도 `429`가 나지 않습니다. 나면 1분 뒤 재실행합니다.
- `docker compose down -v` 등 볼륨 삭제 명령은 `.claude/settings.json`이 막고 있습니다.

## 검증

| 단계 | 항목 | 수단 |
|---|---|---|
| 정적 | V-01~V-03 (`nginx -t`, 치환 결과, Nginx 변수 보존) | `docker exec` |
| 스모크 | V-10~V-25 (SPA, API, 스트림, 업로드 한도, 로드밸런싱) | `scripts/smoke.sh` |
| 통합 | V-30~V-70 (다운로드, HLS 캐시, 로그인, CSP, 로그 마스킹, E2E) | 수동·브라우저, 기록: `scripts/integration-checklist.md` |

결과는 통과/실패/미확인과 근거를 함께 기록하며, 확인하지 못한 항목은 통과로 적지 않습니다.

**미확인 항목:**
- V-41: 개발 서버(`:5173`) 경유 로그인 (운영 기본값에 개발 콜백을 넣지 않음)
- `/artwork/*` 실제 `Content-Type` (앨범아트가 있는 곡이 없음)
- 정상 multipart 110MB 초과 업로드의 브라우저 동작 (업로드를 110MB 이하로 제한할 계획)

## 개발 진행 내역

| Phase | 내용 | 태스크 | 상태 |
|---|---|---|---|
| 0 | 저장소 골격: `.gitattributes`, `.env.example`, `db/init.sql`, `storage-init.sh`, 스모크 뼈대 | T0-1~5 | ✅ |
| 1 | Nginx 템플릿 기본: 골격·`/healthz`, 백엔드 프록시, SPA 서빙 | T1-1~3 | ✅ |
| 2 | 스트리밍·다운로드: HLS, 앨범아트, `X-Accel-Redirect` | T2-1~3 | ✅ |
| 3 | 보안·운영: JWT 로그 마스킹, 보안 헤더·CSP, 속도 제한·413 JSON | T3-1~3 | ✅ |
| 4 | 통합 스택 기동: compose, `smoke.sh` | T4-1~3 | ✅ |
| 5 | 통합 검증: 다운로드, HLS 캐시, 로그인, CSP 강제 전환, E2E, 문서 마감 | T5-1~6 | ✅ |

**주요 결정 (PRD §11.2):**
- nginx 이미지 `1.26-alpine`(EOL) → `1.30-alpine`
- `/api` 경계 정규식을 `(/|$)`로 변경해 `/api` 단독 요청이 SPA로 떨어지지 않게 함
- `/stream`을 `.m3u8` 5초 / `.ts` 24시간 캐시로 분리
- `proxy_hide_header Content-Disposition` 유지로 확정 (V-30 통과)
- CSP는 초안 그대로 Report-Only에서 강제로 전환 (완화한 지시어 없음)
- `/assets/`·`/artwork/`의 `Cache-Control`에서 `always` 제거 (404 장기 캐시 방지)

## 알려진 한계·이후 과제

- `error_log`에는 `token` 마스킹이 적용되지 않으며, 대문자(`TOKEN=`)·퍼센트 인코딩·중복 `token` 파라미터는 마스킹되지 않음 (정상 콜백에서는 발생하지 않아 수용)
- Google 일회용 인가 코드(`code=`)는 마스킹하지 않음 (단회용·PKCE 결합이라 수용)
- Docker Desktop(Windows)에서는 클라이언트가 게이트웨이 IP 하나로 보여 IP별 속도 제한이 사실상 전역 제한

MVP 이후 과제: 로그인 토큰의 일회용 코드 교환 전환, `auth_request` 기반 스트리밍 권한 통제, TLS·HSTS·도메인 적용, 백엔드 헬스 엔드포인트 기반 능동 헬스체크, 다운로드 이력 사용자 귀속·다중 음질(ABR)

## 관련 문서

문서 우선순위: `API.md` > `PRD-05` > `PRD-06` > `PRD-07` > `PRD-04` > `PRD.md` > `PRD-01` (충돌 시 임의 판단하지 말고 확인 후 PRD §11에 기록)

- [`PRD.md`](.claude/docs/PRD.md): 이 저장소의 메인 기준 문서
- [`ROADMAP.md`](.claude/docs/ROADMAP.md): Phase 0~5 태스크와 완료 조건
- [`PROGRESS.md`](.claude/docs/PROGRESS.md): 진행 기록
- [`API.md`](.claude/docs/API.md), `PRD-01`~`PRD-07`: 백엔드·스토리지·DB 계약
- [`CLAUDE.md`](CLAUDE.md): Claude Code 작업 지침
