-- V2__seed_initial_data.sql

INSERT INTO roles (code, name, description)
VALUES
    ('ADMIN', 'Администратор', 'Полный доступ: управление пользователями, каталогом, настройками и всеми заявками'),
    ('CURATOR', 'Куратор', 'Координатор: управление каталогом, подтверждение/отклонение заявок и ведение мероприятий'),
    ('EVENT_CURATOR', 'Куратор мероприятия', 'Временные расширенные права ответственного за конкретное мероприятие (Ф-63)'),
    ('STUDENT', 'Пользователь (студент/преподаватель)', 'Просмотр каталога, оформление заявок, отметка получения и возврата')
ON CONFLICT (code) DO NOTHING;

INSERT INTO booking_settings (setting_key, setting_value, value_type, description)
VALUES
    ('default_max_booking_days', '14', 'INT', 'Максимальный срок бронирования по умолчанию в днях (БП-10)'),
    ('university_pass_max_days', '5', 'INT', 'Максимальный срок бронирования при требовании материального пропуска вуза в днях (БП-11)'),
    ('admin_home_min_advance_hours', '24', 'INT', 'Минимальный срок предзаказа в часах для оборудования из дома администратора (БП-12)'),
    ('default_min_advance_hours', '0', 'INT', 'Минимальный срок предзаказа по умолчанию в часах для мелкого оборудования (БП-13)'),
    ('task_type_priority_order', 'EXHIBITION,DEFENSE,TEST', 'STRING', 'Приоритет типов задач при конфликте заявок (БП-22)'),
    ('allow_student_extensions', 'true', 'BOOLEAN', 'Разрешить пользователям запрашивать продление брони (Ф-37)')
ON CONFLICT (setting_key) DO NOTHING;