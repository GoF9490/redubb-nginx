---
name: nginx-standalone-verify
description: 백엔드·RustFS 없이 Nginx 템플릿(envsubst)을 단독 컨테이너로 치환·검증하는 절차. ROADMAP Phase 1~3(T1-x~T3-x)에서 nginx -t, 치환 결과 확인, curl 검증, 로그 마스킹 확인이 필요할 때 사용한다.
---

# Nginx 단독 검증 절차

compose 기동 전(Phase 1~3)에 `nginx/templates`만으로 설정을 검증하는 레시피입니다. 파일 작성 규칙은 LF, 주석 한국어, 들여쓰기 4칸입니다.

## 1. 컨테이너 기동 (임시 로그·마운트는 스크래치패드 사용)

Git Bash 경로 변환을 막기 위해 `MSYS_NO_PATHCONV=1`을 붙이고, 호스트 경로는 절대 경로를 씁니다.

```bash
MSYS_NO_PATHCONV=1 docker run -d --name nginx-verify -p 8088:80 \
    -e NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx \
    -e 'NGINX_ENVSUBST_FILTER=^(BACKEND_|STORAGE_)' \
    -e BACKEND_UPSTREAM_1=127.0.0.1:8080 \
    -e BACKEND_UPSTREAM_2=127.0.0.1:8081 \
    -e STORAGE_UPSTREAM=127.0.0.1:9000 \
    -e STORAGE_HOST_HEADER=rustfs:9000 \
    -e STORAGE_BUCKET_NAME=audio-storage \
    -v "C:/WorkSpace/re-dubb/nginx/nginx/templates:/etc/nginx/templates:ro" \
    nginx:<확정한 태그>
```

- 컨테이너 이름은 `nginx-verify`(단독 검증용)이며, compose의 `nginx-proxy`와 구분합니다.
- **경로 변환 주의:** Git Bash는 `/`로 시작하는 인자를 윈도우 경로로 바꾼다. `docker exec`에서는 `docker exec nginx-verify sh -c "cat /etc/nginx/nginx.conf"`처럼 명령 전체를 `sh -c "..."`로 감싸 첫 인자가 `/`로 시작하지 않게 한다(권한 허용 패턴과도 일치).
- 설정이 틀리면 컨테이너가 바로 종료되므로 `docker logs nginx-verify`로 원인을 봅니다.
- 템플릿을 수정하면 치환이 다시 일어나도록 `docker rm -f nginx-verify` 후 재생성합니다(`restart`도 가능).
- 정리: `docker rm -f nginx-verify`는 허용되지만 볼륨 삭제·`system prune`은 금지입니다.

## 2. 확인 명령

```bash
docker exec nginx-verify nginx -t                                  # 문법
docker exec nginx-verify cat /etc/nginx/nginx.conf                 # V-02 치환 결과
docker exec nginx-verify grep -nE '\$uri|\$1|\$http_host' /etc/nginx/nginx.conf   # V-03 Nginx 변수 보존
docker exec nginx-verify ls -R /etc/nginx/snippets                 # 하위 폴더 구조 유지 여부
curl -sS -I http://localhost:8088/healthz
docker exec nginx-verify tail -n 20 /var/log/nginx/access.log
```

## 3. 흔한 함정 체크리스트

1. **필터 누락:** `NGINX_ENVSUBST_FILTER`가 없으면 `$uri`, `${reqBefore}` 등이 빈 문자열로 지워집니다. 치환 결과에서 반드시 확인합니다.
2. **새 `${…}` 변수:** 이름이 `BACKEND_`/`STORAGE_`로 시작하지 않으면 치환되지 않습니다.
3. **`add_header` 상속 단절:** location에 `add_header`가 하나라도 있으면 상위 값이 사라집니다. 대상 location마다 스니펫 `include`가 있는지 목록으로 점검합니다. `OPTIONS` 204를 `if` 안에서 처리할 때는 `always`와 `include` 위치를 따로 설계합니다.
4. **정규식 location의 `proxy_pass`:** URI를 쓸 수 없으므로 `rewrite … break;` 후 `proxy_pass http://s3_storage;`를 씁니다.
5. **upstream 해석:** upstream 호스트명이 해석되지 않으면 `nginx -t`가 실패합니다. 단독 검증은 `127.0.0.1:포트` 값을 씁니다. 백엔드가 없으므로 `/api` 계열 응답은 `502`가 정상입니다.
6. **access.log 위치:** 공식 이미지는 기본적으로 stdout/stderr로 심볼릭 링크됩니다. 파일 검증이 필요하면 `docker logs nginx-verify` 출력을 `grep`합니다.
7. **Windows 속도 제한:** 클라이언트가 게이트웨이 IP 하나로 보이므로 `limit_req` 판정은 응답 코드 분포로 합니다.

## 4. 증거 기록 규칙

- 직접 실행한 명령과 출력 요약을 완료 보고에 붙입니다.
- `token=` 값, 시크릿은 가려서 기록합니다.
- 실행하지 못한 항목은 `scripts/integration-checklist.md`에 "미확인"과 사유를 남깁니다.
