# [PRD] Nginx 리버스 프록시 및 통합 docker 스택 상세 설계 (v1.0)

> **작성일:** 2026-11-12
> **목적:** 구현·검증이 끝난 백엔드(`PRD-05`, 스모크 테스트 완료)와 웹 프론트엔드(React SPA, Phase 0~5 완료)의 **실제 계약**에 맞는 Nginx 설정과 통합 docker 스택을 개발하기 위한 이 저장소의 메인 기준 문서입니다. `PRD-04`(Nginx 초안, v1.2)를 대체하며, 달라진 점은 §11에 기록합니다. `PRD-04`는 수정하지 않습니다.
> **문서 우선순위:** `API.md` > `PRD-05` > `PRD-06` > `PRD-07` > `PRD-04` > 이 문서 > `PRD-01`. (계약 값은 구현이 끝난 쪽이 우선입니다. 웹 프론트엔드가 Nginx에 요구하는 사항은 이 문서 §2·§3·§10에 반영되어 있습니다.) 충돌이 발견되면 임의로 판단하지 말고 사용자에게 확인한 뒤 §11에 기록합니다.
> **참조 표기 주의:** `PRD-01`~`PRD-07` 머리말의 "`PRD.md` §7 참조"는 이 문서가 아니라 **구 백엔드 인덱스**의 결정 이력을 뜻합니다. 백엔드·프론트엔드의 인덱스와 로드맵(`PRD-backend.md`, `ROADMAP-backend.md`, `PRD-frontend.md`, `ROADMAP-frontend.md`)은 해당 저장소의 구현 기록이라 이 저장소에서 삭제했습니다(§11.1 U3). 필요한 계약은 이 문서와 `API.md`, `PRD-01`·`04`·`05`·`06`·`07`에 있으며, 본문의 "백엔드/프론트엔드 …" 표기는 삭제된 문서의 출처 표기로 git 이력(`62ea318`)에서 확인할 수 있습니다.

## 1. 개요 및 범위

### 1.1. 제품에서의 위치

온프레미스 도커 환경의 음원 스트리밍·아카이빙 MVP(PRD-01)에서 Nginx(`:80`)는 **유일한 외부 진입점**입니다. 웹·모바일 클라이언트는 Nginx로만 요청하고, Nginx가 경로를 보고 백엔드 클러스터, 음원 서버(RustFS), SPA 정적 파일로 분배합니다. 미디어 바이트(HLS 청크, 앨범아트, 원본 다운로드)는 백엔드 스레드를 거치지 않고 Nginx ➔ RustFS 구간에서 전송됩니다.

### 1.2. 이 저장소가 하는 일

| 영역 | 내용 |
|---|---|
| Nginx 설정 | `nginx.conf.template`(envsubst), 스니펫, 로그 마스킹, 캐시, 보안 헤더, 속도 제한 |
| 통합 스택 | `docker-compose.yml`(postgres-db, rustfs, storage-init, web-server-1/2, nginx), `.env.example`, `db/init.sql`, `scripts/storage-init.sh` |
| 검증 | 스모크 스크립트(`scripts/`), 통합 확인 항목(§8), 프론트엔드 Phase 6(E2E)과 백엔드 T7-3 이관 항목의 선행 조건 충족 |

### 1.3. 이 저장소가 하지 않는 일

* 백엔드·프론트엔드·모바일 앱 코드 수정. 필요한 변경은 구현하지 않고 §10에 **요청 사항**으로만 기록합니다.
* `init.sql`의 스키마 설계(`PRD-07` 소관). 이 저장소는 `PRD-07 §6` DDL을 **그대로 복사**해 마운트만 합니다.
* 버킷 정책의 내용 설계(`PRD-06 §3` 소관). 이 저장소는 정책을 적용하는 `storage-init`을 실행만 합니다.
* 모바일 앱(`PRD-03`) 빌드·배포.
* TLS 종단, 도메인, 외부 로드밸런서(MVP는 `http://localhost`). 분리 배포 시 조치만 §7에 정리합니다.

## 2. 아키텍처·라우팅 계약

### 2.1. 경로표

| 요청 경로 | 대상 | 백엔드 경유 | 비고 |
|---|---|:---:|---|
| `/api`, `/api/*`, `/oauth2/*`, `/login/oauth2/*` | `backend_cluster` (web-server-1/2 라운드로빈) | O | `Host`·`X-Forwarded-*` 전달, 업로드 `110M` |
| `/stream/*` | RustFS `/{bucket}/hls/*` | X | `.ts` 장기 캐시, `.m3u8` 단기 캐시, CORS |
| `/artwork/*` | RustFS `/{bucket}/artwork/*` | X | 캐시 7일, `immutable` |
| `/internal-storage/*` | RustFS `/{bucket}/*` | 내부 전용 | `internal;`, 직접 호출 `404`. 백엔드의 `X-Accel-Redirect`로만 진입 |
| `/healthz` | Nginx 자체 응답 | X | 컨테이너 헬스체크용, 접근 로그 제외 |
| 그 외 `/` | SPA 정적 파일 (`/usr/share/nginx/html`) | X | `try_files … /index.html` |

* **SPA가 쓸 수 없는 경로:** `/api`, `/oauth2`, `/login/oauth2`, `/stream`, `/artwork`, `/internal-storage`, `/healthz` 접두. 웹 로그인 콜백이 `/auth/callback`인 이유입니다(PRD-05 §6.1).
* **업로드 용량:** Nginx `client_max_body_size 110M` = Spring `max-request-size 110MB`(음원 100MB + 앨범자켓 10MB).
* **`/api` 경계:** 정규식은 `^/(api|oauth2|login/oauth2)(/|$)`입니다. PRD-04의 `…/)`는 끝 슬래시가 필수라 `/api` 단독이 SPA `index.html`(200)로 떨어지는 문제가 있어 변경합니다(§11 #4).

### 2.2. 핵심 데이터 흐름 (Nginx 관점)

| 시나리오 | Nginx의 역할 |
|---|---|
| 업로드 | `POST /api/tracks/upload`를 백엔드로 전달. 용량 한도·속도 제한·타임아웃 담당 |
| 스트리밍 | `GET /stream/{uuid}/index.m3u8`, `chunk_NNN.ts`를 RustFS에서 가져와 캐시·CORS 헤더 부여 |
| 원본 다운로드 | 백엔드의 `GET /api/tracks/{id}/download`가 Body 없이 `X-Accel-Redirect: /internal-storage/original/…?X-Amz-…`를 반환 ➔ Nginx가 서명된 요청을 RustFS로 보내 파일을 클라이언트에 전달 |
| 로그인 | `/oauth2/*`, `/login/oauth2/*`를 백엔드로 전달하고 접속 주소 정보(`Host`, `X-Forwarded-*`)를 보존해 Google `redirect_uri`가 올바르게 계산되게 함. 성공 후 `/auth/callback?token={jwt}`는 SPA가 처리 |

## 3. Nginx 상세 요구사항

### 3.1. 환경변수 템플릿 (envsubst)

공식 `nginx` 이미지는 기동 시 `/etc/nginx/templates/**/*.template`의 `${환경변수}`를 치환해 `NGINX_ENVSUBST_OUTPUT_DIR`(`/etc/nginx`)에 출력합니다(하위 폴더 구조 유지, `.template` 접미사 제거). 호스트·버킷명은 설정 파일에 하드코딩하지 않습니다.

| 변수 | 기본값 | 설명 |
|---|---|---|
| `BACKEND_UPSTREAM_1` / `BACKEND_UPSTREAM_2` | `web-server-1:8080` / `web-server-2:8080` | 백엔드 노드 |
| `STORAGE_UPSTREAM` | `rustfs:9000` | RustFS S3 API |
| `STORAGE_HOST_HEADER` | `rustfs:9000` | RustFS로 보내는 `Host`. **백엔드 `STORAGE_ENDPOINT`의 host:port와 반드시 동일** (presigned 서명 검증 기준, PRD-05 §7.1.2) |
| `STORAGE_BUCKET_NAME` | `audio-storage` | 버킷명 (PRD-05/06과 동일) |

* **치환 범위 제한:** `NGINX_ENVSUBST_FILTER=^(BACKEND_|STORAGE_)`를 설정합니다. 정의되지 않은 `${…}`와 `$1`, `$uri` 같은 Nginx 내장 변수·정규식 캡처는 치환되지 않아야 합니다.
* **재시작 필요:** 치환은 컨테이너 기동 시점에만 수행되므로 템플릿 수정 후에는 `docker compose restart nginx`가 필요합니다.

### 3.2. 원본 다운로드 (`X-Accel-Redirect`)

* `location /internal-storage/`는 `internal;`로 외부 직접 호출을 `404`로 차단합니다.
* `proxy_pass http://s3_storage/${STORAGE_BUCKET_NAME}/;`(URI 포함 prefix location)로 **presigned 쿼리 문자열을 재인코딩 없이** RustFS에 전달합니다. `Host`는 `${STORAGE_HOST_HEADER}`로 고정하고 `Authorization`은 비웁니다.
* `Content-Disposition`(RFC 5987 한글 파일명)과 `Content-Type`은 백엔드가 지정한 값이 최종 응답에 유지되어야 합니다. RustFS 응답의 내부 식별 헤더(`x-amz-id-2`, `x-amz-request-id`)는 숨깁니다.
* 대용량 원본(최대 100MB)은 `proxy_buffering off`로 디스크 버퍼링 없이 전송합니다.
* **통합 테스트 1순위 항목:** `proxy_hide_header Content-Disposition`을 둔 상태에서 헤더가 유지되는지 확인합니다(§8, V-30). 유지되지 않으면 해당 줄을 제거하고 §11 #5에 기록합니다.

### 3.3. HLS 스트리밍 (`/stream/*`)

| 대상 | 캐시 | 사유 |
|---|---|---|
| `*.ts` | `proxy_cache_valid 200 24h`, `proxy_cache_lock on` | 불변 객체, 반복 재생·시크 시 RustFS 부하 감소 |
| `*.m3u8` | `proxy_cache_valid 200 5s` | 매니페스트는 짧게. 변환 중·재생성에도 오래된 목록이 남지 않게 함 (§11 #2) |
| 404/5xx | 캐시하지 않음 | `READY` 이전 요청이 부정 캐시로 남는 것 방지 |

* 정규식 location(`.m3u8`/`.ts` 분리)은 `proxy_pass`에 URI를 쓸 수 없으므로 `rewrite ^/stream/(.*)$ /${STORAGE_BUCKET_NAME}/hls/$1 break;` 후 `proxy_pass http://s3_storage;`를 사용합니다.
* `Range` 요청은 Nginx 캐시가 처리해야 합니다(캐시 사용 시 업스트림에는 전체 객체 요청). 시크 동작은 통합 테스트로 확인합니다(V-33).
* 허용 메서드는 `GET`, `HEAD`, `OPTIONS`입니다(`limit_except`). `OPTIONS`는 `204`와 CORS 헤더로 응답합니다.
* CORS: `Access-Control-Allow-Origin *`, `Allow-Methods GET, HEAD, OPTIONS`, `Allow-Headers Range, Origin, Accept, Content-Type`, `Expose-Headers Content-Length, Content-Range`. 단일 오리진 웹에서는 불필요하지만 분리 배포·모바일 대비로 유지합니다.
* 이 경로는 익명 읽기를 허용한 RustFS `hls/*`만 접근합니다. 클라이언트 인증 헤더는 RustFS로 전달하지 않습니다(`Authorization ""`).
* 확장 포인트: 추후 `auth_request /api/auth/check;` 1줄 추가(PRD-01 §5.3, 이 MVP 범위 밖).

### 3.4. 앨범아트 (`/artwork/*`)

* `proxy_pass http://s3_storage/${STORAGE_BUCKET_NAME}/artwork/;`, 캐시 7일, `Cache-Control: public, max-age=604800, immutable`(키가 UUID라 불변), 허용 메서드 `GET`, `HEAD`.
* `Content-Type`은 업로드 시 지정된 실제 MIME(`image/jpeg`/`image/png`)이 그대로 전달되어야 합니다.

### 3.5. 백엔드 프록시 (`/api`, `/oauth2`, `/login/oauth2`)

* 공통 프록시 헤더: `Host $http_host`, `X-Forwarded-Host $http_host`, `X-Forwarded-Proto $scheme`, `X-Forwarded-For $proxy_add_x_forwarded_for`, `X-Real-IP $remote_addr`, `Connection ""`(`proxy_http_version 1.1`, keepalive). `X-Forwarded-Host`는 포트를 포함해야 Spring `forward-headers-strategy: framework`가 비표준 포트에서도 `redirect_uri`를 올바르게 계산합니다(§11 #9).
* 타임아웃: `proxy_connect_timeout 60s`, `proxy_send_timeout 120s`, `proxy_read_timeout 120s`. `proxy_send_timeout`은 연속 쓰기 간격 기준이므로 느린 망의 100MB 업로드도 전송이 진행 중이면 끊기지 않습니다.
* 업로드(`= /api/tracks/upload`): `proxy_request_buffering off`로 임시 디스크 사용 없이 백엔드로 전달하고, 속도 제한을 적용합니다. 비멱등 요청이라 재시도하지 않습니다(`proxy_next_upstream` 기본값 유지).
* 로그인 진입(`= /oauth2/authorization/google`): 속도 제한을 적용합니다.
* 이 경로의 응답에는 Nginx가 보안 헤더를 **추가하지 않습니다**. Spring Security가 `X-Content-Type-Options`, `X-Frame-Options` 등을 이미 붙이므로 중복을 피합니다.
* 업스트림: 노드당 `max_fails=3 fail_timeout=10s`. 백엔드에는 헬스 엔드포인트가 없으므로(actuator 미도입) 수동 헬스체크(요청 기반 장애 감지)만 사용합니다.
* `413` 응답은 프론트엔드의 에러 정규화와 맞도록 JSON(`{"code":"PAYLOAD_TOO_LARGE",…}`)을 반환하는 `error_page`를 둡니다. 프론트엔드는 HTML `413`도 `PAYLOAD_TOO_LARGE`로 추정하므로 필수는 아니며 일관성 목적입니다.

### 3.6. SPA 정적 서빙

| 대상 | 정책 |
|---|---|
| `/` 및 SPA 라우트 (`/auth/callback` 포함) | `try_files $uri $uri/ /index.html`, `Cache-Control: no-cache` (새 빌드 즉시 반영) |
| `/assets/*` | `Cache-Control: public, max-age=31536000, immutable`, `try_files $uri =404` (없는 JS가 `index.html`로 대체 응답되는 것 방지) |
| 압축 | `gzip on` (js, css, json, svg) |

* 정적 파일 루트는 `../frontend-dist`(프론트엔드 `npm run build` 출력)를 읽기 전용으로 마운트합니다. 해당 폴더가 비어 있으면 임시 `index.html`로 기동을 확인합니다(PRD-04 Step 1).
* 웹 빌드의 자산 폴더명이 `/assets`가 아니면(Vite 기본값 가정) 이 location을 조정합니다. 프론트엔드 저장소 산출물을 구현 시 확인합니다.

### 3.7. 보안 헤더와 CSP

대상은 **Nginx가 직접 응답하는 SPA, `/stream`, `/artwork`** 뿐입니다(`add_header`는 location 단위로 상속이 끊기므로 스니펫을 `include`합니다).

| 헤더 | 값 | 적용 |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | SPA, stream, artwork |
| `Referrer-Policy` | `no-referrer` | SPA (콜백 URL의 `token`이 `Referer`로 새는 것 차단, §3.8) |
| `Content-Security-Policy` | 아래 | SPA 응답만 |
| `server_tokens` | `off` | 전역 |

**CSP 초안** (구현 시 통합 테스트로 확정, 위반 시 완화 절차는 §11 #8):

```text
default-src 'self'; script-src 'self'; style-src 'self';
img-src 'self' data: blob: https://*.googleusercontent.com;
media-src 'self' blob:; worker-src 'self' blob:; connect-src 'self';
object-src 'none'; base-uri 'self'; frame-ancestors 'none'
```

* hls.js는 MSE로 `blob:` 미디어 소스를 사용하므로 `media-src blob:`가 필요합니다. Web Worker 사용 시 `worker-src blob:`도 필요합니다(프론트엔드 §15 #4).
* Google 프로필 이미지는 `profileImageUrl`(`lh3.googleusercontent.com` 등) 외부 이미지입니다.
* 도입 순서: 먼저 `Content-Security-Policy-Report-Only`로 적용해 브라우저 콘솔의 위반 보고를 확인하고, 재생·로그인·업로드가 통과하면 강제(`Content-Security-Policy`)로 전환합니다.

### 3.8. 접근 로그의 JWT 마스킹 (필수)

백엔드는 로그인 성공 시 `{redirect_uri}?token={jwt}`로 `302`하므로 웹 콜백 요청 `GET /auth/callback?token=…`이 접근 로그에 JWT를 남깁니다(프론트엔드 §15 #2, 백엔드 T6-5 "알려진 위험").

* `map`으로 `$request`의 `token=` 값을 `***`로 치환한 `$loggable_request`를 로그 포맷에 사용합니다.
* 같은 페이지가 불러오는 JS·CSS 요청의 `Referer`에도 토큰이 실릴 수 있으므로 `$http_referer`도 같은 방식으로 마스킹하고, SPA 응답에 `Referrer-Policy: no-referrer`를 붙여 이중으로 차단합니다.
* **수용 기준:** `/auth/callback?token=SECRET`을 호출한 뒤 `access.log` 전체에 `SECRET` 문자열이 없을 것(V-52).
* **알려진 한계:** `error.log`는 오류 시 요청 줄을 남길 수 있습니다. `/auth/callback`은 정적 파일 경로라 오류 가능성이 낮아 수용하고, 근본 해결(일회용 코드 교환)은 MVP 이후 과제(§12)입니다.

### 3.9. 속도 제한

| 대상 | 존 | 초기값 | 목적 |
|---|---|---|---|
| `= /api/tracks/upload` | `upload_limit` | 30r/m, burst 10 | 업로드 남용·FFmpeg 큐 포화 방지 |
| `= /oauth2/authorization/google` | `auth_limit` | 30r/m, burst 10 | 로그인 진입 남용 방지 |

* 상태 코드는 `429`(`limit_req_status`). 초기값은 정상 사용을 막지 않는 느슨한 값이며 운영 중 조정합니다.
* **주의:** Docker Desktop(Windows)에서는 모든 클라이언트가 게이트웨이 IP 하나로 보일 수 있어 IP별 제한이 사실상 전역 제한이 됩니다. 초기값을 느슨하게 두는 이유이며, 통합 테스트에서 정상 흐름이 `429`에 걸리지 않는지 확인합니다(V-60).

### 3.10. 기타 전역 설정

* `worker_processes auto;`, `worker_connections 1024;`, `sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65;`
* `listen 80 default_server; server_name _;` (IP·localhost 접근 모두 허용)
* `proxy_cache_path /var/cache/nginx/hls_cache levels=1:2 keys_zone=hls_cache:10m max_size=2g inactive=24h use_temp_path=off;` (stream과 artwork가 같은 존 공유, 키는 `$uri`)
* HLS MIME은 `mime.types`에 `m3u8`, `ts`가 포함되어 있으므로 별도 `types {}` 블록을 두지 않습니다(RustFS가 업로드 시 지정한 Content-Type이 그대로 전달됨).

## 4. 기준 설정 (`nginx/templates/nginx.conf.template`)

구현 태스크의 시작점인 기준안입니다. 세부 값은 통합 테스트 결과에 따라 조정하고 변경 시 §11에 기록합니다.

```nginx
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    server_tokens off;

    # [필수] 접근 로그에서 JWT(token 쿼리)를 마스킹한다 (§3.8)
    map $request $loggable_request {
        ~^(?<reqBefore>.*[?&]token=)[^&\s]*(?<reqAfter>.*)$  "${reqBefore}***${reqAfter}";
        default $request;
    }
    map $http_referer $loggable_referer {
        ~^(?<refBefore>.*[?&]token=)[^&\s]*(?<refAfter>.*)$  "${refBefore}***${refAfter}";
        default $http_referer;
    }
    log_format  main  '$remote_addr - $remote_user [$time_local] "$loggable_request" '
                      '$status $body_bytes_sent "$loggable_referer" "$http_user_agent" '
                      'upstream: $upstream_addr cache: $upstream_cache_status rt=$request_time';
    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;

    # 업로드 상한: 백엔드 max-request-size(110MB)와 동일
    client_max_body_size 110M;

    proxy_cache_path /var/cache/nginx/hls_cache levels=1:2 keys_zone=hls_cache:10m max_size=2g inactive=24h use_temp_path=off;

    limit_req_zone $binary_remote_addr zone=upload_limit:10m rate=30r/m;
    limit_req_zone $binary_remote_addr zone=auth_limit:10m   rate=30r/m;
    limit_req_status 429;

    upstream backend_cluster {
        server ${BACKEND_UPSTREAM_1} max_fails=3 fail_timeout=10s;
        server ${BACKEND_UPSTREAM_2} max_fails=3 fail_timeout=10s;
        keepalive 32;
    }

    upstream s3_storage {
        server ${STORAGE_UPSTREAM};
        keepalive 32;
    }

    server {
        listen       80 default_server;
        server_name  _;

        # 컨테이너 헬스체크 (SPA 존재 여부와 무관)
        location = /healthz {
            access_log off;
            default_type text/plain;
            return 200 "ok\n";
        }

        # 1-a. 업로드: 버퍼링 없이 전달 + 속도 제한
        location = /api/tracks/upload {
            limit_req zone=upload_limit burst=10 nodelay;
            proxy_request_buffering off;
            include /etc/nginx/snippets/proxy-backend.conf;
        }

        # 1-b. 로그인 진입 속도 제한
        location = /oauth2/authorization/google {
            limit_req zone=auth_limit burst=10 nodelay;
            include /etc/nginx/snippets/proxy-backend.conf;
        }

        # 1-c. 그 외 백엔드 경로 (/api 단독 포함)
        location ~ ^/(api|oauth2|login/oauth2)(/|$) {
            include /etc/nginx/snippets/proxy-backend.conf;
        }

        # 2-a. HLS 매니페스트: 짧은 캐시
        location ~ ^/stream/.+\.m3u8$ {
            proxy_cache_valid 200 5s;
            include /etc/nginx/snippets/proxy-hls.conf;
        }

        # 2-b. HLS 청크 및 기타: 장기 캐시
        location /stream/ {
            proxy_cache_valid 200 24h;
            include /etc/nginx/snippets/proxy-hls.conf;
        }

        # 3. 앨범 커버
        location /artwork/ {
            limit_except GET HEAD { deny all; }
            proxy_pass http://s3_storage/${STORAGE_BUCKET_NAME}/artwork/;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host ${STORAGE_HOST_HEADER};
            proxy_set_header Authorization "";
            proxy_hide_header x-amz-id-2;
            proxy_hide_header x-amz-request-id;
            proxy_cache hls_cache;
            proxy_cache_key "$uri";
            proxy_cache_lock on;
            proxy_cache_valid 200 7d;
            add_header Cache-Control "public, max-age=604800, immutable";
            add_header X-Cache-Status $upstream_cache_status always;
            add_header Access-Control-Allow-Origin * always;
            include /etc/nginx/snippets/security-headers.conf;
        }

        # 4. 원본 다운로드 전용 내부 경로 (X-Accel-Redirect)
        location /internal-storage/ {
            internal;
            proxy_pass http://s3_storage/${STORAGE_BUCKET_NAME}/;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host ${STORAGE_HOST_HEADER};   # presigned 서명 Host와 일치해야 함
            proxy_set_header Authorization "";
            proxy_hide_header Content-Disposition;           # V-30에서 헤더 유지 여부 확인, 실패 시 제거
            proxy_hide_header x-amz-id-2;
            proxy_hide_header x-amz-request-id;
            proxy_buffering off;
        }

        # 5-a. Vite 해시 자산: 장기 캐시, 없으면 404
        location /assets/ {
            root /usr/share/nginx/html;
            try_files $uri =404;
            add_header Cache-Control "public, max-age=31536000, immutable";
            include /etc/nginx/snippets/security-headers.conf;
        }

        # 5-b. SPA
        location / {
            root   /usr/share/nginx/html;
            index  index.html;
            try_files $uri $uri/ /index.html;
            add_header Cache-Control "no-cache" always;
            include /etc/nginx/snippets/security-headers.conf;
            include /etc/nginx/snippets/csp-spa.conf;
        }
    }
}
```

**스니펫** (`nginx/templates/snippets/*.conf.template` ➔ `/etc/nginx/snippets/*.conf`로 치환·출력):

| 파일 | 내용 |
|---|---|
| `proxy-backend.conf` | `proxy_pass http://backend_cluster;`, `proxy_http_version 1.1;`, §3.5의 헤더·타임아웃 |
| `proxy-hls.conf` | `limit_except GET HEAD OPTIONS`, `rewrite ^/stream/(.*)$ /${STORAGE_BUCKET_NAME}/hls/$1 break;`, `proxy_pass http://s3_storage;`, `Host ${STORAGE_HOST_HEADER}`, `Authorization ""`, `proxy_cache hls_cache; proxy_cache_key "$uri"; proxy_cache_lock on;`, `X-Cache-Status`, CORS, `OPTIONS` ➔ `204`, 보안 헤더 |
| `security-headers.conf` | `X-Content-Type-Options nosniff`, `Referrer-Policy no-referrer` |
| `csp-spa.conf` | §3.7 CSP (초기 `Content-Security-Policy-Report-Only`, T5-4에서 `Content-Security-Policy`로 강제 전환됨) |

## 5. 통합 docker 스택 명세

### 5.1. 서비스 구성

| 서비스 | 이미지 | 호스트 노출 | 역할 |
|---|---|---|---|
| `postgres-db` | `postgres:16-alpine` | `127.0.0.1:5432` | 메타데이터. `db/init.sql`을 `/docker-entrypoint-initdb.d/01-init.sql`에 읽기 전용 마운트 (PRD-07 §7) |
| `rustfs` | `rustfs/rustfs:latest` | `127.0.0.1:9000`, `127.0.0.1:9001` | S3 호환 스토리지 (PRD-06 §3) |
| `storage-init` | `amazon/aws-cli:latest` | 없음 | 버킷 생성 + 익명 읽기 정책(`hls/*`, `artwork/*`만) 적용 후 종료 |
| `web-server-1` / `web-server-2` | `${BACKEND_IMAGE:-music-backend:latest}` | 없음 (내부 `8080`만) | 백엔드 2노드 (`SPRING_PROFILES_ACTIVE=prod`) |
| `nginx` | `nginx:1.30-alpine` (T1-1에서 확인: 1.26은 EOL, 2026-11-12 기준 stable 1.30.x) | `80:80` | 유일한 외부 공개 포트 |

* **외부 공개 포트는 `80` 하나**입니다. PostgreSQL·RustFS는 루프백에만 바인딩하고, 백엔드는 호스트 포트를 노출하지 않습니다(PRD-01 §5.3).
* **백엔드 이미지:** 백엔드 저장소가 빌드한 이미지(`music-backend:*`)를 참조합니다. 이 저장소에서 백엔드를 빌드하지 않습니다.
* **기동 순서:** `postgres-db`, `rustfs` healthy ➔ `storage-init` 정상 종료 ➔ `web-server-1/2` 기동(백엔드는 기동 시 버킷 존재를 확인하며 fail-fast) ➔ `nginx`. 백엔드에 헬스 엔드포인트가 없으므로 `nginx`는 `service_started` 기준으로 기다립니다. Nginx는 시작 시 upstream 호스트를 해석하므로 두 백엔드 컨테이너가 생성되어 있어야 합니다.
* **nginx 헬스체크:** `wget -q --spider http://127.0.0.1/healthz`(alpine에서 `localhost`가 IPv6로 해석되는 문제를 피하기 위해 `127.0.0.1` 사용).

### 5.2. `docker-compose.yml` 기준안

```yaml
name: re-dubb

x-backend-env: &backend-env
    SPRING_PROFILES_ACTIVE: prod
    DB_HOST: postgres-db
    DB_PORT: 5432
    DB_NAME: ${DB_NAME:-streaming_db}
    DB_USERNAME: ${DB_USERNAME:-streaming_user}
    DB_PASSWORD: ${DB_PASSWORD}
    GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
    GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET}
    JWT_SECRET_KEY: ${JWT_SECRET_KEY}
    STORAGE_ENDPOINT: ${STORAGE_ENDPOINT:-http://rustfs:9000}
    STORAGE_BUCKET_NAME: ${STORAGE_BUCKET_NAME:-audio-storage}
    RUSTFS_ACCESS_KEY: ${RUSTFS_ACCESS_KEY}
    RUSTFS_SECRET_KEY: ${RUSTFS_SECRET_KEY}
    OAUTH2_DEFAULT_REDIRECT_URI: ${OAUTH2_DEFAULT_REDIRECT_URI:-http://localhost/auth/callback}
    OAUTH2_ALLOWED_REDIRECT_URIS: ${OAUTH2_ALLOWED_REDIRECT_URIS:-http://localhost/auth/callback,musicapp://oauth2/callback}
    MEDIA_PUBLIC_BASE_URL: ${MEDIA_PUBLIC_BASE_URL:-}
    CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-}
    TZ: Asia/Seoul

services:
    postgres-db:
        image: postgres:16-alpine
        container_name: postgres-db
        restart: unless-stopped
        environment:
            POSTGRES_DB: ${DB_NAME:-streaming_db}
            POSTGRES_USER: ${DB_USERNAME:-streaming_user}
            POSTGRES_PASSWORD: ${DB_PASSWORD}
            TZ: Asia/Seoul
        ports:
            - "127.0.0.1:5432:5432"
        volumes:
            - postgres-data:/var/lib/postgresql/data
            - ./db/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
        healthcheck:
            test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME:-streaming_user} -d ${DB_NAME:-streaming_db}"]
            interval: 10s
            timeout: 5s
            retries: 5

    rustfs:
        image: rustfs/rustfs:latest
        container_name: rustfs
        restart: unless-stopped
        command: /data
        environment:
            RUSTFS_ACCESS_KEY: ${RUSTFS_ACCESS_KEY}
            RUSTFS_SECRET_KEY: ${RUSTFS_SECRET_KEY}
            RUSTFS_ADDRESS: ":9000"
            RUSTFS_CONSOLE_ADDRESS: ":9001"
            RUSTFS_CONSOLE_ENABLE: "true"
            TZ: Asia/Seoul
        ports:
            - "127.0.0.1:9000:9000"
            - "127.0.0.1:9001:9001"
        volumes:
            - rustfs-data:/data
        healthcheck:
            test: ["CMD-SHELL", "curl -f http://localhost:9000/health || exit 1"]
            interval: 5s
            timeout: 3s
            retries: 5

    storage-init:
        image: amazon/aws-cli:latest
        container_name: storage-init
        depends_on:
            rustfs:
                condition: service_healthy
        environment:
            AWS_ACCESS_KEY_ID: ${RUSTFS_ACCESS_KEY}
            AWS_SECRET_ACCESS_KEY: ${RUSTFS_SECRET_KEY}
            AWS_DEFAULT_REGION: us-east-1
            STORAGE_BUCKET_NAME: ${STORAGE_BUCKET_NAME:-audio-storage}
        volumes:
            - ./scripts/storage-init.sh:/storage-init.sh:ro
        entrypoint: ["/bin/sh", "/storage-init.sh"]

    web-server-1:
        image: ${BACKEND_IMAGE:-music-backend:latest}
        container_name: web-server-1
        restart: unless-stopped
        environment: *backend-env
        depends_on:
            postgres-db: { condition: service_healthy }
            rustfs: { condition: service_healthy }
            storage-init: { condition: service_completed_successfully }

    web-server-2:
        image: ${BACKEND_IMAGE:-music-backend:latest}
        container_name: web-server-2
        restart: unless-stopped
        environment: *backend-env
        depends_on:
            postgres-db: { condition: service_healthy }
            rustfs: { condition: service_healthy }
            storage-init: { condition: service_completed_successfully }

    nginx:
        image: nginx:1.30-alpine
        container_name: nginx-proxy
        restart: unless-stopped
        ports:
            - "80:80"
        environment:
            NGINX_ENVSUBST_OUTPUT_DIR: /etc/nginx
            NGINX_ENVSUBST_FILTER: ^(BACKEND_|STORAGE_)
            BACKEND_UPSTREAM_1: ${BACKEND_UPSTREAM_1:-web-server-1:8080}
            BACKEND_UPSTREAM_2: ${BACKEND_UPSTREAM_2:-web-server-2:8080}
            STORAGE_UPSTREAM: ${STORAGE_UPSTREAM:-rustfs:9000}
            STORAGE_HOST_HEADER: ${STORAGE_HOST_HEADER:-rustfs:9000}
            STORAGE_BUCKET_NAME: ${STORAGE_BUCKET_NAME:-audio-storage}
        volumes:
            - ./nginx/templates:/etc/nginx/templates:ro
            - ${FRONTEND_DIST_DIR:-../frontend-dist}:/usr/share/nginx/html:ro
            - nginx-hls-cache:/var/cache/nginx/hls_cache
        depends_on:
            - web-server-1
            - web-server-2
            - rustfs
        healthcheck:
            test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1/healthz || exit 1"]
            interval: 10s
            timeout: 3s
            retries: 3

volumes:
    postgres-data:
    rustfs-data:
    nginx-hls-cache:
```

* `scripts/storage-init.sh`: 버킷 확인·생성 ➔ 익명 읽기 정책(`hls/*`, `artwork/*`만, `s3:ListBucket` 비허용) 적용. PRD-06 §3의 YAML 인라인 heredoc은 따옴표 이스케이프 오류가 나기 쉬워 **스크립트 파일로 분리**합니다(정책 내용은 변경 없음).
* **정책 지원 확인:** RustFS가 경로별 `Resource` 정책(`hls/*`, `artwork/*`)을 지원하는지는 백엔드 인덱스 §7.1의 미확인 항목입니다. `original/` 익명 `GET`이 `403`이어야 합니다(V-31).
* **포트 `80` 충돌:** Windows에서 IIS 등이 `80`을 점유하면 기동에 실패합니다. 호스트 포트를 바꾸면 Google 리디렉션 URI와 백엔드 화이트리스트(`http://localhost/…`)도 함께 바뀌므로 기본은 `80` 유지입니다.

### 5.3. `.env.example` (이 저장소가 소유)

PRD-05 §4.3 + PRD-06 Step 1 + PRD-07 §7의 변수를 한 파일로 통합합니다. **시크릿은 예시 값만** 넣고 `.env`는 `.gitignore` 대상입니다.

| 변수 | 구분 | 예시 값 / 비고 |
|---|---|---|
| `DB_NAME` / `DB_USERNAME` / `DB_PASSWORD` | 시크릿(비밀번호) | `streaming_db` / `streaming_user` / `local_secret_pw_123!` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | 시크릿 | Google Console 발급값. 승인된 리디렉션 URI는 `http://localhost/login/oauth2/code/google` |
| `JWT_SECRET_KEY` | 시크릿 | UTF-8 32바이트 이상 (미만이면 백엔드 기동 실패) |
| `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` | 시크릿 | 비밀키 8자 이상 |
| `STORAGE_ENDPOINT` / `STORAGE_HOST_HEADER` | 일반 | `http://rustfs:9000` / `rustfs:9000` (**host:port 반드시 동일**) |
| `STORAGE_UPSTREAM` / `STORAGE_BUCKET_NAME` | 일반 | `rustfs:9000` / `audio-storage` |
| `BACKEND_UPSTREAM_1` / `BACKEND_UPSTREAM_2` | 일반 | `web-server-1:8080` / `web-server-2:8080` |
| `BACKEND_IMAGE` | 일반 | `music-backend:latest` (백엔드 저장소가 빌드) |
| `FRONTEND_DIST_DIR` | 일반 | `../frontend-dist` |
| `OAUTH2_DEFAULT_REDIRECT_URI` / `OAUTH2_ALLOWED_REDIRECT_URIS` | 일반 | 기본 `http://localhost/auth/callback,musicapp://oauth2/callback`. **개발 서버 로그인용 `http://localhost:5173/auth/callback`은 개발 `.env`에서만 추가하고 운영에는 넣지 않습니다** (프론트엔드 §12.3, §15 #1) |
| `MEDIA_PUBLIC_BASE_URL` / `CORS_ALLOWED_ORIGINS` | 일반 | 단일 오리진은 빈 값 |
| 선택 | 일반 | `MAX_UPLOAD_SIZE`, `MAX_REQUEST_SIZE`, `JWT_EXPIRATION_MS`, `STORAGE_PRESIGNED_EXPIRY_SECONDS`, `FFMPEG_TIMEOUT_MINUTES` |

## 6. 이 저장소의 디렉터리 구조

```text
nginx/                               # 저장소 루트
├── docker-compose.yml
├── .env.example                     # .env는 .gitignore
├── .gitattributes                   # * text=auto eol=lf (conf·sh·sql의 CRLF 방지)
├── .gitignore
├── nginx/
│   └── templates/
│       ├── nginx.conf.template
│       └── snippets/
│           ├── proxy-backend.conf.template
│           ├── proxy-hls.conf.template
│           ├── security-headers.conf.template
│           └── csp-spa.conf.template
├── db/
│   └── init.sql                     # PRD-07 §6 DDL 그대로
├── scripts/
│   ├── storage-init.sh              # 버킷 + 익명 읽기 정책
│   ├── smoke.sh                     # §8 정적·스모크 단계 자동화
│   └── integration-checklist.md     # §8 통합 단계 수행 기록 틀
└── .claude/docs/                    # 이 문서와 참조 PRD
```

* 정적 파일 루트(`../frontend-dist`)는 프론트엔드 저장소의 `npm run build` 출력 위치이며 이 저장소 밖에 있습니다.
* **Windows 주의:** 셸 스크립트·`.conf`·`init.sql`이 CRLF로 체크아웃되면 컨테이너 안에서 오류가 납니다. `.gitattributes`(`* text=auto eol=lf`)를 첫 태스크에서 추가합니다. 이미 커밋된 파일의 줄바꿈 정규화(`git add --renormalize .`)는 사용자 확인 후에만 합니다.

## 7. 환경변수·플랫폼 분리 대비

웹·DB·스토리지가 별도 서버/플랫폼으로 분리되면 아래 값만 변경하며 설정 파일 수정은 필요하지 않아야 합니다.

| 분리 대상 | Nginx (이 저장소) | 백엔드 (요청 사항) | 추가 조치 |
|---|---|---|---|
| 스토리지 | `STORAGE_UPSTREAM`, `STORAGE_HOST_HEADER` | `STORAGE_ENDPOINT` (호스트 동일) | `9000`은 Nginx·백엔드 IP만 허용, 퍼블릭망이면 TLS 또는 사설망 (upstream `https://` 전환) |
| 백엔드 노드 | `BACKEND_UPSTREAM_1/2` (노드 추가 시 upstream 항목 추가) | - | 방화벽에서 `8080`은 Nginx IP만 허용 |
| DB | - | `DB_HOST`, `DB_PORT` | `5432`는 백엔드 IP만 허용 |
| 웹 (CDN 등 별도 오리진) | `/` 정적 서빙 제거 가능 | `CORS_ALLOWED_ORIGINS`, `MEDIA_PUBLIC_BASE_URL`, `OAUTH2_*` | Google Console 리디렉션 URI 갱신. `allowed-origins`가 비어 있지 않은 구성에서는 동일 오리진 요청의 `Origin` 판정이 `Host`/`X-Forwarded-*`에 영향받을 수 있어 재확인 (백엔드 T6-6 이관 항목, V-62) |

* 원본 보호는 presigned 서명 기반이므로 네트워크 경계가 바뀌어도 변경이 필요하지 않습니다.

## 8. 검증·테스트 전략

세 단계로 진행하며, 각 항목에는 **결과(통과/실패/미확인)와 근거**를 `scripts/integration-checklist.md`에 기록합니다. 직접 확인하지 못한 항목을 통과로 적지 않습니다.

### 8.1. 정적 검증

| ID | 항목 | 기대 결과 |
|---|---|---|
| V-01 | `docker exec nginx-proxy nginx -t` | `syntax is ok`, `test is successful` |
| V-02 | 치환 결과: `grep -nE "server |Host |proxy_pass" /etc/nginx/nginx.conf` | upstream·Host·버킷명이 기대값, 치환되지 않은 `${…}`는 로그 포맷 `map`의 캡처 변수뿐 |
| V-03 | `$uri`, `$1` 등 Nginx 변수가 치환으로 지워지지 않음 | `nginx.conf`에 `$uri`, `$1` 존재 |

### 8.2. 스모크 (curl, `scripts/smoke.sh`)

| ID | 항목 | 기대 결과 |
|---|---|---|
| V-10 | `curl -I http://localhost/` | `200`, `Cache-Control: no-cache` |
| V-11 | `curl -I http://localhost/auth/callback` (SPA 새로고침) | `200` (`index.html`) |
| V-12 | `curl -I http://localhost/assets/없는파일.js` | `404` (HTML로 대체 응답되지 않음) |
| V-13 | `curl -I http://localhost/healthz` | `200`, 접근 로그에 기록되지 않음 |
| V-14 | `curl -I http://localhost/api/tracks`, `…/api` (슬래시 없음) | 백엔드 응답(`200`/`404` JSON), SPA HTML 아님 |
| V-15 | `curl -I http://localhost/api/auth/me` (토큰 없음) | `401` JSON |
| V-20 | `curl -I http://localhost/internal-storage/original/test.wav` | `404` (직접 호출 차단) |
| V-21 | `curl -I http://localhost/stream/없는uuid/index.m3u8` | RustFS 응답(`404`), `Access-Control-Allow-Origin: *`, `X-Cache-Status` |
| V-22 | `curl -X OPTIONS http://localhost/stream/x/index.m3u8 -H "Origin: http://example.com"` | `204`, CORS 헤더 |
| V-23 | `curl -X POST http://localhost/stream/x` | `405`/`403` (쓰기 메서드 차단) |
| V-24 | 업로드 한도: 111MB 요청 / 110MB 이하 요청 | 초과는 `413`, 이하는 백엔드로 전달 |
| V-25 | `/api/tracks`를 10회 호출 후 `docker logs nginx-proxy` | `upstream:`이 web-server-1/2로 분산 |

### 8.3. 통합 (Milestone 1 선행 조건, 샘플 음원 업로드 후)

| ID | 항목 | 기대 결과 / 실패 시 조치 |
|---|---|---|
| V-30 | **원본 다운로드 헤더 유지 (1순위):** `curl -sS -D - -o /tmp/d.bin http://localhost/api/tracks/{id}/download` (한글 파일명 곡) | `200`, `Content-Disposition: attachment; filename="…"; filename*=UTF-8''…`, 원본 sha256 일치. 헤더 누락 시 `proxy_hide_header Content-Disposition` 제거 후 재검증 |
| V-31 | 원본 익명 접근: `docker exec nginx-proxy wget -S -O /dev/null http://rustfs:9000/audio-storage/original/…` | `403`. `hls/*`, `artwork/*` 익명 `GET`은 `200` |
| V-32 | presigned 서명 보존: V-30이 `403 SignatureDoesNotMatch`가 아님 | 403이면 `STORAGE_HOST_HEADER`≠`STORAGE_ENDPOINT` host:port 또는 쿼리 재인코딩 의심 |
| V-33 | 시크·`Range`: `curl -H "Range: bytes=0-99" http://localhost/stream/{id}/chunk_000.ts` 2회 | `206`, 두 번째는 `X-Cache-Status: HIT`. 브라우저 시크 시 총 길이·구간 이동 정상 |
| V-34 | `.m3u8` 캐시: 연속 2회 요청 | 5초 이내 `HIT`, 5초 후 `EXPIRED`/`MISS` |
| V-40 | Google 로그인 5회 이상 반복 (멀티노드) | `authorization_request_not_found` 없이 `/auth/callback?token=…` 복귀 (PRD-04 §6-7) |
| V-41 | `redirect_uri` 계산: 개발 서버(`:5173`, `changeOrigin`) 경유 로그인 | `http://localhost/login/oauth2/code/google`로 계산, `invalid_redirect_uri` 없음 (`.env`에 dev 콜백 추가 필요) |
| V-50 | 보안 헤더: SPA·`/stream`·`/artwork` 응답 | `X-Content-Type-Options: nosniff`, SPA에 `Referrer-Policy: no-referrer`·CSP, `/api` 응답에 중복 헤더 없음 |
| V-51 | CSP 영향: 로그인, 업로드, hls.js 재생, 프로필 이미지 표시 | 콘솔에 CSP 위반 없음. 위반 시 해당 지시어만 완화하고 §11 #8에 기록 |
| V-52 | 로그 마스킹: `curl "http://localhost/auth/callback?token=SECRET123"` 후 `grep -c SECRET123 /var/log/nginx/access.log` | `0`. `Referer`에도 없음 |
| V-60 | 속도 제한: 정상 업로드·로그인 흐름이 `429`에 걸리지 않음 | 걸리면 초기값 완화. 초과 시나리오(31회/분)는 `429` |
| V-61 | 다운로드 흐름 전체: 백엔드 `DOWNLOAD` 이력 기록 + 브라우저 `<a download>` 저장 파일명·바이트 일치 | 프론트엔드 Phase 6(T6-2)의 선행 조건 |
| V-62 | 분리 배포 `CORS_ALLOWED_ORIGINS` 비어 있지 않은 구성에서 동일 오리진 요청 | `403` 없이 통과 (해당 구성을 쓰게 될 때만) |
| V-70 | 프론트엔드 `npm run build` 결과를 마운트한 상태에서 Milestone 1 E2E(업로드 ➔ `READY` ➔ 재생 ➔ 반복재생 ➔ 다운로드) | 프론트엔드 ROADMAP T6-1~T6-3 수행 가능 |

## 9. 비기능 요구사항

* **성능:** 청크·원본·앨범아트 바이트는 백엔드를 거치지 않습니다. `.ts`/아트워크는 Nginx 캐시로 반복 요청을 흡수합니다(`proxy_cache_lock`로 동시 MISS 요청 병합). 정적 자산은 `immutable` 장기 캐시.
* **보안 (원본 보호 3중):** ① RustFS `original/` 익명 읽기 금지, ② presigned 60초 서명, ③ Nginx `internal;`. 외부 공개 포트는 `80` 하나이며 RustFS/PostgreSQL은 루프백만. JWT는 접근 로그·`Referer`에 남기지 않습니다.
* **안정성:** upstream `max_fails`/`fail_timeout`, 컨테이너 `restart: unless-stopped`, 헬스체크, 기동 순서 의존. 실패 시 원인 분류가 가능하도록 접근 로그에 `upstream:`, `cache:`, `rt=`를 남깁니다.
* **운영성:** 설정 변경은 템플릿 수정 ➔ `restart nginx` ➔ `nginx -t` 절차. 캐시 볼륨은 `nginx-hls-cache`에 영속화합니다.

## 10. 외부 요청 사항 (이 저장소에서 구현하지 않음)

| # | 요청 | 담당 | 비고 |
|---|---|---|---|
| 1 | 백엔드 `STORAGE_ENDPOINT` host:port와 Nginx `STORAGE_HOST_HEADER` 동일 유지 | 백엔드 환경변수 | 불일치 시 원본 다운로드 `403` |
| 2 | 개발용 `OAUTH2_ALLOWED_REDIRECT_URIS`에 `http://localhost:5173/auth/callback` 추가 (운영 제외) | 백엔드 환경변수 | 프론트엔드 §15 #1. 이 저장소는 `.env.example`에 주석으로만 안내 |
| 3 | 백엔드 이미지에 헬스 엔드포인트(actuator 등) 도입 검토 | 백엔드 | 도입 시 compose `healthcheck`·`depends_on` 강화. 현재는 필수 아님 |
| 4 | 프론트엔드 빌드 산출물의 자산 폴더명(`/assets`)과 출력 경로 `../frontend-dist` 유지 | 프론트엔드 | §3.6의 location 전제 |
| 5 | 프론트엔드 CSP 호환 확인 (외부 스크립트·인라인 스타일 사용 여부) | 프론트엔드 | §3.7 CSP의 `script-src 'self'; style-src 'self'` 전제 |

## 11. 결정 이력

### 11.1. 사용자 확정 (2026-11-12)

| # | 결정 |
|---|---|
| U1 | 이 저장소의 범위는 **Nginx + 통합 docker 스택**(compose, `.env`, `db/init.sql`, `storage-init`, 검증 스크립트 포함) |
| U2 | 메인 기준 문서 파일명은 `.claude/docs/PRD.md` |
| U3 | `PRD-backend.md`, `ROADMAP-backend.md`, `PRD-frontend.md`, `ROADMAP-frontend.md`는 다른 저장소의 구현 기록이라 이 저장소에서 삭제(`git rm`). 필요한 내용(통합 확인 항목, 외부 요청, CSP·로그 마스킹 요구)은 §3·§8·§10에 흡수 |

### 11.2. PRD-04 대비 보완·변경 (문서 교차 검토)

| # | PRD-04 / 기존 상태 | 변경 | 사유 |
|---|---|---|---|
| 1 | 접근 로그가 `$request`·`$http_referer`를 그대로 기록 | `map`으로 `token` 쿼리 마스킹, SPA에 `Referrer-Policy: no-referrer` | JWT가 `/auth/callback?token=`으로 전달됨 (프론트엔드 §15 #2, 백엔드 T6-5). 수용 기준 V-52 |
| 2 | `/stream/`의 모든 `200`을 24h 캐시 (주석은 "m3u8 최신 유지"라 하나 설정은 전체 캐시) | `.m3u8` 5초, `.ts` 24h로 location 분리 (rewrite 방식) | 매니페스트의 오래된 사본 방지, 의도와 설정 일치 |
| 3 | - (신규 관찰) | 생성된 `index.m3u8`에 `#EXT-X-PLAYLIST-TYPE:VOD`가 없고 `#EXT-X-ENDLIST`만 있음. Nginx 변경 없이 시크·총 길이만 V-33에서 확인 | 백엔드 T7-3 보고, PRD-06 소관 |
| 4 | `^/(api\|oauth2\|login/oauth2)/` (끝 슬래시 필수) | `(/\|$)`로 변경 | `/api` 단독이 SPA로 떨어지는 문제 |
| 5 | `proxy_hide_header Content-Disposition` 유지 여부 미확정 | 유지하되 V-30을 1순위로 검증, 실패 시 제거하고 이 표에 결과 기록 | 백엔드 통합 확인 항목, PRD-04 §6-5 (결과 **확인 완료 2026-11-12, T5-1**: V-30 통과. 200, 한글 `filename*=UTF-8''…` 유지, 본문 sha256 일치, `X-Accel-Redirect` 미노출. 백엔드가 지정한 `Content-Disposition`은 `X-Accel-Redirect` 내부 리다이렉트에서도 유지되고 `proxy_hide_header`는 RustFS 응답 헤더만 숨기므로 **`proxy_hide_header Content-Disposition` 유지로 확정**, 설정 변경 없음. V-32도 통과(서명 보존)) |
| 6 | 헬스체크 `wget /` | 전용 `/healthz`, `127.0.0.1` 사용 | SPA 존재 의존 제거, alpine IPv6 해석 문제 회피 |
| 7 | 없음 | 업로드·로그인 진입에 `limit_req`, `/stream`·`/artwork`에 허용 메서드 제한 | 남용·FFmpeg 큐 포화 방지, 쓰기 메서드 차단 |
| 8 | CSP·보안 헤더 미정 (프론트엔드 §15 #4) | Nginx 직접 응답(SPA/stream/artwork)에만 적용, CSP는 Report-Only ➔ 강제 순서 (§3.7) | `/api`는 Spring이 이미 헤더를 붙임. CSP 최종 값은 V-51 후 확정 (**미확인**) — **강제 전환 완료(2026-11-12, T5-4)**: V-51 통과(완화한 지시어 없음, §3.7 초안 그대로). `Content-Security-Policy`(강제) 적용 후 SPA 로딩·hls.js 재생 정상, 주입한 인라인 스크립트는 차단됨 |
| 9 | `X-Forwarded-Host $host` | `$http_host` (포트 포함) | 비표준 포트에서 `redirect_uri` 계산 오류 방지. 포트 `80`에서는 동일 동작이라 V-40/V-41로 확인 |
| 10 | 업로드도 기본 요청 버퍼링 | 업로드만 `proxy_request_buffering off` | 110MB의 임시 디스크 쓰기 제거. 이 설정에서 `413`/연결 종료 동작은 V-24에서 확인 (**미확인**) |
| 11 | compose 내 `storage-init`의 인라인 heredoc | `scripts/storage-init.sh`로 분리 | YAML 따옴표 이스케이프 오류 방지 (정책 내용 불변) |
| 12 | `nginx.conf.template`만 템플릿 | 스니펫도 `templates/snippets/*.template`로 두고 `NGINX_ENVSUBST_FILTER` 지정 | location별 `add_header` 상속 단절을 `include`로 해결, 의도하지 않은 치환 방지 |
| 13 | `/assets/`에서 `expires 1y` 제거, `/assets/`·`/artwork/`의 `add_header Cache-Control`에서 `always` 제거. `/artwork/`에 `proxy_cache_key "$uri"`, `proxy_cache_lock on`, `X-Cache-Status` 추가 | `expires`와 `add_header`가 `Cache-Control`을 두 줄로 내보내고, `always` 때문에 404에도 `immutable`이 붙어 오류 응답이 장기 캐시될 위험이 있었다(T1-3에서 발견) | 2xx/3xx에만 `Cache-Control` 한 줄 (`artwork`는 T2-2에서 적용). 캐시 키·락은 `/stream`과 동일 규칙(키 접두가 달라 충돌 없음) |
| 14 | `/stream` 캐시 동작 확인 결과 (설정 변경 없음) | `proxy_ignore_headers` 불필요. `Range` MISS 시 전체 객체를 받아 캐시하고(이후 `Range` 호출은 `206`+`HIT`), `.m3u8`은 5초 후 `EXPIRED` | T5-2 검증: RustFS가 `Cache-Control`/`Expires`/`X-Accel-Expires`를 붙이지 않아 `proxy_cache_valid`가 적용됨. 캐시된 `206` 응답에는 `Accept-Ranges`가 없으나 `Content-Range`가 있어 `hls.js` 시크에는 영향이 없을 것으로 판단(브라우저 시크는 미확인) |
| 15 | 업로드 한도 `110M`·`proxy_request_buffering off`의 `413` 동작 (V-24) | 설정 유지. `Content-Length` 111MB는 Nginx `413` JSON, 110MB 이하는 백엔드로 전달. 백엔드가 본문을 다 읽기 전에 응답(예: `415`)하면 chunked 초과 본문에서 Nginx `413`은 나오지 않음 | T4-3 검증: 호스트 `curl`로 큰 본문을 보내면 백엔드가 먼저 응답한 경우 응답을 못 받고 멈추는 현상이 재현됨(같은 compose 네트워크 안에서는 즉시 응답, Docker Desktop 포트 프록시 경로 추정, 미확정). 브라우저 실사용 업로드(110MB 이하)는 `202`로 정상(T5-5). 업로드 한도를 110MB 이하로 제한하는 운영 계획이라 영향 없음. 정상 multipart 110MB 초과 업로드는 미확인 |
| 16 | 로그에 남는 값의 한계 (수용) | 접근 로그의 `$request`·`$http_referer`는 `token` 마스킹. 그러나 `error_log`와 `/login/oauth2/code/google` 콜백 URL의 Google 일회용 인가 코드(`code=`)는 마스킹하지 않음 | JWT가 아니고 단회용·PKCE 결합이라 수용. 413 JSON `timestamp`는 컨테이너 시간대(UTC, `+00:00`)이며 API.md 형식(`+09:00`)과 다르나 프론트엔드가 사용하지 않는 것으로 추정(저우선) |

### 11.3. 미결 (구현·통합 테스트 후 갱신)

* **해결됨(2026-11-12, T5):** V-30(`Content-Disposition` 유지로 확정, §11.2 #5), V-32(서명 보존), V-33·V-34(`Range`/캐시, §11.2 #14), V-51(CSP 강제 전환, §11.2 #8), V-24(§11.2 #15), RustFS 경로별 정책(아래), nginx 이미지 태그(아래).
* **미확인(사유):** V-41(개발 서버 `:5173` 경유 로그인 — 운영 기본값에 개발 콜백을 넣지 않았음), `/artwork/*` 실제 `Content-Type`(앨범아트가 있는 곡이 없음), 정상 multipart 110MB 초과 업로드의 브라우저 동작(업로드를 110MB 이하로 제한할 계획).
* RustFS 경로별 버킷 정책 지원 여부(V-31): **확인 완료(2026-11-12, T4-1)**. `hls/*`·`artwork/*`만 익명 GET 허용, `original/`·버킷 목록은 403. rustfs 이미지에 `curl`·`wget`이 있어 PRD 헬스체크를 그대로 사용. `storage-init` 재실행 멱등성(버킷 존재 시 건너뜀, exit 0) 확인.
* nginx 이미지 태그: **확인 완료(2026-11-12, T1-1)**. `1.26-alpine`은 EOL이고 Docker Hub에서 2025-04-16 이후 갱신이 없어 `1.30-alpine`(stable 1.30.x)으로 변경했다. 단독 컨테이너에서 `nginx -t`와 envsubst 치환 통과. `error_log`에는 `token` 마스킹이 적용되지 않아 쿼리가 평문으로 남을 수 있으므로(PRD 수용 한계) V-52는 `access.log` 기준으로 판정한다.
* JWT 로그 마스킹 한계(T3-1 검증, 수용): `map`은 소문자 `token=` 파라미터만 마스킹한다. 대문자(`TOKEN=`), 퍼센트 인코딩(`%74oken=`, `token%3d`), 중복 `token` 파라미터의 앞쪽 값은 마스킹되지 않는다. 정상 콜백(`/auth/callback?token={jwt}`, 백엔드가 소문자 `token`을 1회 사용)에서는 발생하지 않으며, 이런 요청은 공격자가 자기 값을 직접 넣을 때만 생긴다. 필요해지면 `~*` 전환 등으로 강화한다.

## 12. MVP 이후 과제

* 로그인 토큰을 URL 쿼리 대신 일회용 코드 교환 방식으로 전환(백엔드 협의). 전환 시 §3.8의 마스킹은 방어 계층으로만 남김.
* `auth_request /api/auth/check` 기반 스트리밍 권한 통제(PRD-01 §5.3 2단계).
* TLS 종단(HTTPS), HSTS, 도메인 적용, 외부 로드밸런서 뒤 `real_ip` 설정.
* 백엔드 헬스 엔드포인트 기반 능동 헬스체크.
* 다운로드 이력의 사용자 귀속(단기 다운로드 토큰), 다중 음질(ABR) 선택.

## 13. 개발 단계 요약

상세 태스크(ID·선행·완료 조건)는 후속 `.claude/docs/ROADMAP.md`로 분리합니다.

| 단계 | 내용 | 선행 |
|---|---|---|
| N0 | 골격: `.gitattributes`, `.gitignore`, `.env.example`, `db/init.sql` 복사, 디렉터리, `scripts/storage-init.sh` | - |
| N1 | Nginx 템플릿 기본: 경로 라우팅 5종, 업스트림, 프록시 스니펫, `/healthz`, `nginx -t` 통과 | N0 |
| N2 | 스트리밍·다운로드: HLS 캐시 분리, CORS, `X-Accel-Redirect`, 아트워크 | N1 |
| N3 | 보안·운영: 로그 마스킹, 보안 헤더·CSP(Report-Only), 속도 제한, 413 JSON | N1 |
| N4 | 통합 스택 기동: `docker-compose.yml` 전체, 기동 순서, 스모크(V-01~V-25) | N2, N3 |
| N5 | 통합 검증: V-30~V-70 수행·기록, 결정 이력 갱신, CSP 강제 전환, 프론트엔드 Phase 6 연계 | N4, 백엔드·프론트엔드 산출물 |
