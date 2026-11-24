-- V3__dev_seed.sql
-- Тестовые данные для локальной проверки БД

INSERT INTO users (email, password_hash, full_name, phone_or_telegram, is_trusted, is_active)
VALUES
    ('admin@handoff.local', '$2a$10$dummyhashadmin', 'Влада Сергеевна (Админ)', '@vlada_admin', TRUE, TRUE),
    ('curator@handoff.local', '$2a$10$dummyhashcurator', 'Екатерина (Куратор)', '@ekaterina_cur', TRUE, TRUE),
    ('trusted@handoff.local', '$2a$10$dummyhashtrusted', 'Анна Доверенная', '@anna_trusted', TRUE, TRUE),
    ('student@handoff.local', '$2a$10$dummyhashstudent', 'Иван Студентов', '@ivan_stud', FALSE, TRUE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO user_roles (user_id, role_id, valid_from)
SELECT u.id, r.id, NOW()
FROM users u
JOIN roles r ON
    (u.email = 'admin@handoff.local' AND r.code = 'ADMIN') OR
    (u.email = 'curator@handoff.local' AND r.code = 'CURATOR') OR
    (u.email IN ('trusted@handoff.local', 'student@handoff.local') AND r.code = 'STUDENT')
WHERE NOT EXISTS (
    SELECT 1 FROM user_roles ur
    WHERE ur.user_id = u.id AND ur.role_id = r.id AND ur.event_id IS NULL
);

INSERT INTO storage_locations (location_type, building, room, sector, box_number, notes)
VALUES
    ('AUDITORIUM', 'Корпус D', 'D734', 'Стеллаж A', 'Коробка №1', 'Проекторы и видеооборудование'),
    ('AUDITORIUM', 'Корпус D', 'D734', 'Стеллаж B', 'Коробка №4', 'Кабели HDMI, переходники и удлинители'),
    ('ADMIN_HOME', NULL, 'Дом администратора', NULL, NULL, 'Требуется предварительное бронирование (БП-12)'),
    ('EXTERNAL_VENUE', NULL, 'Артэтаж', 'Склад площадки', NULL, 'Внешняя площадка: доступность уточнять через админа (Ф-18)')
;
-- Не создаём повторные строки локаций при повторном запуске dev-seed.

INSERT INTO equipment_models (
    name, brand, model, category_id, photo_url, specs,
    is_booking_blocked, max_booking_days_override, min_advance_hours_override
)
SELECT v.name, v.brand, v.model, c.id, v.photo_url, v.specs::jsonb,
       v.is_booking_blocked, v.max_booking_days_override, v.min_advance_hours_override
FROM (VALUES
    ('Проектор короткофокусный Epson EB-685W', 'Epson', 'EB-685W', 'PROJECTOR',
     'equipment/epson-eb-685w/main.jpg',
     '{"brightness_lumens":3500,"ports":["HDMI","VGA","USB-A"],"warnings":["Слабая яркость — не подойдёт для солнечной аудитории"],"bugs":["Иногда сбоит правый HDMI-порт"],"extra_photos":{"label":"equipment/epson-eb-685w/label.jpg","ports":"equipment/epson-eb-685w/ports.jpg"}}',
     FALSE, NULL::int, 24),
    ('Кабель HDMI 15 метров', 'UGREEN', 'HD104-15M', 'CABLE',
     'equipment/hdmi-15m/main.jpg',
     '{"length_meters":15,"connector_from":"HDMI","connector_to":"HDMI"}',
     FALSE, NULL::int, 0),
    ('Куб выставочный деревянный 50x50x100', 'Custom', 'WOOD-CUBE-100', 'FURNITURE',
     'equipment/wood-cube-100/main.jpg',
     '{"dimensions_cm":"50x50x100","material":"Дерево, белая покраска"}',
     FALSE, NULL::int, 24),
    ('Mac mini', 'Apple', 'Mac mini', 'COMPUTER',
     'equipment/mac-mini/main.jpg',
     '{"notes":"Для выставок; запрещено использовать для тестирования"}',
     FALSE, NULL::int, 24)
) AS v(name, brand, model, category_code, photo_url, specs, is_booking_blocked, max_booking_days_override, min_advance_hours_override)
JOIN equipment_categories c ON c.code = v.category_code
WHERE NOT EXISTS (SELECT 1 FROM equipment_models em WHERE em.name = v.name AND em.model IS NOT DISTINCT FROM v.model);

-- Для Mac mini явно разрешена только выставка
INSERT INTO equipment_model_allowed_task_types (model_id, task_type_id)
SELECT em.id, tt.id
FROM equipment_models em
JOIN task_types tt ON tt.code = 'EXHIBITION'
WHERE em.name = 'Mac mini'
ON CONFLICT DO NOTHING;

INSERT INTO equipment_units (
    model_id, inventory_number, serial_number, owner_info,
    requires_university_pass, condition_status, condition_notes, storage_location_id
)
SELECT em.id, v.inventory_number, v.serial_number, v.owner_info,
       v.requires_university_pass, v.condition_status, v.condition_notes, sl.id
FROM (VALUES
    ('Проектор короткофокусный Epson EB-685W', 'INV-PRJ-001', 'SN-EPS-1001', 'UNIVERSITY', TRUE, 'WORKING', NULL, 'D734', 'Стеллаж A'),
    ('Проектор короткофокусный Epson EB-685W', 'INV-PRJ-002', 'SN-EPS-1002', 'UNIVERSITY', TRUE, 'DEFECTIVE', 'Требуется замена лампы', 'D734', 'Стеллаж A'),
    ('Кабель HDMI 15 метров', 'INV-CBL-010', NULL, 'UNIVERSITY', FALSE, 'WORKING', NULL, 'D734', 'Стеллаж B'),
    ('Кабель HDMI 15 метров', 'INV-CBL-011', NULL, 'UNIVERSITY', FALSE, 'WORKING', NULL, 'D734', 'Стеллаж B'),
    ('Куб выставочный деревянный 50x50x100', 'INV-CUB-001', NULL, 'EXTERNAL', FALSE, 'WORKING', 'Находится на внешней площадке', 'Артэтаж', 'Склад площадки')
) AS v(model_name, inventory_number, serial_number, owner_info, requires_university_pass, condition_status, condition_notes, room, sector)
JOIN equipment_models em ON em.name = v.model_name
JOIN storage_locations sl ON sl.room = v.room AND sl.sector IS NOT DISTINCT FROM v.sector
WHERE NOT EXISTS (
    SELECT 1 FROM equipment_units eu WHERE eu.inventory_number = v.inventory_number
);

INSERT INTO equipment_recommendations (
    source_category_id, source_model_id, recommended_model_id,
    recommended_quantity, is_mandatory_hint, note
)
SELECT c.id, NULL, cable.id, 1, TRUE,
       'К проектору рекомендуется взять длинный HDMI-кабель (лежит в Стеллаже B, Коробка №4)'
FROM equipment_categories c
JOIN equipment_models cable ON cable.name = 'Кабель HDMI 15 метров'
WHERE c.code = 'PROJECTOR'
  AND NOT EXISTS (
      SELECT 1 FROM equipment_recommendations er
      WHERE er.source_category_id = c.id AND er.recommended_model_id = cable.id
  );

INSERT INTO events (title, event_type, venue, description, start_date, end_date, created_by_user_id)
SELECT 'Осенняя выставка проектов', 'EXTERNAL', 'Артэтаж',
       'Выездная выставка студенческих инсталляций',
       NOW() + INTERVAL '7 days', NOW() + INTERVAL '10 days', u.id
FROM users u
WHERE u.email = 'admin@handoff.local'
  AND NOT EXISTS (SELECT 1 FROM events e WHERE e.title = 'Осенняя выставка проектов');

INSERT INTO requests (
    user_id, event_id, task_type_id, usage_location, usage_building,
    usage_location_type, start_date, end_date, status, purpose
)
SELECT u.id, e.id, tt.id, 'Артэтаж, выставочная площадка', NULL,
       'EXTERNAL_VENUE', NOW() + INTERVAL '7 days', NOW() + INTERVAL '10 days',
       'PENDING', 'Нужен проектор и кабель для инсталляции на выставке'
FROM users u
JOIN events e ON e.title = 'Осенняя выставка проектов'
JOIN task_types tt ON tt.code = 'EXHIBITION'
WHERE u.email = 'student@handoff.local'
  AND NOT EXISTS (
      SELECT 1 FROM requests r
      WHERE r.user_id = u.id AND r.purpose = 'Нужен проектор и кабель для инсталляции на выставке'
  );

INSERT INTO request_items (request_id, model_id, quantity)
SELECT r.id, em.id, 1
FROM requests r
JOIN equipment_models em ON em.name IN ('Проектор короткофокусный Epson EB-685W', 'Кабель HDMI 15 метров')
WHERE r.purpose = 'Нужен проектор и кабель для инсталляции на выставке'
ON CONFLICT (request_id, model_id) DO NOTHING;
