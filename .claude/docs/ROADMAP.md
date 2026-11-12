# ROADMAP: Nginx 리버스 프록시 및 통합 docker 스택

**📅 최종 업데이트:** 2026-11-12
**📊 진행 상황:** 전체 완료 (23/23 Tasks 완료)

> 기준 문서: [`PRD.md`](./PRD.md) §13(개발 단계 요약). 이 문서는 PRD 단계 N0~N5를 Phase 0~5로 1:1 대응시켜 태스크로 쪼갠 것입니다.
> 문서 우선순위: `API.md` > `PRD-05` > `PRD-06` > `PRD-07` > `PRD-04` > `PRD.md` > `PRD-01`. 충돌을 발견하면 임의로 판단하지 말고 사용자에게 확인합니다.
> 체크박스는 `/docs:update-roadmap`이 갱신합니다. 현황판과 태스크 본문의 형식(`- [ ] **T0-1**`, `#### T0-1.`)을 바꾸지 마세요.

## 0. 서브 에이전트 공통 규약

1. **읽을 범위:** 맡은 태스크의 "참조" 절만 읽습니다. PRD 전체를 다시 읽지 않습니다(`CLAUDE.md`에 요약이 있습니다).
2. **수정 금지:** `PRD-01`~`PRD-07`, `API.md`는 수정하지 않습니다. 계약과 다른 값을 쓰게 되면 `PRD.md` §11(결정 이력)에 기록하고 사용자에게 보고합니다. 백엔드·프론트엔드 코드는 이 저장소 범위가 아닙니다(요청 사항은 PRD §10에만 기록).
3. **미확인은 통과가 아님:** 직접 실행하지 못한 검증 항목은 `scripts/integration-checklist.md`에 "미확인"으로 남깁니다. 결과는 통과/실패/미확인과 근거(명령 출력 요약)를 함께 적습니다.
4. **완료 보고:** 완료 조건마다 증거(실행한 명령과 출력 요약)를 제출한 뒤에 `/docs:update-roadmap T{ID}`를 호출합니다. 증거 없이 체크하지 않습니다.
5. **커밋:** 커밋은 오케스트레이터가 검토 후 수행합니다. 에이전트는 커밋하지 않으며, `git push`는 누구도 하지 않습니다(`settings.json`에서 deny).
6. **작성 규칙:** 파일은 LF, 주석·문서는 한국어, 식별자는 영어, 들여쓰기는 4칸입니다(Nginx `.conf`도 4칸).
7. **Nginx 단독 검증(Phase 1~3):** 백엔드·RustFS가 없으면 upstream 호스트 해석 실패로 `nginx -t`가 실패합니다. 이때는 환경변수를 `BACKEND_UPSTREAM_1=127.0.0.1:8080` 같은 값으로 치환해 `docker run --rm`으로 검증하고, 실제 호스트명(`web-server-1` 등)은 compose 기동 후(Phase 4) 다시 확인합니다.
8. **destructive 명령 금지:** `docker compose down -v`, 볼륨 삭제, `git reset --hard` 등은 `settings.json`이 막고 있으며 우회하지 않습니다.
9. **템플릿 수정 후:** 치환은 컨테이너 기동 시점에만 일어납니다. `docker compose restart nginx`(단독 검증이면 컨테이너 재생성) 후 `nginx -t`를 실행합니다.

## 1. 사용자 조치 필요 항목 (에이전트가 대신할 수 없음)

| 시점 | 항목 | 비고 |
|---|---|---|
| T0-2 이후 | `.env` 작성(실제 시크릿) | `.env`는 `settings.json`이 읽기를 막습니다. 에이전트는 `.env.example`만 다룹니다 |
| T4-2 전 | 백엔드 이미지 `music-backend:latest` 빌드 | 백엔드 저장소 소관. 없으면 T4-2는 대기 |
| T1-3 이후 | 프론트엔드 `npm run build` 산출물을 `../frontend-dist`에 배치 | 폴더가 비면 임시 `index.html`로 대체(T1-3) |
| T4-2 전 | Windows 포트 `80` 점유 확인(IIS 등) | 점유 시 호스트 포트만 바꾸면 Google 리디렉션 URI도 바뀌므로 사용자 결정 필요 |
| T5-1 전 | 한글 파일명 샘플 음원 업로드 | V-30은 한글 파일명 곡이 필요 |
| T5-3 | Google 로그인 브라우저 조작, Google Console에 리디렉션 URI `http://localhost/login/oauth2/code/google` 등록 | 에이전트는 인증 정보를 입력할 수 없음 |

## 2. 진행 현황판

### Phase 0: 저장소 골격 (PRD N0)

- [x] **T0-1** 규약 파일·디렉터리 (선행: -)
- [x] **T0-2** `.env.example` (선행: T0-1)
- [x] **T0-3** `db/init.sql` (선행: T0-1)
- [x] **T0-4** `scripts/storage-init.sh` (선행: T0-1)
- [x] **T0-5** 검증 기반 `smoke.sh` 뼈대 + 체크리스트 틀 (선행: T0-1)

### Phase 1: Nginx 템플릿 기본 (PRD N1) ✅

- [x] **T1-1** `nginx.conf.template` 골격·`/healthz`·이미지 태그 확정 (선행: T0-1)
- [x] **T1-2** 백엔드 프록시 스니펫과 location 3종 (선행: T1-1)
- [x] **T1-3** SPA 정적 서빙 (선행: T1-1)

### Phase 2: 스트리밍·다운로드 (PRD N2) ✅

- [x] **T2-1** HLS 스트리밍 `/stream` (선행: T1-1)
- [x] **T2-2** 앨범아트 `/artwork` (선행: T2-1)
- [x] **T2-3** 원본 다운로드 `/internal-storage` (선행: T1-1)

### Phase 3: 보안·운영 (PRD N3) ✅

- [x] **T3-1** 접근 로그 JWT 마스킹 (선행: T1-3)
- [x] **T3-2** 보안 헤더·CSP(Report-Only) (선행: T2-1, T1-3)
- [x] **T3-3** 속도 제한·413 JSON (선행: T1-2)

### Phase 4: 통합 스택 기동 (PRD N4) ✅

- [x] **T4-1** compose: postgres-db·rustfs·storage-init (선행: T0-2, T0-3, T0-4)
- [x] **T4-2** compose: web-server-1/2·nginx 전체 기동 (선행: T4-1, T2-3, T3-1, T3-2, T3-3, T2-2)
- [x] **T4-3** `smoke.sh` 완성·실행 (선행: T4-2, T0-5)

### Phase 5: 통합 검증 (PRD N5) ✅

- [x] **T5-1** 원본 다운로드 검증 (선행: T4-3)
- [x] **T5-2** HLS 캐시·시크 검증 (선행: T4-3)
- [x] **T5-3** 로그인·속도 제한 실사용 검증 (선행: T4-3)
- [x] **T5-4** 보안 헤더·CSP 강제 전환 (선행: T5-2, T5-3)
- [x] **T5-5** E2E·분리 배포 검증 (선행: T5-1, T5-4)
- [x] **T5-6** 문서 마감 (선행: T5-5)

---

## 3. Phase 0: 저장소 골격

#### T0-1. 규약 파일·디렉터리

- **목표:** CRLF 문제를 막는 `.gitattributes`, `.gitignore`, PRD §6의 디렉터리 골격을 만든다.
- **선행:** -
- **참조:** PRD §6
- **산출물:** `.gitattributes`(`* text=auto eol=lf`), `.gitignore`(`.env`, 로컬 임시 산출물), `nginx/templates/snippets/`, `db/`, `scripts/`
- **완료 조건:**
    - [x] `git check-attr eol -- x.conf x.sh x.sql`이 세 파일 모두 `eol: lf`를 출력한다
    - [x] `git check-ignore .env`가 성공하고 `git check-ignore .env.example`은 실패한다(추적 대상)
    - [x] 디렉터리 `nginx/templates/snippets`, `db`, `scripts`가 존재한다(빈 폴더는 `.gitkeep`)
- **주의:**
    - [구현] 이미 커밋된 파일의 `git add --renormalize .`는 **사용자 확인 후에만** 한다. 현재 커밋된 파일은 문서와 JSON뿐이라 필요 여부부터 보고한다.

#### T0-2. `.env.example`

- **목표:** 통합 스택에 필요한 환경변수를 한 파일로 통합한다.
- **선행:** T0-1
- **참조:** PRD §5.3, PRD-05 §4.3, PRD-06 §3 Step 1, PRD-07 §7
- **산출물:** `.env.example`
- **완료 조건:**
    - [x] PRD §5.3 표의 모든 변수(선택 변수 5종 포함)가 파일에 존재한다(변수 목록을 `grep -c`로 대조한 출력 첨부)
    - [x] 시크릿 값은 예시 값뿐이다(실제 Google 자격증명 형태의 문자열 없음)
    - [x] `STORAGE_ENDPOINT`와 `STORAGE_HOST_HEADER`의 host:port가 동일하다는 주석이 있다
    - [x] 개발 서버 콜백 `http://localhost:5173/auth/callback`은 **주석으로만** 안내한다(운영 기본값에 포함하지 않음)
- **주의:**
    - [탐색] `.env.example`은 읽을 수 있지만 `.env`는 읽기가 막혀 있다. `.env`를 만들거나 읽으려 하지 않는다.
    - [검토] `JWT_SECRET_KEY` 예시는 32바이트 이상, `RUSTFS_SECRET_KEY`는 8자 이상인지 확인한다.

#### T0-3. `db/init.sql`

- **목표:** PRD-07 §6의 DDL을 그대로 복사한다.
- **선행:** T0-1
- **참조:** PRD-07 §6
- **산출물:** `db/init.sql`
- **완료 조건:**
    - [x] 파일 내용이 PRD-07 §6 코드 블록과 diff 0이다(추출한 블록과의 `diff` 출력 첨부)
    - [x] `users`, `tracks`, `playback_logs` 세 테이블의 `CREATE TABLE`이 있다
- **주의:**
    - [계획] 스키마를 개선하고 싶어도 **수정하지 않는다**(PRD-07 소관). 문제를 발견하면 보고만 한다.

#### T0-4. `scripts/storage-init.sh`

- **목표:** 버킷을 만들고 `hls/*`, `artwork/*`만 익명 읽기를 허용하는 정책을 적용한다.
- **선행:** T0-1
- **참조:** PRD §5.2(마지막 불릿), PRD-06 §3 Step 2
- **산출물:** `scripts/storage-init.sh`
- **완료 조건:**
    - [x] `sh -n scripts/storage-init.sh`가 통과한다
    - [x] 정책 JSON의 `Resource`가 `hls/*`, `artwork/*`뿐이고 `s3:GetObject`만 허용하며 `s3:ListBucket`이 없다(PRD-06 §3과 대조)
    - [x] 버킷이 이미 있어도 재실행이 오류 없이 끝난다(멱등, 로직을 코드로 설명하거나 T4-1에서 실제 확인)
    - [x] 성공 시 'PRD-06이 정한 완료 문구'를 로그로 출력한다
- **주의:**
    - [탐색] 실행 이미지는 `amazon/aws-cli`라 entrypoint가 `aws`다. compose에서 `/bin/sh`로 덮어쓴다. 엔드포인트는 `--endpoint-url http://rustfs:9000`이다.
    - [구현] 정책 내용은 인라인 heredoc 이스케이프 오류가 나기 쉬워 파일로 분리했다. 정책 내용 자체는 바꾸지 않는다.

#### T0-5. 검증 기반 (`smoke.sh` 뼈대 + 체크리스트 틀)

- **목표:** 이후 모든 Phase가 같은 형식으로 결과를 남기도록 검증 도구의 공통 부분을 만든다(이 저장소의 "테스트 기반").
- **선행:** T0-1
- **참조:** PRD §8
- **산출물:** `scripts/smoke.sh`(헬퍼 함수: `check`/`pass`/`fail`/`skip`, 대상 URL 변수 `BASE_URL`, 요약·종료 코드), `scripts/integration-checklist.md`
- **완료 조건:**
    - [x] `bash -n scripts/smoke.sh`가 통과한다
    - [x] 대상이 없는 상태(`BASE_URL=http://127.0.0.1:1`)에서 실행하면 FAIL을 출력하고 비정상 종료 코드로 끝난다
    - [x] `integration-checklist.md`에 PRD §8의 V-ID 29개가 모두 있고 결과는 전부 "미확인"이다(ID 개수 대조 출력 첨부)
    - [x] 체크리스트 각 행에 결과·근거·수행일 열이 있다
- **주의:**
    - [계획] 이 단계에서는 개별 V 항목 구현을 하지 않는다(T4-3에서 완성). 헬퍼와 틀만 만든다.
    - [구현] 시크릿이 출력에 섞이지 않게 한다. 증거 출력에서 `token=`은 가려서 기록한다.

---

## 4. Phase 1: Nginx 템플릿 기본

#### T1-1. `nginx.conf.template` 골격·`/healthz`·이미지 태그 확정

- **목표:** 전역 설정, 업스트림, `/healthz`까지 있는 최소 설정을 만들고 nginx 이미지 태그를 확정한다.
- **선행:** T0-1
- **참조:** PRD §3.1, §3.10, §4(기준 설정), §11.3(이미지 태그)
- **산출물:** `nginx/templates/nginx.conf.template`
- **완료 조건:**
    - [x] 단독 컨테이너에서 `nginx -t`가 `syntax is ok`, `test is successful`을 출력한다
    - [x] V-02: 치환된 `/etc/nginx/nginx.conf`에 upstream·Host·버킷명이 기대값으로 들어 있다
    - [x] V-03: 치환된 `nginx.conf`에 `$uri`, `$1` 등이 남아 있다
    - [x] `NGINX_ENVSUBST_FILTER=^(BACKEND_|STORAGE_)`가 적용되어 로그 포맷 `map`의 `${…}` 캡처가 지워지지 않는다
    - [x] V-13: `curl -I /healthz`가 `200`이고 접근 로그에 남지 않는다
    - [x] nginx 이미지 태그(PRD 기준 `1.26-alpine`)가 현행 지원 안정판인지 공식 릴리스로 확인한 결과를 기록한다(PRD §11.3 반영용 메모)
- **주의:**
    - [탐색] 공식 이미지 envsubst는 `/etc/nginx/templates/*.template`을 `NGINX_ENVSUBST_OUTPUT_DIR`로 출력한다. 하위 폴더 구조가 유지되는지 실제로 확인한다.
    - [구현] 변수 이름이 `STORAGE_`, `BACKEND_`로 시작하지 않는 `${…}`를 새로 도입하지 않는다(치환되지 않음).
    - [검토] 이 시점에서 location은 `/healthz`뿐이어도 되지만, 이후 태스크가 `include`할 스니펫 경로(`/etc/nginx/snippets/`)를 미리 맞춘다.

#### T1-2. 백엔드 프록시 스니펫과 location 3종

- **목표:** `/api`, `/oauth2`, `/login/oauth2`를 `backend_cluster`로 전달한다.
- **선행:** T1-1
- **참조:** PRD §2.1(`/api` 경계), §3.5, §4, §11.2 #4·#9
- **산출물:** `nginx/templates/snippets/proxy-backend.conf.template`, `nginx.conf.template`의 location 3종(업로드 정확 일치, 로그인 진입 정확 일치, 정규식 `^/(api|oauth2|login/oauth2)(/|$)`)
- **완료 조건:**
    - [x] `nginx -t` 통과
    - [x] 치환 결과에 `Host $http_host`, `X-Forwarded-Host $http_host`, `X-Forwarded-Proto`, `X-Forwarded-For`, `X-Real-IP`, `Connection ""`, 타임아웃 60s/120s/120s가 존재한다
    - [x] 백엔드가 없는 단독 환경에서 `curl -I /api`와 `/api/tracks`가 SPA `200`이 아니라 `502`를 반환한다
    - [x] 업로드 location에 `proxy_request_buffering off`가 있고 `proxy_next_upstream` 기본값을 건드리지 않았다
    - [x] 이 스니펫은 `add_header`를 추가하지 않는다(Spring과 중복 방지)
- **주의:**
    - [계획] 속도 제한(`limit_req`)은 T3-3에서 붙인다. 지금은 넣지 않는다.
    - [구현] `X-Forwarded-Host`에 `$http_host`(포트 포함)를 쓰는 이유는 §11 #9. 포트 `80`에서는 `$host`와 같으므로 V-40/V-41(T5-3)에서 확인한다.

#### T1-3. SPA 정적 서빙

- **목표:** `/`, SPA 라우트, `/assets/`를 서빙한다.
- **선행:** T1-1
- **참조:** PRD §3.6, §4(5-a, 5-b)
- **산출물:** `nginx.conf.template`의 `/assets/`·`/` location, 확인용 임시 `index.html`(저장소에 커밋하지 않음, 임시 마운트용)
- **완료 조건:**
    - [x] V-10: `curl -I /`가 `200`, `Cache-Control: no-cache`
    - [x] V-11: `curl -I /auth/callback`이 `200`(index.html)
    - [x] V-12: `curl -I /assets/없는파일.js`가 `404`(HTML로 대체되지 않음)
    - [x] `/assets/` 응답에 `Cache-Control: public, max-age=31536000, immutable`이 있다(실제 파일을 임시로 두고 확인)
    - [x] 예약 경로(`/api` 등) 접두가 SPA로 떨어지지 않는다
- **주의:**
    - [탐색] `../frontend-dist`가 존재하면 실제 빌드 산출물의 자산 폴더명(`/assets`)과 `index.html`의 스크립트 경로를 확인한다(PRD §10 #4). 없으면 가정이라고 보고에 명시한다.
    - [구현] `add_header`는 location 내부에서 상속이 끊긴다. 보안 헤더 `include`는 T3-2에서 추가한다(이 태스크에서 빠뜨려도 결함 아님).

---

## 5. Phase 2: 스트리밍·다운로드

#### T2-1. HLS 스트리밍 `/stream`

- **목표:** `.m3u8`은 5초, 그 외(`.ts`)는 24시간 캐시로 RustFS에서 프록시한다.
- **선행:** T1-1
- **참조:** PRD §3.3, §4(2-a, 2-b, 스니펫 표), §11.2 #2·#3
- **산출물:** `nginx/templates/snippets/proxy-hls.conf.template`, `/stream` location 2종
- **완료 조건:**
    - [x] `nginx -t` 통과, 치환 결과에 `rewrite ^/stream/(.*)$ /audio-storage/hls/$1 break;`가 있다
    - [x] V-22: `OPTIONS /stream/x/index.m3u8`(Origin 포함)이 `204`와 CORS 헤더 4종을 반환한다
    - [x] V-23: `POST /stream/x`가 `405` 또는 `403`이다
    - [x] `.m3u8`은 `200 5s`, `.ts`는 `200 24h`로 location이 분리되어 있고 404/5xx는 `proxy_cache_valid`에 없어 캐시되지 않는다
    - [x] `Authorization ""`, `proxy_cache_lock on`, 캐시 키 `$uri`, `X-Cache-Status` 응답 헤더가 있다
- **주의:**
    - [계획] `OPTIONS`를 `204`로 처리할 때 `if` 안에서 `add_header`가 따로 필요한 상속 문제가 있다. `always` 사용 여부와 함께 설계 후 구현한다.
    - [구현] `rewrite … break;` 뒤 `proxy_cache_key "$uri"`의 `$uri`는 rewrite 후 값이다. 키 충돌이 없는지 확인한다(artwork와 같은 캐시 존 공유).
    - [검토] `Range` 요청의 캐시 동작과 시크는 실제 RustFS가 필요하므로 T5-2(V-33)로 이관하고, 이 태스크에서는 통과로 적지 않는다.

#### T2-2. 앨범아트 `/artwork`

- **목표:** 앨범아트를 7일 `immutable` 캐시로 서빙한다.
- **선행:** T2-1
- **참조:** PRD §3.4, §4(3)
- **산출물:** `/artwork/` location
- **완료 조건:**
    - [x] `nginx -t` 통과, 치환 결과에 `proxy_pass http://s3_storage/audio-storage/artwork/;`가 있다
    - [x] `POST /artwork/x`가 `403` 또는 `405`이다
    - [x] 응답 헤더 설정에 `Cache-Control: public, max-age=604800, immutable`과 `Access-Control-Allow-Origin *`가 있다
    - [x] `x-amz-id-2`, `x-amz-request-id`가 숨겨진다
- **주의:**
    - [구현] 실제 `Content-Type`(`image/jpeg`/`image/png`) 전달은 RustFS가 필요하므로 T4-1 이후 확인 대상으로 체크리스트에 남긴다.

#### T2-3. 원본 다운로드 `/internal-storage`

- **목표:** `X-Accel-Redirect` 전용 내부 location을 만든다.
- **선행:** T1-1
- **참조:** PRD §3.2, §4(4), §11.2 #5
- **산출물:** `/internal-storage/` location(`internal;`)
- **완료 조건:**
    - [x] `nginx -t` 통과
    - [x] V-20: `curl -I /internal-storage/original/test.wav`가 `404`(직접 호출 차단)
    - [x] 치환 결과에 `proxy_pass http://s3_storage/audio-storage/;`(URI 포함), `Host rustfs:9000`, `Authorization ""`, `proxy_buffering off`가 있다
    - [x] `proxy_pass`에 변수나 `rewrite`를 쓰지 않았다(쿼리 문자열 재인코딩 방지)
- **주의:**
    - [계획] `proxy_hide_header Content-Disposition`은 **일단 유지**하고, 실제 유지 여부는 V-30(T5-1)에서 결정한다. 이 태스크 완료 조건에 포함하지 않는다.
    - [검토] presigned 서명이 `Host`에 묶여 있으므로 `STORAGE_HOST_HEADER` 변수를 하드코딩하지 않았는지 확인한다.

---

## 6. Phase 3: 보안·운영

#### T3-1. 접근 로그 JWT 마스킹

- **목표:** `token` 쿼리 값이 접근 로그에 남지 않게 한다(필수).
- **선행:** T1-3
- **참조:** PRD §3.8, §4(map 블록), §11.2 #1
- **산출물:** `nginx.conf.template`의 `$loggable_request`, `$loggable_referer` map과 `log_format`
- **완료 조건:**
    - [x] V-52 단독: `/auth/callback?token=SECRET123`, `/auth/callback?a=1&token=SECRET123`, `/auth/callback?token=SECRET123&a=1` 세 경우 후 `grep -c SECRET123 access.log`가 `0`이다
    - [x] `Referer: http://localhost/auth/callback?token=SECRET123` 헤더로 요청해도 로그에 `SECRET123`이 없다
    - [x] 로그 줄에 `upstream:`, `cache:`, `rt=`가 남는다
    - [x] 마스킹이 정상 경로(`token`이 없는 요청)의 로그를 훼손하지 않는다
- **주의:**
    - [구현] map 정규식의 이름 있는 캡처(`?<reqBefore>`)는 `${reqBefore}` 형태라 envsubst 필터가 없으면 지워진다. T1-1의 필터가 동작하는지 치환 결과로 확인한다.
    - [검토] `error.log`에 요청 줄이 남을 수 있는 한계는 PRD에서 수용했다. 결과에 한계로 명시하고 해결하려 하지 않는다.

#### T3-2. 보안 헤더·CSP(Report-Only)

- **목표:** Nginx가 직접 응답하는 SPA, `/stream`, `/artwork`에만 보안 헤더를 붙인다.
- **선행:** T2-1, T1-3
- **참조:** PRD §3.7, §4(스니펫 표), §11.2 #8
- **산출물:** `snippets/security-headers.conf.template`, `snippets/csp-spa.conf.template`, 각 location의 `include`
- **완료 조건:**
    - [x] SPA 응답에 `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Content-Security-Policy-Report-Only`가 있다
    - [x] `/assets/*`, `/stream/*`, `/artwork/*` 응답에 `nosniff`가 있다
    - [x] `/api*` 응답에는 Nginx가 이 헤더들을 추가하지 않는다(백엔드 미기동 502 응답에서도 헤더 없음)
    - [x] CSP 문자열이 PRD §3.7 초안과 동일하다
    - [x] `server_tokens off`로 `Server` 헤더에 버전이 없다
- **주의:**
    - [구현] 각 location에 `add_header`가 하나라도 있으면 상위 값은 상속되지 않는다. 모든 대상 location에 `include`가 들어갔는지 목록으로 점검한다.
    - [검토] CSP를 **강제**로 전환하지 않는다(T5-4, V-51 이후).

#### T3-3. 속도 제한·413 JSON

- **목표:** 업로드·로그인 진입에 `limit_req`를 적용하고 `413`을 JSON으로 응답한다.
- **선행:** T1-2
- **참조:** PRD §3.5(413), §3.9, §11.2 #7·#10
- **산출물:** `limit_req_zone` 2종, `limit_req_status 429`, `error_page 413`
- **완료 조건:**
    - [x] `nginx -t` 통과
    - [x] 111MB 본문 요청이 `413`이고 본문이 `{"code":"PAYLOAD_TOO_LARGE",…}` JSON이며 `Content-Type: application/json`이다
    - [x] `/oauth2/authorization/google`을 41회 연속 호출하면 일부가 `429`이고 첫 호출들은 `429`가 아니다
    - [x] 정상 빈도(분당 수 회)에서는 `429`가 나오지 않는다
- **주의:**
    - [계획] `proxy_request_buffering off`일 때 `Content-Length` 없는(chunked) 요청의 `413`/연결 종료 동작은 이 단계에서 확정할 수 없다. 확인한 범위를 적고 나머지는 "미확인"으로 남긴다(PRD §11.2 #10, V-24).
    - [구현] 단독 환경에는 백엔드가 없으므로 `429` 판정은 응답 코드 분포로 한다(백엔드 응답은 `502`).
    - [검토] Docker Desktop(Windows)에서는 클라이언트가 게이트웨이 IP 하나로 보여 사실상 전역 제한이 된다. 초기값을 낮추지 않는다.

---

## 7. Phase 4: 통합 스택 기동

#### T4-1. compose: postgres-db·rustfs·storage-init

- **목표:** 데이터 계층 세 서비스를 기동하고 버킷·익명 정책을 확인한다.
- **선행:** T0-2, T0-3, T0-4
- **참조:** PRD §5.1, §5.2, PRD-06 §3, PRD-07 §7
- **산출물:** `docker-compose.yml`(`name`, `x-backend-env` 앵커, 세 서비스, 볼륨 3종)
- **완료 조건:**
    - [x] `docker compose config`가 오류 없이 통과한다(필수 변수 누락 경고 없음)
    - [x] `postgres-db`, `rustfs`가 `healthy`, `storage-init`이 exit 0으로 종료된다
    - [x] `\dt`로 `users`, `tracks`, `playback_logs`가 확인된다
    - [x] V-31: 테스트 객체를 `original/`, `hls/`, `artwork/`에 올린 뒤 익명 `GET`이 `original/`만 `403`, 나머지는 `200`이다(확인 후 테스트 객체 삭제)
    - [x] `postgres-db`·`rustfs`의 포트가 `127.0.0.1`에만 바인딩된다(`docker compose ps` 출력)
- **주의:**
    - [탐색] 사용할 `.env`는 사용자가 만든다(§1 표). 없으면 `docker compose config`를 임시 환경변수로만 검증하고 보고한다.
    - [계획] RustFS가 경로별 `Resource` 정책을 지원하지 않거나 `original/`이 익명 `GET`에 열려 있으면 **스택을 계속 진행하지 말고** 사용자에게 보고한다(보안 3중 보호 중 1겹이 무너짐, PRD §11.3).
    - [구현] RustFS 이미지에 `curl`이 있는지 확인한다. 없으면 헬스체크를 이미지에 맞게 바꾸고 §11에 기록한다.
    - [검토] `docker compose down -v`는 금지다. 초기화가 필요하면 사용자에게 요청한다.

#### T4-2. compose: web-server-1/2·nginx 전체 기동

- **목표:** 백엔드 2노드와 nginx를 추가해 전체 스택을 올린다.
- **선행:** T4-1, T2-2, T2-3, T3-1, T3-2, T3-3
- **참조:** PRD §5.1(기동 순서), §5.2
- **산출물:** `docker-compose.yml`의 `web-server-1/2`, `nginx` 서비스
- **완료 조건:**
    - [x] 백엔드 이미지가 로컬에 존재한다(`docker image inspect`). 없으면 **사용자 조치 대기**로 보고하고 이 태스크를 체크하지 않는다
    - [x] `docker compose ps`에서 모든 서비스가 기동 상태이고 nginx는 `healthy`다
    - [x] 실스택에서 V-01(`nginx -t`), V-02(치환 결과의 upstream이 `web-server-1:8080`, `web-server-2:8080`, `rustfs:9000`), V-03이 통과한다
    - [x] 외부 공개 포트가 호스트 `80`뿐이다(백엔드 `8080` 미노출)
- **주의:**
    - [탐색] 포트 `80` 점유(IIS 등)로 기동이 실패하면 임의로 포트를 바꾸지 않는다. 사용자에게 보고한다(Google 리디렉션 URI가 함께 바뀜).
    - [구현] 백엔드는 기동 시 버킷 존재를 확인하며 fail-fast다. 백엔드 컨테이너가 재시작을 반복하면 로그로 원인(DB/버킷/환경변수)을 구분해 보고한다.
    - [검토] nginx는 시작 시 upstream 호스트를 해석한다. 두 백엔드 컨테이너가 생성되어 있지 않으면 기동에 실패한다.

#### T4-3. `smoke.sh` 완성·실행

- **목표:** V-10~V-25를 자동화해 실행하고 결과를 기록한다.
- **선행:** T4-2, T0-5
- **참조:** PRD §8.2
- **산출물:** `scripts/smoke.sh`(V-10~V-25), 갱신된 `scripts/integration-checklist.md`
- **완료 조건:**
    - [x] V-10, V-11, V-12, V-13이 PASS다
    - [x] V-14: `/api/tracks`와 `/api`(슬래시 없음) 모두 백엔드 응답이며 SPA HTML이 아니다
    - [x] V-15: 토큰 없는 `/api/auth/me`가 `401` JSON이다
    - [x] V-20, V-21(`Access-Control-Allow-Origin: *`, `X-Cache-Status` 포함), V-22, V-23이 PASS다
    - [x] V-24: 111MB는 `413`, 110MB 이하는 백엔드로 전달된다(응답 코드가 인증 요구로 `401`이어도 Nginx를 통과했다는 근거로 판단, 근거 기재)
    - [x] V-25: `/api/tracks` 10회 호출 후 접근 로그의 `upstream:`에 web-server-1과 web-server-2가 모두 나타난다
    - [x] 체크리스트에 각 항목의 결과·근거·수행일이 기록되고, FAIL·미확인은 원인과 함께 남는다
- **주의:**
    - [탐색] 업로드 엔드포인트의 인증 요구 여부는 `API.md`로 확인한다. 문서와 실제 응답이 다르면 `API.md`를 수정하지 말고 보고한다.
    - [구현] 110MB 테스트 파일은 `dd`/`fsutil`로 임시 생성하고 저장소에 두지 않는다(스크래치패드 사용).
    - [검토] 직접 확인하지 못한 항목을 PASS로 적지 않는다.

---

## 8. Phase 5: 통합 검증

> 이 Phase는 샘플 음원 업로드와 `READY` 상태 곡이 필요합니다(§1 사용자 조치 참조).

#### T5-1. 원본 다운로드 검증

- **목표:** `X-Accel-Redirect` 다운로드 전체 경로를 검증하고 `Content-Disposition` 유지 여부를 확정한다(1순위).
- **선행:** T4-3
- **참조:** PRD §3.2, §8.3 V-30·V-32, §11.2 #5
- **산출물:** 체크리스트 기록, 필요 시 `/internal-storage/` 설정 수정
- **완료 조건:**
    - [x] V-30: 한글 파일명 곡의 `curl -sS -D - -o /tmp/d.bin …/download`가 `200`이고 `Content-Disposition: attachment; filename="…"; filename*=UTF-8''…`가 유지되며 sha256이 원본과 일치한다
    - [x] V-32: 응답이 `403 SignatureDoesNotMatch`가 아니다
    - [x] V-30에서 헤더가 누락됐다면 `proxy_hide_header Content-Disposition`을 제거하고 재검증한 결과를 PRD §11.2 #5에 기록했다(누락이 없었다면 "유지로 확정"을 기록)
- **주의:**
    - [계획] V-32가 `403`이면 `STORAGE_HOST_HEADER`와 백엔드 `STORAGE_ENDPOINT`의 host:port 불일치 또는 쿼리 재인코딩을 순서대로 의심한다.
    - [검토] 설정을 바꾼 경우 `nginx -t`와 T2-3의 V-20을 다시 통과시킨다.

#### T5-2. HLS 캐시·시크 검증

- **목표:** 실제 HLS 청크로 `Range` 요청과 캐시 동작을 확인한다.
- **선행:** T4-3
- **참조:** PRD §3.3, §8.3 V-33·V-34, §11.2 #2·#3
- **산출물:** 체크리스트 기록, 필요 시 캐시 설정 수정
- **완료 조건:**
    - [x] V-33: `curl -H "Range: bytes=0-99" …/chunk_000.ts`를 2회 호출해 `206`이고 두 번째가 `X-Cache-Status: HIT`이다
    - [x] V-34: `.m3u8` 연속 2회가 5초 이내 `HIT`, 5초 후 `EXPIRED` 또는 `MISS`다
    - [x] 브라우저 시크 시 총 길이·구간 이동이 정상이다(또는 확인하지 못했음을 "미확인"으로 기록)
- **주의:**
    - [탐색] 생성된 `index.m3u8`에는 `#EXT-X-PLAYLIST-TYPE:VOD`가 없고 `#EXT-X-ENDLIST`만 있다(PRD §11.2 #3). Nginx를 바꾸지 말고 시크 결과만 기록한다.
    - [검토] `Range` 요청이 캐시 MISS일 때 업스트림에 전체 객체가 요청되는지 `cache:` 로그로 확인한다.

#### T5-3. 로그인·속도 제한 실사용 검증

- **목표:** 멀티노드에서 Google 로그인이 안정적으로 동작하는지, 속도 제한이 정상 사용을 막지 않는지 확인한다.
- **선행:** T4-3
- **참조:** PRD §8.3 V-40·V-41·V-60, §3.9
- **산출물:** 체크리스트 기록
- **완료 조건:**
    - [x] V-40: 사용자가 Google 로그인을 5회 이상 반복해 `authorization_request_not_found` 없이 `/auth/callback?token=…`으로 복귀한다(사용자 수행, 에이전트는 로그로 확인)
    - [x] V-41: 개발 서버(`:5173`) 경유 로그인에서 `redirect_uri`가 `http://localhost/login/oauth2/code/google`로 계산된다(개발 콜백을 `.env`에 추가한 구성에서만. 하지 않았다면 "미확인")
    - [x] V-60: 정상 업로드·로그인 흐름에 `429`가 없고, 31회/분 초과 시나리오에서는 `429`가 난다
- **주의:**
    - [계획] 사용자의 브라우저 조작이 필요하다. 에이전트는 수행 요청 문구를 보고하고 결과 로그만 판정한다. 로그인 인증 정보는 요청하지 않는다.
    - [검토] 로그에 JWT가 남지 않았는지 이 시점에도 `grep`으로 확인한다.

#### T5-4. 보안 헤더·CSP 강제 전환

- **목표:** 실제 SPA에서 CSP 위반이 없는지 확인한 뒤 Report-Only를 강제로 전환한다.
- **선행:** T5-2, T5-3
- **참조:** PRD §3.7, §3.8, §8.3 V-50·V-51·V-52, §11.2 #8
- **산출물:** `csp-spa.conf.template` 수정, 체크리스트 기록
- **완료 조건:**
    - [x] V-50: SPA·`/stream`·`/artwork`에 `nosniff`, SPA에 `Referrer-Policy: no-referrer`와 CSP가 있고 `/api` 응답에 중복 헤더가 없다
    - [x] V-51: 로그인, 업로드, hls.js 재생, 프로필 이미지 표시 중 브라우저 콘솔(Playwright MCP 또는 사용자 확인)에 CSP 위반이 없다. 위반이 있으면 해당 지시어만 완화하고 PRD §11.2 #8에 기록했다
    - [x] V-52: 실스택에서 `/auth/callback?token=SECRET123` 호출 후 `access.log` 전체에 `SECRET123`이 0건이다(`Referer` 포함)
    - [x] 위 통과 후 `Content-Security-Policy-Report-Only`가 `Content-Security-Policy`로 전환되고 같은 시나리오가 다시 통과한다
- **주의:**
    - [탐색] `../frontend-dist`가 없으면 V-51을 검증할 수 없다. 임시 `index.html`로 통과 처리하지 말고 "미확인"으로 남긴다.
    - [계획] CSP 완화는 위반된 지시어 하나씩만 한다. `unsafe-inline` 도입이 필요해지면 프론트엔드 요청 사항(PRD §10 #5)으로 보고한다.

#### T5-5. E2E·분리 배포 검증

- **목표:** Milestone 1 E2E와 다운로드 흐름 전체를 확인한다.
- **선행:** T5-1, T5-4
- **참조:** PRD §8.3 V-61·V-62·V-70, §7
- **산출물:** 체크리스트 기록
- **완료 조건:**
    - [x] V-61: 백엔드 `DOWNLOAD` 이력이 기록되고 브라우저 `<a download>` 저장 파일명·바이트가 일치한다
    - [x] V-70: 프론트엔드 빌드를 마운트한 상태에서 업로드 → `READY` → 재생 → 반복재생 → 다운로드가 성공한다(사용자 조작 포함)
    - [x] V-62: `CORS_ALLOWED_ORIGINS`가 비어 있지 않은 분리 배포 구성을 쓰지 않으면 "해당 없음(사유)"으로 기록한다. 쓰면 동일 오리진 요청이 `403` 없이 통과한다
- **주의:**
    - [계획] 프론트엔드 Phase 6(T6-2 등)과 백엔드 T7-3 이관 항목의 선행 조건을 충족했음을 사용자에게 보고한다.

#### T5-6. 문서 마감

- **목표:** 검증 결과를 PRD와 CLAUDE.md에 반영한다.
- **선행:** T5-5
- **참조:** PRD §11.2, §11.3, §13
- **산출물:** `PRD.md` §11 갱신, `CLAUDE.md` 명령어 섹션 갱신
- **완료 조건:**
    - [x] PRD §11.3의 미결 항목(V-30, V-32, V-33, V-51, V-24, 경로별 정책, nginx 이미지 태그)이 모두 결과와 함께 §11.2로 옮겨졌거나 "미확인" 사유가 적혀 있다
    - [x] 값이 바뀐 설정(예: `proxy_hide_header` 제거, CSP 완화)이 §11.2 표에 새 행으로 기록되어 있다
    - [x] `CLAUDE.md`의 "구현 후 사용" 명령어가 실제 존재하는 스크립트·값으로 갱신되고 "구현 전" 안내 문구가 제거되었다
    - [x] `scripts/integration-checklist.md`에 "미확인"이 남아 있다면 각각 사유가 있다
- **주의:**
    - [검토] 이 태스크에서만 PRD.md를 수정한다. `PRD-01`~`07`과 `API.md`는 여전히 수정하지 않는다.

---

## 9. 이관·미결 추적표

| PRD §11.3 미결 항목 | 해결 태스크 | 기록 위치 |
|---|---|---|
| V-30 `Content-Disposition` 유지 | T5-1 | PRD §11.2 #5 |
| V-32 서명 보존 | T5-1 | 체크리스트 |
| V-33 `Range`/캐시 | T5-2 | 체크리스트 |
| V-51 CSP | T5-4 | PRD §11.2 #8 |
| V-24 `request_buffering off`의 413 동작 | T3-3(부분), T4-3 | PRD §11.2 #10 |
| RustFS 경로별 버킷 정책 | T4-1 | 체크리스트(V-31) |
| nginx 이미지 태그 현행 여부 | T1-1 | PRD §11.3 |
