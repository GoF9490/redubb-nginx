-- 1. 회원 마스터 테이블 (Google OAuth2 최소 정보 + 프로필 이미지 URL)
CREATE TABLE users (
    user_id           BIGSERIAL    PRIMARY KEY,
    provider          VARCHAR(20)  NOT NULL DEFAULT 'GOOGLE',
    provider_id       VARCHAR(100) NOT NULL,
    email             VARCHAR(150) NOT NULL,
    profile_image_url VARCHAR(500) NULL,
    role              VARCHAR(30)  NOT NULL DEFAULT 'ROLE_USER',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at     TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_users_provider_id UNIQUE (provider_id),
    CONSTRAINT uk_users_email       UNIQUE (email)
);

-- 2. 음원 메타데이터 및 비동기 변환 상태 테이블
CREATE TABLE tracks (
    track_id          UUID          PRIMARY KEY,
    uploader_id       BIGINT        NULL REFERENCES users(user_id) ON DELETE SET NULL,
    title             VARCHAR(200)  NOT NULL,
    artist            VARCHAR(150)  NOT NULL DEFAULT 'Unknown Artist',
    album             VARCHAR(200)  NULL,
    duration_seconds  INT           NOT NULL CHECK (duration_seconds > 0),
    original_filename VARCHAR(255)  NOT NULL,
    file_extension    VARCHAR(20)   NOT NULL,
    file_size_bytes   BIGINT        NOT NULL CHECK (file_size_bytes > 0),
    mime_type         VARCHAR(100)  NOT NULL,
    original_s3_key   VARCHAR(500)  NOT NULL,
    artwork_s3_key    VARCHAR(500)  NULL,
    hls_playlist_key  VARCHAR(500)  NULL,
    status            VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    error_message     VARCHAR(500)  NULL,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_tracks_status CHECK (status IN ('PENDING', 'PROCESSING', 'READY', 'FAILED'))
);

-- 3. 스트리밍 및 원본 다운로드 이력 테이블
CREATE TABLE playback_logs (
    log_id      BIGSERIAL   PRIMARY KEY,
    track_id    UUID        NOT NULL REFERENCES tracks(track_id) ON DELETE CASCADE,
    user_id     BIGINT      NULL REFERENCES users(user_id) ON DELETE SET NULL,
    action_type VARCHAR(20) NOT NULL DEFAULT 'STREAM',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_playback_logs_action CHECK (action_type IN ('STREAM', 'DOWNLOAD'))
);

-- 4. 최소 필수 인덱스 생성
CREATE INDEX idx_tracks_created_at_desc   ON tracks (created_at DESC);
CREATE INDEX idx_tracks_status_created_at ON tracks (status, created_at DESC);
CREATE INDEX idx_playback_logs_track_id   ON playback_logs (track_id);
