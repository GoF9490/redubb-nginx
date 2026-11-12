# PROGRESS (오케스트레이션 작업 기록)

> 기준: `ROADMAP.md`(23개 태스크). 커밋은 사용자 요청 시 수행(push 없음). 시크릿(.env, env.txt)은 문서에 옮기지 않는다.

## 현재 상태

- **ROADMAP 23/23 완료 (2026-11-12).** 커밋 대기(사용자 확인 후 `/git:commit`).

## 검증 결과 요약

- `bash scripts/smoke.sh`: PASS=14 FAIL=0 (V-10~V-25). 전체 스택 6개 서비스 기동, nginx healthy, 공개 포트 80만.
- 통과: V-01~03, V-10~15, V-20~25, V-30~34, V-40, V-50~52, V-60~61, V-70. 해당 없음: V-62.
- 미확인(사유): V-41(개발 서버 :5173 경유 로그인, 개발 콜백 미추가), `/artwork/*` 실제 Content-Type(앨범아트 있는 곡 없음), 정상 multipart 110MB 초과 업로드(업로드를 110MB 이하로 제한할 계획).

## 주요 결정·변경 (상세는 PRD §11.2·§11.3)

- nginx 이미지 `1.26-alpine`(EOL) → `1.30-alpine`.
- `/assets/`·`/artwork/`의 `Cache-Control` `always` 제거, `/assets/`의 `expires 1y` 제거(오류 응답 장기 캐시 방지, #13). `/artwork/`에 cache_key/lock/X-Cache-Status 추가.
- `proxy_hide_header Content-Disposition` 유지 확정(#5). `proxy_ignore_headers` 불필요(#14).
- CSP Report-Only → 강제 전환 완료, 완화 지시어 없음(#8).
- x-backend-env에 PRD-05 §4.3 선택키 6개 추가. `.env.example`에 `STORAGE_REGION` 추가.
- 수용한 한계(#15·#16): JWT 마스킹은 소문자 token만, error_log·콜백 URL의 Google 일회용 code 미마스킹, 413 JSON timestamp UTC, 호스트 curl 대용량 POST 무응답(Docker Desktop 추정).

## 스택에 남은 테스트 데이터 (정리는 사용자/백엔드 몫, 삭제 API 미확인)

- 합성음 트랙 58cbf33a-82b7-49d6-bcb3-35fa5f4ea723, 파일명 깨진 트랙 03b015fc-465e-4fd5-9d9e-c6699eb9574a, 사용자 업로드 트랙 b79cacce-562f-4e06-b7ab-ea821f4929ec(실제 곡).
- 볼륨: re-dubb_postgres-data, re-dubb_rustfs-data, re-dubb_nginx-hls-cache. 기존 다른 프로젝트 볼륨(music-rustfs-data, pgdata)은 미사용·미변경. 사용자가 기존 단독 rustfs 컨테이너를 삭제함.

## 후속 과제

- 개발 콜백(:5173) 추가 후 V-41 확인, 앨범아트 있는 곡 업로드 후 /artwork Content-Type 확인.
- 프론트엔드 Phase 6, 백엔드 T7-3 이관 항목의 선행 조건(Nginx 통합 스택 + E2E)은 충족됨.
