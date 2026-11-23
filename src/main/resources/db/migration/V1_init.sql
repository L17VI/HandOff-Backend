-- V1__init.sql

CREATE TABLE users (
    id                  BIGSERIAL       PRIMARY KEY,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    password_hash       VARCHAR(255)    NOT NULL,
    full_name           VARCHAR(255)    NOT NULL,
    phone_or_telegram   VARCHAR(150),
    is_trusted          BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ,
    CONSTRAINT chk_users_email_not_blank CHECK (length(trim(email)) > 0),
    CONSTRAINT chk_users_updated_after_created CHECK (updated_at IS NULL OR updated_at >= created_at)
);

CREATE TABLE roles (
    id          BIGSERIAL       PRIMARY KEY,
    code        VARCHAR(50)     NOT NULL UNIQUE,
    name        VARCHAR(100)    NOT NULL,
    description TEXT,
    CONSTRAINT chk_roles_code CHECK (code IN ('ADMIN', 'CURATOR', 'EVENT_CURATOR', 'STUDENT'))
);

CREATE TABLE events (
    id                  BIGSERIAL       PRIMARY KEY,
    title               VARCHAR(255)    NOT NULL,
    event_type          VARCHAR(50)     NOT NULL,
    venue               VARCHAR(255)    NOT NULL,
    description         TEXT,
    start_date          TIMESTAMPTZ     NOT NULL,
    end_date            TIMESTAMPTZ     NOT NULL,
    created_by_user_id  BIGINT          NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_events_type CHECK (event_type IN ('INTERNAL', 'EXTERNAL')),
    CONSTRAINT chk_events_dates CHECK (end_date > start_date)
);

CREATE TABLE user_roles (
    id              BIGSERIAL       PRIMARY KEY,
    user_id         BIGINT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id         BIGINT          NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    event_id        BIGINT          REFERENCES events(id) ON DELETE CASCADE,
    valid_from      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    valid_until     TIMESTAMPTZ,
    assigned_by_id  BIGINT          REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_user_roles_validity CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE storage_locations (
    id              BIGSERIAL       PRIMARY KEY,
    location_type   VARCHAR(50)     NOT NULL,
    room            VARCHAR(100)    NOT NULL,
    sector          VARCHAR(100),
    box_number      VARCHAR(100),
    notes           TEXT,
    CONSTRAINT chk_storage_locations_type CHECK (
        location_type IN ('AUDITORIUM', 'ADMIN_HOME', 'EXTERNAL_VENUE')
    )
);

CREATE TABLE equipment_models (
    id                          BIGSERIAL       PRIMARY KEY,
    name                        VARCHAR(255)    NOT NULL,
    brand                       VARCHAR(100),
    model                       VARCHAR(150),
    category                    VARCHAR(50)     NOT NULL,
    photo_url                   VARCHAR(500),
    specs                       JSONB           NOT NULL DEFAULT '{}'::jsonb,
    is_booking_blocked          BOOLEAN         NOT NULL DEFAULT FALSE,
    block_reason                TEXT,
    max_booking_days_override   INT,
    min_advance_hours_override  INT,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_equipment_models_max_days CHECK (
        max_booking_days_override IS NULL OR max_booking_days_override >= 1
    ),
    CONSTRAINT chk_equipment_models_min_hours CHECK (
        min_advance_hours_override IS NULL OR min_advance_hours_override >= 0
    ),
    CONSTRAINT chk_equipment_models_block_reason CHECK (
        NOT is_booking_blocked OR (block_reason IS NOT NULL AND length(trim(block_reason)) > 0)
    )
);

CREATE TABLE equipment_units (
    id                      BIGSERIAL       PRIMARY KEY,
    model_id                BIGINT          NOT NULL REFERENCES equipment_models(id) ON DELETE RESTRICT,
    inventory_number        VARCHAR(100)    UNIQUE,
    serial_number           VARCHAR(150),
    owner_info              VARCHAR(50)     NOT NULL DEFAULT 'UNIVERSITY',
    requires_university_pass BOOLEAN        NOT NULL DEFAULT FALSE,
    condition_status        VARCHAR(50)     NOT NULL DEFAULT 'WORKING',
    condition_notes         TEXT,
    storage_location_id     BIGINT          NOT NULL REFERENCES storage_locations(id) ON DELETE RESTRICT,
    is_booking_blocked      BOOLEAN         NOT NULL DEFAULT FALSE,
    block_reason            TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_equipment_units_owner CHECK (
        owner_info IN ('PERSONAL_ADMIN', 'UNIVERSITY', 'EXTERNAL')
    ),
    CONSTRAINT chk_equipment_units_condition CHECK (
        condition_status IN ('WORKING', 'DEFECTIVE', 'IN_REPAIR', 'LOST', 'WRITTEN_OFF')
    ),
    CONSTRAINT chk_equipment_units_block_reason CHECK (
        NOT is_booking_blocked OR (block_reason IS NOT NULL AND length(trim(block_reason)) > 0)
    )
);

CREATE TABLE requests (
    id                      BIGSERIAL       PRIMARY KEY,
    user_id                 BIGINT          NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    event_id                BIGINT          REFERENCES events(id) ON DELETE SET NULL,
    task_type               VARCHAR(50),
    start_date              TIMESTAMPTZ     NOT NULL,
    end_date                TIMESTAMPTZ     NOT NULL,
    status                  VARCHAR(50)     NOT NULL DEFAULT 'PENDING',
    has_pending_extension   BOOLEAN         NOT NULL DEFAULT FALSE,
    purpose                 TEXT            NOT NULL,
    reviewed_by_user_id     BIGINT          REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at             TIMESTAMPTZ,
    rejection_reason        TEXT,
    actual_issued_at        TIMESTAMPTZ,
    issued_by_user_id       BIGINT          REFERENCES users(id) ON DELETE SET NULL,
    actual_returned_at      TIMESTAMPTZ,
    received_by_user_id     BIGINT          REFERENCES users(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_requests_dates CHECK (end_date > start_date),
    CONSTRAINT chk_requests_status CHECK (
        status IN (
            'PENDING', 'APPROVED', 'ISSUED', 'OVERDUE',
            'RETURNED', 'DISPUTE', 'REJECTED', 'CANCELLED'
        )
    ),
    CONSTRAINT chk_requests_rejection_reason CHECK (
        status <> 'REJECTED' OR (rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)
    ),
    CONSTRAINT chk_requests_actual_return_after_issue CHECK (
        actual_returned_at IS NULL OR actual_issued_at IS NULL OR actual_returned_at >= actual_issued_at
    )
);

CREATE TABLE request_items (
    id          BIGSERIAL   PRIMARY KEY,
    request_id  BIGINT      NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    model_id    BIGINT      NOT NULL REFERENCES equipment_models(id) ON DELETE RESTRICT,
    quantity    INT         NOT NULL,
    CONSTRAINT chk_request_items_quantity CHECK (quantity >= 1),
    CONSTRAINT uq_request_items_request_model UNIQUE (request_id, model_id)
);

CREATE TABLE request_item_units (
    id                  BIGSERIAL   PRIMARY KEY,
    request_item_id     BIGINT      NOT NULL REFERENCES request_items(id) ON DELETE CASCADE,
    unit_id             BIGINT      NOT NULL REFERENCES equipment_units(id) ON DELETE RESTRICT,
    CONSTRAINT uq_request_item_units_item_unit UNIQUE (request_item_id, unit_id)
);

CREATE TABLE request_extensions (
    id                      BIGSERIAL       PRIMARY KEY,
    request_id              BIGINT          NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    requested_by_user_id    BIGINT          NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    old_end_date            TIMESTAMPTZ     NOT NULL,
    new_end_date            TIMESTAMPTZ     NOT NULL,
    reason                  TEXT            NOT NULL,
    status                  VARCHAR(30)     NOT NULL DEFAULT 'PENDING',
    reviewed_by_user_id     BIGINT          REFERENCES users(id) ON DELETE SET NULL,
    rejection_reason        TEXT,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    reviewed_at             TIMESTAMPTZ,
    CONSTRAINT chk_request_extensions_dates CHECK (new_end_date > old_end_date),
    CONSTRAINT chk_request_extensions_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_request_extensions_rejection CHECK (
        status <> 'REJECTED' OR (rejection_reason IS NOT NULL AND length(trim(rejection_reason)) > 0)
    )
);

CREATE TABLE return_issues (
    id                  BIGSERIAL       PRIMARY KEY,
    request_id          BIGINT          NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    unit_id             BIGINT          NOT NULL REFERENCES equipment_units(id) ON DELETE RESTRICT,
    reported_by_user_id BIGINT          NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    issue_type          VARCHAR(50)     NOT NULL,
    description         TEXT            NOT NULL,
    photo_urls          JSONB           NOT NULL DEFAULT '[]'::jsonb,
    is_resolved         BOOLEAN         NOT NULL DEFAULT FALSE,
    resolution_notes    TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_return_issues_type CHECK (
        issue_type IN ('DAMAGE', 'MALFUNCTION', 'MISSING_PART', 'LATE_RETURN', 'OTHER')
    ),
    CONSTRAINT chk_return_issues_description CHECK (length(trim(description)) > 0)
);

CREATE TABLE equipment_recommendations (
    id                      BIGSERIAL       PRIMARY KEY,
    source_category         VARCHAR(50),
    source_model_id         BIGINT          REFERENCES equipment_models(id) ON DELETE CASCADE,
    recommended_model_id    BIGINT          NOT NULL REFERENCES equipment_models(id) ON DELETE RESTRICT,
    recommended_quantity    INT             NOT NULL DEFAULT 1,
    is_mandatory_hint       BOOLEAN         NOT NULL DEFAULT FALSE,
    note                    VARCHAR(255),
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_recommendations_source_xor CHECK (
        (source_category IS NOT NULL AND source_model_id IS NULL)
        OR
        (source_category IS NULL AND source_model_id IS NOT NULL)
    ),
    CONSTRAINT chk_recommendations_quantity CHECK (recommended_quantity >= 1),
    CONSTRAINT chk_recommendations_not_self CHECK (
        source_model_id IS NULL OR source_model_id <> recommended_model_id
    )
);

CREATE TABLE notifications (
    id                  BIGSERIAL       PRIMARY KEY,
    user_id             BIGINT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_id          BIGINT          REFERENCES requests(id) ON DELETE SET NULL,
    notification_type   VARCHAR(50)     NOT NULL,
    title               VARCHAR(255)    NOT NULL,
    message             TEXT            NOT NULL,
    is_read             BOOLEAN         NOT NULL DEFAULT FALSE,
    read_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_notifications_type CHECK (
        notification_type IN (
            'NEW_REQUEST', 'REQUEST_APPROVED', 'REQUEST_REJECTED',
            'EXTENSION_DECISION', 'RETURN_REMINDER', 'OVERDUE_ALERT'
        )
    ),
    CONSTRAINT chk_notifications_read_at CHECK (NOT is_read OR read_at IS NOT NULL)
);

CREATE TABLE booking_settings (
    setting_key         VARCHAR(100)    PRIMARY KEY,
    setting_value       VARCHAR(255)    NOT NULL,
    value_type          VARCHAR(20)     NOT NULL,
    description         TEXT,
    updated_by_user_id  BIGINT          REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_booking_settings_value_type CHECK (value_type IN ('INT', 'BOOLEAN', 'STRING'))
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX idx_user_roles_event_id ON user_roles(event_id);
CREATE INDEX idx_user_roles_assigned_by_id ON user_roles(assigned_by_id);

CREATE INDEX idx_events_created_by_user_id ON events(created_by_user_id);
CREATE INDEX idx_events_dates ON events(start_date, end_date);
CREATE INDEX idx_events_type ON events(event_type);

CREATE INDEX idx_storage_locations_type_room ON storage_locations(location_type, room);

CREATE INDEX idx_equipment_models_category ON equipment_models(category);
CREATE INDEX idx_equipment_models_blocked ON equipment_models(is_booking_blocked);
CREATE INDEX idx_equipment_models_specs_gin ON equipment_models USING GIN (specs);

CREATE INDEX idx_equipment_units_model_id ON equipment_units(model_id);
CREATE INDEX idx_equipment_units_storage_location_id ON equipment_units(storage_location_id);
CREATE INDEX idx_equipment_units_condition_status ON equipment_units(condition_status);
CREATE INDEX idx_equipment_units_blocked ON equipment_units(is_booking_blocked);

CREATE INDEX idx_requests_user_id ON requests(user_id);
CREATE INDEX idx_requests_event_id ON requests(event_id);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_requests_task_type ON requests(task_type);
CREATE INDEX idx_requests_dates ON requests(start_date, end_date);
CREATE INDEX idx_requests_status_dates ON requests(status, start_date, end_date);
CREATE INDEX idx_requests_reviewed_by ON requests(reviewed_by_user_id);
CREATE INDEX idx_requests_issued_by ON requests(issued_by_user_id);
CREATE INDEX idx_requests_received_by ON requests(received_by_user_id);

CREATE INDEX idx_request_items_request_id ON request_items(request_id);
CREATE INDEX idx_request_items_model_id ON request_items(model_id);

CREATE INDEX idx_request_item_units_request_item_id ON request_item_units(request_item_id);
CREATE INDEX idx_request_item_units_unit_id ON request_item_units(unit_id);

CREATE INDEX idx_request_extensions_request_id ON request_extensions(request_id);
CREATE INDEX idx_request_extensions_requested_by ON request_extensions(requested_by_user_id);
CREATE INDEX idx_request_extensions_reviewed_by ON request_extensions(reviewed_by_user_id);
CREATE INDEX idx_request_extensions_status ON request_extensions(status);

CREATE INDEX idx_return_issues_request_id ON return_issues(request_id);
CREATE INDEX idx_return_issues_unit_id ON return_issues(unit_id);
CREATE INDEX idx_return_issues_reported_by ON return_issues(reported_by_user_id);
CREATE INDEX idx_return_issues_type ON return_issues(issue_type);
CREATE INDEX idx_return_issues_resolved ON return_issues(is_resolved);
CREATE INDEX idx_return_issues_photo_urls_gin ON return_issues USING GIN (photo_urls);

CREATE INDEX idx_equipment_recommendations_source_category ON equipment_recommendations(source_category);
CREATE INDEX idx_equipment_recommendations_source_model_id ON equipment_recommendations(source_model_id);
CREATE INDEX idx_equipment_recommendations_recommended_model_id ON equipment_recommendations(recommended_model_id);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_request_id ON notifications(request_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_type ON notifications(notification_type);

CREATE INDEX idx_booking_settings_updated_by ON booking_settings(updated_by_user_id);