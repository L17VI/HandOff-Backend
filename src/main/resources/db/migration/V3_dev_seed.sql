-- V3__dev_seed.sql
-- Тестовый набор данных для локальной проверки БД и связки с MinIO/S3

-- 1. Тестовые пользователи (админ, куратор, доверенный студент, обычный студент)
INSERT INTO users (email, password_hash, full_name, phone_or_telegram, is_trusted, is_active)
VALUES
    ('admin@handoff.local', '$2a$10$dummyhashadmin', 'Влада Сергеевна (Админ)', '@vlada_admin', TRUE, TRUE),
    ('curator@handoff.local', '$2a$10$dummyhashcurator', 'Екатерина (Куратор)', '@ekaterina_cur', TRUE, TRUE),
    ('trusted@handoff.local', '$2a$10$dummyhashtrusted', 'Анна Доверенная', '@anna_trusted', TRUE, TRUE),
    ('student@handoff.local', '$2a$10$dummyhashstudent', 'Иван Студентов', '@ivan_stud', FALSE, TRUE)
ON CONFLICT (email) DO NOTHING;

-- Назначение ролей
INSERT INTO user_roles (user_id, role_id, valid_from)
SELECT u.id, r.id, NOW()
FROM users u
JOIN roles r ON (
    (u.email = 'admin@handoff.local' AND r.code = 'ADMIN') OR
    (u.email = 'curator@handoff.local' AND r.code = 'CURATOR') OR
    (u.email = 'trusted@handoff.local' AND r.code = 'STUDENT') OR
    (u.email = 'student@handoff.local' AND r.code = 'STUDENT')
);

-- 2. Места хранения (аудитория с сектором и коробкой, дом админа, внешняя площадка)
INSERT INTO storage_locations (location_type, room, sector, box_number, notes)
VALUES
    ('AUDITORIUM', 'D734', 'Стеллаж A', 'Коробка №1', 'Проекторы и видеооборудование'),
    ('AUDITORIUM', 'D734', 'Стеллаж B', 'Коробка №4', 'Кабели HDMI, переходники и удлинители'),
    ('ADMIN_HOME', 'Дом администратора', NULL, NULL, 'Требуется предварительное бронирование (БП-12)'),
    ('EXTERNAL_VENUE', 'Артэтаж', 'Склад площадки', NULL, 'Внешняя площадка: доступность уточнять через админа (Ф-18)');

-- 3. Модели каталога (ссылки photo_url подготовлены под выгрузку фото с Google Диска в бакет MinIO)
INSERT INTO equipment_models (
    name, brand, model, category, photo_url, specs,
    is_booking_blocked, max_booking_days_override, min_advance_hours_override
)
VALUES
    (
        'Проектор короткофокусный Epson EB-685W',
        'Epson',
        'EB-685W',
        'PROJECTOR',
        'equipment/epson-eb-685w/main.jpg',
        '{
            "brightness_lumens": 3500,
            "ports": ["HDMI", "VGA", "USB-A"],
            "warnings": ["Слабая яркость — не подойдёт для солнечной аудитории"],
            "bugs": ["Иногда сбоит правый HDMI-порт"],
            "extra_photos": {
                "label": "equipment/epson-eb-685w/label.jpg",
                "ports": "equipment/epson-eb-685w/ports.jpg"
            }
        }'::jsonb,
        FALSE,
        NULL,
        24
    ),
    (
        'Кабель HDMI 15 метров',
        'UGREEN',
        'HD104-15M',
        'CABLE',
        'equipment/hdmi-15m/main.jpg',
        '{
            "length_meters": 15,
            "connector_from": "HDMI",
            "connector_to": "HDMI"
        }'::jsonb,
        FALSE,
        NULL,
        0
    ),
    (
        'Куб выставочный деревянный 50x50x100',
        'Custom',
        'WOOD-CUBE-100',
        'FURNITURE',
        'equipment/wood-cube-100/main.jpg',
        '{
            "dimensions_cm": "50x50x100",
            "material": "Дерево, белая покраска",
            "allowed_task_type": "EXHIBITION"
        }'::jsonb,
        FALSE,
        NULL,
        24
    );

-- 4. Физические экземпляры (несколько штук одной модели с разными состояниями)
INSERT INTO equipment_units (
    model_id, inventory_number, serial_number, owner_info,
    requires_university_pass, condition_status, condition_notes, storage_location_id
)
VALUES
    (1, 'INV-PRJ-001', 'SN-EPS-1001', 'UNIVERSITY', TRUE, 'WORKING', NULL, 1),
    (1, 'INV-PRJ-002', 'SN-EPS-1002', 'UNIVERSITY', TRUE, 'DEFECTIVE', 'Требуется замена лампы', 1),
    (2, 'INV-CBL-010', NULL, 'UNIVERSITY', FALSE, 'WORKING', NULL, 2),
    (2, 'INV-CBL-011', NULL, 'UNIVERSITY', FALSE, 'WORKING', NULL, 2),
    (3, 'INV-CUB-001', NULL, 'EXTERNAL', FALSE, 'WORKING', 'Находится на внешней площадке', 4);

-- 5. Рекомендации сопутствующих кабелей к категории PROJECTOR (Ф-25, Ф-31)
INSERT INTO equipment_recommendations (
    source_category, source_model_id, recommended_model_id, recommended_quantity, is_mandatory_hint, note
)
VALUES
    ('PROJECTOR', NULL, 2, 1, TRUE, 'К проектору рекомендуется взять длинный HDMI-кабель (лежит в Стеллаже B, Коробка №4)');

-- 6. Мероприятие и тестовая заявка
INSERT INTO events (title, event_type, venue, description, start_date, end_date, created_by_user_id)
VALUES
    (
        'Осенняя выставка проектов',
        'EXTERNAL',
        'Артэтаж',
        'Выездная выставка студенческих инсталляций',
        NOW() + INTERVAL '7 days',
        NOW() + INTERVAL '10 days',
        1
    );

INSERT INTO requests (user_id, event_id, task_type, start_date, end_date, status, purpose)
VALUES
    (
        4,
        1,
        'EXHIBITION',
        NOW() + INTERVAL '7 days',
        NOW() + INTERVAL '10 days',
        'PENDING',
        'Нужен проектор и кабель для инсталляции на выставке'
    );

INSERT INTO request_items (request_id, model_id, quantity)
VALUES
    (1, 1, 1),
    (1, 2, 1);