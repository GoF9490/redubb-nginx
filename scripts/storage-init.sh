#!/bin/sh
# RustFS 버킷 생성 및 익명 읽기 정책 적용 (PRD-06 §3 Step 2, PRD §5.2)
# - 실행 이미지: amazon/aws-cli (entrypoint가 aws이므로 compose에서 /bin/sh로 덮어쓴다)
# - 익명 읽기는 hls/*, artwork/* 의 s3:GetObject만 허용한다(s3:ListBucket 비허용, original/ 비공개)
# - 멱등: 버킷이 이미 있으면 생성을 건너뛰고 정책은 매번 덮어쓴다
set -eu

BUCKET="${STORAGE_BUCKET_NAME:-audio-storage}"
ENDPOINT="http://rustfs:9000"
POLICY_FILE="/tmp/policy.json"

# 버킷이 없을 때만 생성한다
if aws --endpoint-url "$ENDPOINT" s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "버킷이 이미 존재합니다: $BUCKET"
else
    aws --endpoint-url "$ENDPOINT" s3 mb "s3://$BUCKET"
fi

# 정책 JSON 생성(변수만 치환되도록 heredoc 구분자를 따옴표 없이 사용)
cat > "$POLICY_FILE" << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": ["s3:GetObject"],
            "Resource": [
                "arn:aws:s3:::${BUCKET}/hls/*",
                "arn:aws:s3:::${BUCKET}/artwork/*"
            ]
        }
    ]
}
EOF

aws --endpoint-url "$ENDPOINT" s3api put-bucket-policy \
    --bucket "$BUCKET" --policy "file://$POLICY_FILE"

echo '=== RustFS audio-storage 버킷 생성 및 내부 프록시 읽기 정책 설정 완료 ==='
exit 0
