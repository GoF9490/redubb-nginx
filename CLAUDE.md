# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 저장소 현황

아직 구현 코드가 없고 **설계 문서만 있는 초기 상태**입니다(`.claude/docs/`). 빌드·린트·테스트 도구도 없습니다. 구현 대상은 **Nginx 리버스 프록시 + 통합 docker 스택**이며, 기준 문서는 `.claude/docs/PRD.md`입니다. 작업 순서는 PRD §13(N0~N5)을 따르고, 상세 태스크는 후속 `.claude/docs/ROADMAP.md`(`/docs:update-roadmap`이 갱신)로 분리될 예정입니다.

이 저장소의 범위는 Nginx 설정, `docker-compose.yml`, `.env.example`, `db/init.sql`(PRD-07 §6 DDL을 **그대로 복사**), `scripts/storage-init.sh`, 검증 스크립트입니다. 백엔드·프론트엔드·모바일 코드는 다른 저장소 소관이므로 수정하지 않고, 필요한 변경은 PRD §10에 요청 사항으로만 기록합니다.

## 문서 우선순위

`API.md` > `PRD-05` > `PRD-06` > `PRD-07` > `PRD-04` > `PRD.md` > `PRD-01`. 문서 간 충돌을 발견하면 임의로 판단하지 말고 사용자에게 확인한 뒤 PRD §11(결정 이력)에 기록합니다. `PRD-04`는 `PRD.md`가 대체한 초안이므로 수정하지 않습니다. `PRD-01`~`07` 머리말의 "`PRD.md` §7 참조"는 이 문서가 아니라 삭제된 구 백엔드 인덱스를 뜻합니다.

## 아키텍처 (여러 문서를 읽어야 보이는 큰 그림)

Nginx(`:80`)가 유일한 외부 진입점이며 경로로 세 곳에 분배합니다.

- `/api`, `/oauth2`, `/login/oauth2` → `backend_cluster` (web-server-1/2 라운드로빈)
- `/stream/*`, `/artwork/*` → RustFS 직접 프록시 (백엔드를 거치지 않음, 캐시·CORS)
- `/internal-storage/*` → `internal;` 전용. 백엔드가 `GET /api/tracks/{id}/download`에서 `X-Accel-Redirect`로 보낸 presigned URL로만 진입
- 그 외 → SPA 정적 파일(`/usr/share/nginx/html`, 호스트의 `../frontend-dist` 마운트)

SPA가 쓸 수 없는 경로 접두는 `/api`, `/oauth2`, `/login/oauth2`, `/stream`, `/artwork`, `/internal-storage`, `/healthz`입니다.

## 반드시 지켜야 할 계약

- **`STORAGE_HOST_HEADER`는 백엔드 `STORAGE_ENDPOINT`의 host:port와 동일**해야 합니다(presigned 서명 검증 기준). 다르면 원본 다운로드가 `403`입니다.
- **envsubst 템플릿:** 설정은 `nginx/templates/**/*.template`(스니펫 포함)로 두고 `NGINX_ENVSUBST_FILTER=^(BACKEND_|STORAGE_)`로 치환 범위를 제한합니다. `$uri`, `$1` 등 Nginx 변수가 지워지면 안 됩니다. 템플릿 수정 후에는 `docker compose restart nginx`가 필요합니다.
- **JWT 마스킹(필수):** 로그인 콜백이 `/auth/callback?token={jwt}`라서 접근 로그의 `$request`와 `$http_referer`를 `map`으로 마스킹하고, SPA에 `Referrer-Policy: no-referrer`를 붙입니다. 수용 기준은 `access.log`에 토큰 문자열이 0건인 것(V-52).
- `add_header`는 location 단위로 상속이 끊기므로 보안 헤더·CSP는 스니펫을 `include`합니다. `/api` 경로 응답에는 Spring Security가 이미 헤더를 붙이므로 Nginx가 추가하지 않습니다.
- 정규식 location은 `proxy_pass`에 URI를 쓸 수 없어 `/stream/`은 `rewrite … break;` 후 `proxy_pass http://s3_storage;`를 씁니다. `.m3u8`은 5초, `.ts`는 24h 캐시이고 404/5xx는 캐시하지 않습니다.
- 업로드 한도 `client_max_body_size 110M`은 Spring `max-request-size 110MB`와 같아야 합니다.
- CSP는 `Content-Security-Policy-Report-Only`로 먼저 적용하고 V-51 통과 후 강제로 전환합니다.
- 외부 공개 포트는 `80` 하나이며 PostgreSQL·RustFS는 `127.0.0.1`에만 바인딩합니다. 백엔드 이미지(`music-backend`)는 이 저장소에서 빌드하지 않습니다.

## 명령어 (구현 후 사용, PRD §8 기준)

```bash
docker compose up -d                          # 전체 스택 기동 (nginx는 service_started 기준으로 대기)
docker compose restart nginx                  # 템플릿 수정 후 재치환
docker exec nginx-proxy nginx -t              # V-01 문법 검증
docker exec nginx-proxy grep -nE "server |Host |proxy_pass" /etc/nginx/nginx.conf   # V-02 치환 결과
docker logs nginx-proxy                       # upstream:/cache:/rt= 확인 (V-25)
bash scripts/smoke.sh                         # V-01~V-25 정적·스모크 (작성 예정)
```

단일 검증 항목은 PRD §8의 ID(V-xx)별 curl 명령을 그대로 실행합니다. 결과(통과/실패/미확인)와 근거는 `scripts/integration-checklist.md`에 기록하며, 직접 확인하지 못한 항목을 통과로 적지 않습니다. 미확인 사항(V-30 `Content-Disposition` 유지, V-33 Range, V-24 `proxy_request_buffering off`의 413 동작, RustFS 경로별 정책)은 PRD §11.3에 있습니다.

## 환경·규칙

- Windows 환경이라 CRLF로 체크아웃된 `.conf`·`.sh`·`.sql`은 컨테이너 안에서 오류를 냅니다. 첫 태스크에서 `.gitattributes`(`* text=auto eol=lf`)를 추가합니다. 기존 파일의 `git add --renormalize .`는 사용자 확인 후에만 합니다.
- `.env`는 `.gitignore` 대상이고 `.claude/settings.json`이 읽기를 차단합니다. `.env.example`에는 예시 값만 넣습니다.
- `.claude/settings.json`은 `git push`, 파괴적 git 명령, Docker 볼륨 삭제(`down -v`, `volume rm/prune`, `system prune`)를 deny합니다.
- 커밋 메시지는 한국어 + gitmoji(예: `📝 docs: …`, `🔧 chore: …`)입니다. 커밋 명령은 `/git:commit`, 브랜치는 `/git:branch`를 사용합니다.
- 문서와 코드 주석은 한국어, 식별자는 영어, 들여쓰기는 4칸입니다.
