#!/usr/bin/env bash
# 스모크 검증 (PRD §8.2, V-10~V-25).
#
# 사용법:
#   BASE_URL=http://localhost bash scripts/smoke.sh
#
# 종료 코드: FAIL이 하나라도 있으면 1, 없으면 0 (SKIP은 실패로 보지 않는다).
# 주의: 출력에 시크릿이 섞이지 않도록 mask_secret을 거쳐 출력한다(token= 값 마스킹).

set -u

BASE_URL="${BASE_URL:-http://localhost}"
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"
UPLOAD_TIMEOUT="${UPLOAD_TIMEOUT:-20}"
NGINX_CONTAINER="${NGINX_CONTAINER:-nginx-proxy}"
SCRATCH=""

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# 출력 직전 token= 값을 가린다
mask_secret() {
    sed -E 's/(token=)[^&[:space:]"]+/\1***/g'
}

# pass <ID> <메시지>
pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS  %s  %s\n' "$1" "$2" | mask_secret
}

# fail <ID> <메시지>
fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL  %s  %s\n' "$1" "$2" | mask_secret
}

# skip <ID> <사유>
skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf 'SKIP  %s  %s\n' "$1" "$2" | mask_secret
}

# http_status <curl 인자...> : HTTP 상태 코드만 출력한다(연결 실패 시 000)
http_status() {
    curl -sS -o /dev/null -w '%{http_code}' --max-time "$CURL_TIMEOUT" "$@" 2>/dev/null || true
}

# http_headers <curl 인자...> : 응답 헤더 전체를 출력한다
http_headers() {
    curl -sS -D - -o /dev/null --max-time "$CURL_TIMEOUT" "$@" 2>/dev/null || true
}

# check <ID> <설명> <기대 상태코드> <curl 인자...> : 상태 코드 일치 여부로 판정한다
check() {
    local id="$1" desc="$2" expected="$3"
    shift 3
    local actual
    actual="$(http_status "$@")"
    if [ "$actual" = "$expected" ]; then
        pass "$id" "$desc (HTTP $actual)"
    else
        fail "$id" "$desc (기대 $expected, 실제 $actual)"
    fi
}

# 요약 출력 후 종료 코드를 결정한다
summarize() {
    printf '\n요약: PASS=%d FAIL=%d SKIP=%d (대상 %s)\n' \
        "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$BASE_URL"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        return 1
    fi
    return 0
}

# header_value <헤더 전체> <헤더 이름> : 헤더 값을 출력한다(대소문자 무시, CR 제거)
header_value() {
    printf '%s\n' "$1" | tr -d '\r' | grep -i "^$2:" | head -n 1 | sed -E 's/^[^:]*:[[:space:]]*//'
}

# 업로드 속도 제한(upload_limit 30r/m burst 10) 보호:
# 업로드 location을 때리는 호출은 한 번 실행에 최대 4회(V-24)로 제한한다.
# 연속 재실행으로 burst가 소진되면 429가 나므로, 그 경우 오탐임을 메시지에 명시하고 대기 후 재시도를 안내한다.
# /oauth2/authorization/google은 호출하지 않는다(V-60은 T5-3).

verify_spa() {
    local headers cc
    headers="$(http_headers "$BASE_URL/")"
    cc="$(header_value "$headers" 'Cache-Control')"
    if printf '%s' "$headers" | head -n 1 | grep -q ' 200' && printf '%s' "$cc" | grep -qi 'no-cache'; then
        pass "V-10" "SPA index (HTTP 200, Cache-Control: $cc)"
    else
        fail "V-10" "SPA index 응답 이상 (Cache-Control: ${cc:-없음})"
    fi
    check "V-11" "SPA 새로고침 /auth/callback" 200 "$BASE_URL/auth/callback"
    check "V-12" "없는 정적 파일은 404 (HTML 대체 아님)" 404 "$BASE_URL/assets/smoke-none-$$.js"

    # V-13: 200이고 접근 로그에 남지 않음 (고유 쿼리로 로그를 검색)
    local marker="smoke13-$$-$RANDOM" code
    code="$(http_status "$BASE_URL/healthz?m=$marker")"
    if [ "$code" != "200" ]; then
        fail "V-13" "/healthz 기대 200, 실제 $code"
    elif ! docker logs "$NGINX_CONTAINER" >/dev/null 2>&1; then
        skip "V-13" "/healthz 200 확인, 접근 로그 미기록은 docker logs 접근 불가로 미확인"
    elif docker logs "$NGINX_CONTAINER" 2>&1 | grep -q "$marker"; then
        fail "V-13" "/healthz가 접근 로그에 기록됨"
    else
        pass "V-13" "/healthz 200, 접근 로그 미기록"
    fi
}

verify_api() {
    local code ctype body
    # V-14: 두 경로 모두 백엔드 JSON이며 SPA HTML이 아니다
    local ok=1 detail="" path
    for path in /api/tracks /api; do
        body="$(curl -sS -D "$SCRATCH/h" --max-time "$CURL_TIMEOUT" "$BASE_URL$path" 2>/dev/null || true)"
        code="$(head -n 1 "$SCRATCH/h" | tr -d '\r' | awk '{print $2}')"
        ctype="$(header_value "$(cat "$SCRATCH/h")" 'Content-Type')"
        detail="$detail $path=$code($ctype)"
        if ! printf '%s' "$ctype" | grep -qi 'application/json' || printf '%s' "$body" | grep -qi '<html'; then
            ok=0
        fi
        case "$code" in 200|404) ;; *) ok=0 ;; esac
    done
    if [ "$ok" = 1 ]; then pass "V-14" "백엔드 JSON 응답:$detail"; else fail "V-14" "백엔드 JSON 아님:$detail"; fi

    # V-15: 토큰 없는 /api/auth/me는 401 JSON
    body="$(curl -sS -D "$SCRATCH/h" --max-time "$CURL_TIMEOUT" "$BASE_URL/api/auth/me" 2>/dev/null || true)"
    code="$(head -n 1 "$SCRATCH/h" | tr -d '\r' | awk '{print $2}')"
    ctype="$(header_value "$(cat "$SCRATCH/h")" 'Content-Type')"
    if [ "$code" = "401" ] && printf '%s' "$ctype" | grep -qi 'application/json' && printf '%s' "$body" | grep -q '"code"'; then
        pass "V-15" "토큰 없는 /api/auth/me는 401 JSON"
    else
        fail "V-15" "기대 401 JSON, 실제 $code ($ctype)"
    fi
}

verify_storage() {
    local headers acao xc
    check "V-20" "/internal-storage 직접 호출 차단" 404 "$BASE_URL/internal-storage/original/test.wav"

    headers="$(http_headers "$BASE_URL/stream/smoke-none-$$/index.m3u8")"
    acao="$(header_value "$headers" 'Access-Control-Allow-Origin')"
    xc="$(header_value "$headers" 'X-Cache-Status')"
    if printf '%s' "$headers" | head -n 1 | grep -q ' 404' && [ "$acao" = "*" ] && [ -n "$xc" ]; then
        pass "V-21" "없는 HLS 404, ACAO=*, X-Cache-Status=$xc"
    else
        fail "V-21" "기대 404+ACAO *+X-Cache-Status, 실제 $(printf '%s' "$headers" | head -n 1 | tr -d '\r') ACAO=${acao:-없음} XCache=${xc:-없음}"
    fi

    headers="$(http_headers -X OPTIONS -H 'Origin: http://example.com' -H 'Access-Control-Request-Method: GET' "$BASE_URL/stream/x/index.m3u8")"
    acao="$(header_value "$headers" 'Access-Control-Allow-Origin')"
    if printf '%s' "$headers" | head -n 1 | grep -q ' 204' && [ -n "$acao" ]; then
        pass "V-22" "OPTIONS 204, ACAO=$acao"
    else
        fail "V-22" "기대 204+CORS, 실제 $(printf '%s' "$headers" | head -n 1 | tr -d '\r') ACAO=${acao:-없음}"
    fi

    local code
    code="$(http_status -X POST "$BASE_URL/stream/x")"
    case "$code" in
        403|405) pass "V-23" "POST /stream 차단 (HTTP $code)" ;;
        *) fail "V-23" "기대 403/405, 실제 $code" ;;
    esac
}

# 요청 결과 한 줄 요약: <상태코드>|<Content-Type>|<curl 종료코드>
upload_probe() {
    local out rc
    out="$(curl -sS -o "$SCRATCH/body" -w '%{http_code}|%{content_type}' --max-time "$UPLOAD_TIMEOUT" "$@" 2>"$SCRATCH/err")"
    rc=$?
    printf '%s|%s' "$out" "$rc"
}

verify_upload() {
    local big="$SCRATCH/over.bin" under="$SCRATCH/under.bin" r code ctype rc
    dd if=/dev/zero of="$big" bs=1M count=111 status=none
    dd if=/dev/zero of="$under" bs=1M count=109 status=none

    # 111MB (Content-Length 있음): 413 JSON 기대
    r="$(upload_probe -X POST -H 'Content-Type: application/octet-stream' --data-binary "@$big" "$BASE_URL/api/tracks/upload")"
    code="${r%%|*}"; ctype="$(printf '%s' "$r" | cut -d'|' -f2)"; rc="${r##*|}"
    if [ "$code" = "413" ] && printf '%s' "$ctype" | grep -qi 'application/json' && grep -q PAYLOAD_TOO_LARGE "$SCRATCH/body"; then
        pass "V-24" "111MB는 413 JSON(PAYLOAD_TOO_LARGE)"
    elif [ "$code" = "429" ]; then
        fail "V-24" "111MB 요청이 429 (upload_limit 속도 제한 오탐, 1분 대기 후 재실행)"
    else
        fail "V-24" "111MB 기대 413 JSON, 실제 HTTP $code ($ctype) curl=$rc"
    fi

    # 109MB (110MB 이하): Nginx를 통과해 백엔드 응답이어야 한다(multipart가 아니라 업로드 트랙은 생성되지 않음)
    # 호스트 curl이 큰 본문 전송 중 백엔드의 조기 응답(415)을 받지 못하고 멈추는 현상이 있어(Docker Desktop 추정),
    # 응답 미수신(HTTP 100/000)이면 고유 쿼리로 Nginx 접근 로그의 상태·upstream을 확인해 판정한다.
    local marker="smoke24-$$-$RANDOM" lg lgcode
    r="$(upload_probe -X POST -H 'Content-Type: application/octet-stream' --data-binary "@$under" "$BASE_URL/api/tracks/upload?m=$marker")"
    code="${r%%|*}"; ctype="$(printf '%s' "$r" | cut -d'|' -f2)"; rc="${r##*|}"
    case "$code" in
        100|000)
            lg="$(docker logs "$NGINX_CONTAINER" 2>&1 | grep "$marker" | tail -n 1)"
            lgcode="$(printf '%s' "$lg" | sed -nE 's/.*" ([0-9]{3}) [0-9]+ ".*/\1/p')"
            if [ -n "$lg" ] && [ "$lgcode" != "413" ] && printf '%s' "$lg" | grep -qE 'upstream: [0-9.]+:[0-9]+'; then
                pass "V-24" "109MB: 호스트 curl은 응답 미수신(curl=$rc, Docker Desktop 추정), Nginx 로그상 upstream 전달·HTTP $lgcode"
            else
                fail "V-24" "109MB 응답 없음(curl=$rc)이며 Nginx 로그에서 upstream 전달 근거 없음"
            fi ;;
        413) fail "V-24" "109MB가 413 (110M 한도 이내인데 거부됨)" ;;
        429) fail "V-24" "109MB 요청이 429 (속도 제한 오탐, 1분 대기 후 재실행)" ;;
        400|401|415|403)
            if printf '%s' "$ctype" | grep -qi 'application/json' && grep -q '"code"' "$SCRATCH/body"; then
                pass "V-24" "109MB는 백엔드로 전달됨 (백엔드 JSON 응답 HTTP $code, 413 아님)"
            else
                fail "V-24" "109MB 응답이 백엔드 JSON 형식이 아님 (HTTP $code, $ctype)"
            fi ;;
        *) fail "V-24" "109MB 예상 밖 응답 HTTP $code ($ctype) curl=$rc" ;;
    esac

    # chunked 111MB: request_buffering off 환경의 413/연결 종료 동작 (정보성, 판정에 포함하지 않음)
    marker="smoke24c-$$-$RANDOM"
    r="$(upload_probe -X POST -H 'Content-Type: application/octet-stream' -H 'Transfer-Encoding: chunked' -T "$big" "$BASE_URL/api/tracks/upload?m=$marker")"
    code="${r%%|*}"; rc="${r##*|}"
    lg="$(docker logs "$NGINX_CONTAINER" 2>&1 | grep "$marker" | tail -n 1 | sed -E 's/.*" ([0-9]{3}) [0-9]+ ".*(upstream: [^ ]*).*/\1 \2/')"
    printf 'INFO  V-24  chunked 111MB: 호스트 curl HTTP %s (curl 종료코드 %s), Nginx 로그 기준: %s\n' "$code" "$rc" "${lg:-기록 없음}"
}

verify_balance() {
    local i marker="smoke25-$$-$RANDOM" ips1 ips2 up1 up2 log
    for i in 1 2 3 4 5 6 7 8 9 10; do
        http_status "$BASE_URL/api/tracks?m=$marker" >/dev/null
    done
    if ! log="$(docker logs "$NGINX_CONTAINER" 2>&1 | grep "$marker")"; then
        skip "V-25" "docker logs 접근 불가로 미확인"
        return
    fi
    local cnt
    cnt="$(printf '%s\n' "$log" | wc -l | tr -d ' ')"
    ips1="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' web-server-1 2>/dev/null | awk '{print $1}')"
    ips2="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' web-server-2 2>/dev/null | awk '{print $1}')"
    up1="$(printf '%s\n' "$log" | grep -c "upstream: ${ips1}:" || true)"
    up2="$(printf '%s\n' "$log" | grep -c "upstream: ${ips2}:" || true)"
    if [ -z "$ips1" ] || [ -z "$ips2" ]; then
        skip "V-25" "web-server-1/2 IP를 얻지 못해 미확인 (로그 ${cnt}건)"
    elif [ "$up1" -gt 0 ] && [ "$up2" -gt 0 ]; then
        pass "V-25" "10회 중 로그 ${cnt}건: web-server-1($ips1)=$up1, web-server-2($ips2)=$up2"
    else
        fail "V-25" "분산 실패: web-server-1($ips1)=$up1, web-server-2($ips2)=$up2 (로그 ${cnt}건)"
    fi
}

main() {
    printf '스모크 시작: BASE_URL=%s\n' "$BASE_URL"

    # 사전 점검: 대상이 응답하지 않으면 이후 항목은 의미가 없다
    check "PRE" "대상 연결 확인 (/healthz)" 200 "$BASE_URL/healthz"

    SCRATCH="$(mktemp -d)"
    trap 'rm -rf "$SCRATCH"' EXIT

    verify_spa
    verify_api
    verify_storage
    verify_balance
    # 업로드(속도 제한 대상)는 마지막에 실행한다
    verify_upload

    summarize
}

main "$@"
exit $?
