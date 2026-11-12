# 통합 검증 체크리스트

PRD §8의 V-ID별 결과를 기록한다. 결과는 `통과` / `실패` / `미확인` 중 하나이며, 직접 확인하지 못한 항목은 통과로 적지 않는다.
근거에는 실행 명령과 출력 요약을 적고, `token=` 값과 시크릿은 가려서 기록한다.

## 8.1. 정적 검증

| ID | 항목 | 기대 결과 | 결과 | 근거 | 수행일 |
|---|---|---|---|---|---|
| V-01 | `docker exec nginx-proxy nginx -t` | `syntax is ok`, `test is successful` | 통과 | 실스택 `docker exec nginx-proxy nginx -t`: `syntax is ok`, `test is successful` (T4-2, CSP 강제 전환 후 재확인) | 2026-11-12 |
| V-02 | 치환 결과 `grep -nE "server \|Host \|proxy_pass" /etc/nginx/nginx.conf` | upstream·Host·버킷명이 기대값, 미치환 `${…}`는 로그 포맷 `map` 캡처 변수뿐 | 통과 | 치환 결과: `server web-server-1:8080 max_fails=3 fail_timeout=10s;`, `server web-server-2:8080 ...;`, `server rustfs:9000;`, `proxy_set_header Host rustfs:9000;`(artwork·internal-storage·proxy-hls 스니펫), 버킷명 `audio-storage` | 2026-11-12 |
| V-03 | `$uri`, `$1` 등 Nginx 변수가 치환으로 지워지지 않음 | `nginx.conf`에 `$uri`, `$1` 존재 | 통과 | `$uri`·`$1`·`$http_host`·`$request_uri`가 치환 결과에 남아 있음(템플릿과 출현 수 11건 동일). `proxy_cache_key "$uri"`, `try_files $uri $uri/ /index.html`, `rewrite ^/stream/(.*)$ /audio-storage/hls/$1 break;` 확인 | 2026-11-12 |

## 8.2. 스모크 (`scripts/smoke.sh`)

| ID | 항목 | 기대 결과 | 결과 | 근거 | 수행일 |
|---|---|---|---|---|---|
| V-10 | `curl -I http://localhost/` | `200`, `Cache-Control: no-cache` | 통과 | T4-3 smoke.sh: 200, `Cache-Control: no-cache` | 2026-11-12 |
| V-11 | `curl -I http://localhost/auth/callback` (SPA 새로고침) | `200` (`index.html`) | 통과 | T4-3 smoke.sh: HTTP 200 | 2026-11-12 |
| V-12 | `curl -I http://localhost/assets/없는파일.js` | `404` (HTML 대체 응답 아님) | 통과 | T4-3 smoke.sh: HTTP 404 | 2026-11-12 |
| V-13 | `curl -I http://localhost/healthz` | `200`, 접근 로그에 기록되지 않음 | 통과 | T4-3 smoke.sh: 200, 고유 쿼리(`?m=smoke13-…`)로 `docker logs nginx-proxy` 검색 0건 | 2026-11-12 |
| V-14 | `curl -I http://localhost/api/tracks`, `…/api` | 백엔드 응답(`200`/`404` JSON), SPA HTML 아님 | 통과 | T4-3 smoke.sh: `/api/tracks`=200 `application/json`(빈 목록 페이지), `/api`=404 `application/json`(`INVALID_REQUEST`), 본문에 `<html` 없음 | 2026-11-12 |
| V-15 | `curl -I http://localhost/api/auth/me` (토큰 없음) | `401` JSON | 통과 | T4-3 smoke.sh: 401 `application/json;charset=UTF-8`, `{"code":"UNAUTHORIZED",…}`. 참고: API.md 상 `/api/tracks`·업로드는 인증 "선택"이라 무인증 200/처리 가능(문서와 일치) | 2026-11-12 |
| V-20 | `curl -I http://localhost/internal-storage/original/test.wav` | `404` (직접 호출 차단) | 통과 | T4-3 smoke.sh: HTTP 404 | 2026-11-12 |
| V-21 | `curl -I http://localhost/stream/없는uuid/index.m3u8` | RustFS `404`, `Access-Control-Allow-Origin: *`, `X-Cache-Status` | 통과 | T4-3 smoke.sh: 404, `Access-Control-Allow-Origin: *`, `X-Cache-Status: MISS` | 2026-11-12 |
| V-22 | `curl -X OPTIONS …/stream/x/index.m3u8 -H "Origin: http://example.com"` | `204`, CORS 헤더 | 통과 | T4-3 smoke.sh: 204, `Access-Control-Allow-Origin: *` | 2026-11-12 |
| V-23 | `curl -X POST http://localhost/stream/x` | `405`/`403` (쓰기 메서드 차단) | 통과 | T4-3 smoke.sh: HTTP 403 | 2026-11-12 |
| V-24 | 업로드 한도: 111MB 요청 / 110MB 이하 요청 | 초과는 `413`, 이하는 백엔드로 전달 | 통과 | T4-3 (`application/octet-stream` 본문, 트랙 생성 없음). 111MB(Content-Length): 413 JSON `PAYLOAD_TOO_LARGE`. 109MB: Nginx 로그 `POST /api/tracks/upload 415 upstream: 172.20.0.x:8080 rt=0.01`로 백엔드 전달 확인(415는 multipart 아님에 대한 백엔드 응답). 호스트 curl은 109MB에서 응답을 받지 못하고 `--max-time` 만료(curl 28, `HTTP 100`): 이전 단독 검증의 ≥800KB 멈춤 현상이 재현됨. 같은 compose 네트워크 안의 임시 컨테이너(curl, 일회용)에서는 109MB 415·111MB 413 모두 즉시(0.01초) 응답 → Nginx·백엔드 문제가 아니라 호스트(Docker Desktop 포트 프록시) 경로 한정으로 판단(원인은 추정, 미확정). chunked 111MB: 컨테이너 내부·호스트 모두 Nginx 413이 아니라 백엔드 415(조기 응답)이며 호스트 curl은 마찬가지로 멈춤. 즉 `proxy_request_buffering off`에서는 백엔드가 본문을 읽기 전에 응답하면 chunked 초과 본문에 대한 Nginx 413은 확인되지 않음(백엔드가 본문을 읽는 정상 multipart 흐름에서의 413/연결 종료 동작은 미확인, 실제 multipart 110MB 초과 업로드는 T5에서 확인 필요). 속도 제한: 업로드 호출은 실행당 3회로 제한(burst 10) | 2026-11-12 |
| V-25 | `/api/tracks` 10회 호출 후 `docker logs nginx-proxy` | `upstream:`이 web-server-1/2로 분산 | 통과 | T4-3 smoke.sh: 로그 10건 중 web-server-1(172.20.0.5)=5, web-server-2(172.20.0.4)=5 (`docker inspect` IP 매핑) | 2026-11-12 |

## 8.3. 통합 (Milestone 1 선행 조건)

| ID | 항목 | 기대 결과 / 실패 시 조치 | 결과 | 근거 | 수행일 |
|---|---|---|---|---|---|
| V-30 | 원본 다운로드 헤더 유지 (1순위, 한글 파일명 곡) | `200`, `Content-Disposition: attachment; filename="…"; filename*=UTF-8''…`, sha256 일치. 누락 시 `proxy_hide_header Content-Disposition` 제거 후 재검증 | 통과 | 합성 WAV(6초, 한글 파일명) 업로드 → READY → `GET /api/tracks/{id}/download` 200, `Content-Disposition: attachment; filename="track-{id}.wav"; filename*=UTF-8''%ED%85%8C%EC%8A%A4%ED%8A%B8%EA%B3%A1_%EA%B2%80%EC%A6%9D.wav` 유지, sha256 원본과 일치(b1c439ba…ba846), `proxy_hide_header` 유지로 확정(변경 없음) | 2026-11-12 |
| V-31 | 원본 익명 접근 `wget -S` (`original/` / `hls/*`, `artwork/*`) | `original/` `403`, `hls/*`·`artwork/*` 익명 `GET` `200` | 통과 | T4-1: 객체를 original/·hls/·artwork/에 업로드 후 익명 GET original/ 403, hls/ 200, artwork/ 200. 버킷 루트 익명 목록 403. 테스트 객체 삭제(남은 객체 0). 오케스트레이터 재확인: 없는 키 original/ 403, hls/·artwork/ 404(정책 통과) | 2026-11-12 |
| V-32 | presigned 서명 보존 (V-30이 `403 SignatureDoesNotMatch`가 아님) | 403이면 `STORAGE_HOST_HEADER`≠`STORAGE_ENDPOINT` host:port 또는 쿼리 재인코딩 의심 | 통과 | V-30 응답이 200이며 SignatureDoesNotMatch/403 아님, 본문 529244바이트 수신 | 2026-11-12 |
| V-33 | 시크·`Range` (`bytes=0-99`, 2회) | `206`, 두 번째는 `X-Cache-Status: HIT`, 브라우저 시크 정상 | 통과 (Range·캐시: T5-2, 브라우저 시크: T5-4에서 Playwright로 확인) | 트랙 58cbf33a-…(READY, 세그먼트 chunk_000.ts 66364B, chunk_001.ts 752B). 캐시에는 index.m3u8만 있던 상태에서 chunk_000·chunk_001 각각 Range 2회: 1회차 `206` `Content-Range: bytes 0-99/66364`(/752) `X-Cache-Status: MISS`(upstream 172.20.0.3:9000), 2회차 `206` `HIT`(upstream `-`). MISS 이후 Range 없는 전체 GET이 `200` 66364B `HIT`이므로 Range MISS 시 업스트림에서 전체 객체를 받아 캐시한다. 206 응답에는 `Accept-Ranges`가 없다(Nginx가 캐시에서 Range를 처리하며 `Content-Range`로 충분, RustFS 직접 응답은 `accept-ranges: bytes`). RustFS 응답에 `Cache-Control`/`Expires`/`X-Accel-Expires`가 없어(직접 HEAD 확인) `proxy_cache_valid`가 그대로 적용되므로 `proxy_ignore_headers` 불필요. index.m3u8은 `#EXT-X-ENDLIST`만 있고 `PLAYLIST-TYPE:VOD` 없음(§11.2 #3). 브라우저 시크(총 길이·구간 이동)는 인증 필요·브라우저 도구 부재로 미확인 브라우저(Playwright): hls.js(blob: MSE) 재생 완료, duration 6.04초, seekable [0, 6.04], currentTime=2 시크 정상, 오디오 오류 없음 | 2026-11-12 |
| V-34 | `.m3u8` 캐시: 연속 2회 요청 | 5초 이내 `HIT`, 5초 후 `EXPIRED`/`MISS` | 통과 | sleep으로 간격 조정: #1 `EXPIRED`(이미 캐시 항목이 있던 만료 상태, MISS 대신), #2(+1s) `HIT`, #3(+3s) `HIT`, #4(+9s) `EXPIRED`(upstream 재요청), #5(직후) `HIT`. `docker logs`의 `cache:` 값도 동일 | 2026-11-12 |
| V-40 | Google 로그인 5회 이상 반복 (멀티노드) | `authorization_request_not_found` 없이 `/auth/callback?token=…` 복귀 | 통과 | 사용자가 Google 로그인 5회 이상 수행(Chrome). nginx 로그: `/login/oauth2/code/google` 콜백 5회 모두 302, `/auth/callback?token=***` 복귀 5회, 비302 응답 0건, 백엔드 로그에 `authorization_request_not_found`·OAuth2AuthenticationException 0건. 진입·콜백이 web-server-1/2 양쪽으로 분산됐는데도 성공(멀티노드 세션 문제 없음). 접근 로그에 JWT(`eyJ`) 0건 | 2026-11-12 |
| V-41 | `redirect_uri` 계산: 개발 서버(`:5173`, `changeOrigin`) 경유 로그인 | `http://localhost/login/oauth2/code/google`로 계산, `invalid_redirect_uri` 없음 | 미확인 | 개발 서버(:5173) 경유 로그인은 `.env`에 개발 콜백(`http://localhost:5173/auth/callback`)을 추가한 구성에서만 확인 가능한데 현재 운영 기본값(콜백 미추가)이라 수행하지 않음. `X-Forwarded-Host $http_host` 설정 자체는 T1-2에서 확인 | 2026-11-12 |
| V-50 | 보안 헤더: SPA·`/stream`·`/artwork` 응답 | `X-Content-Type-Options: nosniff`, SPA에 `Referrer-Policy: no-referrer`·CSP, `/api` 중복 헤더 없음 | 통과 | 실스택 curl: `/` nosniff+Referrer-Policy: no-referrer+CSP-Report-Only, `/assets` 404·`/stream`(m3u8·ts)·`/artwork` 404 모두 nosniff. `/api/tracks`·`/api/auth/me`의 nosniff는 Spring 것 1개뿐(중복 없음) | 2026-11-12 |
| V-51 | CSP 영향: 로그인, 업로드, hls.js 재생, 프로필 이미지 | 콘솔에 CSP 위반 없음. 위반 시 해당 지시어만 완화 후 §11 #8 기록 | 통과 | Report-Only 상태에서: SPA 로딩·hls.js 재생·시크(Playwright 콘솔 0건), 로그인·프로필 이미지·업로드·재생(사용자 Chrome DevTools 콘솔 CSP 위반 없음 확인). 이후 강제 전환 완료 | 2026-11-12 |
| V-52 | 로그 마스킹: `/auth/callback?token=SECRET123` 호출 후 `grep -c SECRET123 access.log` | `0`, `Referer`에도 없음 | 통과 | 실스택: `/auth/callback` 3가지 쿼리 변형+`Referer` 헤더 요청 후 `docker logs nginx-proxy` 전체에서 SECRET123 0건. 실제 로그인 5회 복귀 로그에도 JWT(eyJ) 0건. 한계: error_log 미적용(PRD §11.3) | 2026-11-12 (CSP 강제 전환 후 재실행: SECRET123 0건) |
| V-60 | 속도 제한: 정상 업로드·로그인 흐름이 `429`에 걸리지 않음 | 걸리면 초기값 완화. 초과 시나리오(31회/분)는 `429` | 통과 | 정상 로그인 5회+스모크 실행 중 429 0건. 1분 대기 후 `/oauth2/authorization/google` 41회 연속 호출: 11번째까지 302, 12번째부터 429(burst 10+기본 1) | 2026-11-12 |
| V-61 | 다운로드 흐름 전체: `DOWNLOAD` 이력 + `<a download>` 파일명·바이트 일치 | 프론트엔드 Phase 6(T6-2)의 선행 조건 | 통과 | 사용자 Chrome 다운로드 성공(저장 파일명·바이트 일치 확인). 서버측: nginx `GET /api/tracks/b79cacce-…/download` 200 3956434B, DB `playback_logs`에 해당 트랙 `DOWNLOAD` 이력 기록(2026-11-12 21:54:16 KST) | 2026-11-12 |
| V-62 | 분리 배포 `CORS_ALLOWED_ORIGINS` 비어 있지 않은 구성에서 동일 오리진 요청 | `403` 없이 통과 (해당 구성을 쓸 때만) | 해당 없음 | `CORS_ALLOWED_ORIGINS`가 비어 있는 단일 오리진 구성(분리 배포 미사용). 동일 오리진 요청은 정상 동작(V-70) | 2026-11-12 |
| V-70 | 프론트엔드 빌드 마운트 후 Milestone 1 E2E (업로드 ➔ `READY` ➔ 재생 ➔ 반복재생 ➔ 다운로드) | 프론트엔드 T6-1~T6-3 수행 가능 | 통과 | 사용자 Chrome: 실제 음원 업로드(nginx 202) → READY → 재생·반복재생 → 원본 다운로드(200, 3956434B) 모두 성공. CSP 강제 전환 상태에서 수행 | 2026-11-12 |

## 8.4 추가 확인 항목 (V-ID 외, RustFS 필요)

| 항목 | 기대 결과 | 결과 | 근거 | 수행일 |
|---|---|---|---|---|
| `/artwork/*` 실제 Content-Type | `image/jpeg` / `image/png`가 그대로 전달된다 (T2-2에서 이관) | 미확인 | T5-2: 테스트 트랙에 커버가 없어 확인 불가(커버 있는 트랙 필요) | - |
| `/stream` 캐시 HIT·Range·`.m3u8` 5초 만료 | V-33·V-34와 동일 (T2-1에서 이관) | 통과 | V-33(Range 206, MISS→HIT)·V-34(.m3u8 HIT, 5초 후 EXPIRED) 근거 참조 | 2026-11-12 |
