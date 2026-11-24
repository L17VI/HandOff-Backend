-- V2__seed_initial_data.sql
-- Базовые справочники и настройки

INSERT INTO roles (code, name, description)
VALUES
    ('ADMIN', 'Администратор', 'Полный доступ: управление пользователями, каталогом, настройками и всеми заявками'),
    ('CURATOR', 'Куратор', 'Координатор: управление каталогом, подтверждение/отклонение заявок и ведение мероприятий'),
    ('EVENT_CURATOR', 'Куратор мероприятия', 'Временные расширенные права ответственного за конкретное мероприятие (Ф-63)'),
    ('STUDENT', 'Пользователь (студент/преподаватель)', 'Просмотр каталога, оформление заявок, отметка получения и возврата')
ON CONFLICT (code) DO NOTHING;

INSERT INTO equipment_categories (code, name, description)
VALUES
    ('PROJECTOR', 'Проекторы', 'Проекционное оборудование'),
    ('CABLE', 'Кабели и переходники', 'Кабели, адаптеры и переходники'),
    ('FURNITURE', 'Мебель и конструкции', 'Мебель, выставочные конструкции и стенды'),
    ('COMPUTER', 'Компьютерная техника', 'Компьютеры и периферийное оборудование')
ON CONFLICT (code) DO NOTHING;

INSERT INTO task_types (code, name, description)
VALUES
    ('EXHIBITION', 'Выставка', 'Выставки и экспозиции'),
    ('DEFENSE', 'Защита', 'Защиты проектов и дипломных работ'),
    ('TEST', 'Тестирование', 'Тестирование и проверка оборудования/проектов')
ON CONFLICT (code) DO NOTHING;

INSERT INTO booking_settings (setting_key, setting_value, value_type, description)
VALUES
    ('default_max_booking_days', '14', 'INT', 'Максимальный срок бронирования по умолчанию в днях (БП-10)'),
    ('university_pass_max_days', '5', 'INT', 'Максимальный срок бронирования, если для выбранного места использования требуется материальный пропуск вуза (БП-11)'),
    ('admin_home_min_advance_hours', '24', 'INT', 'Минимальный срок предзаказа в часах для оборудования из дома администратора (БП-12)'),
    ('default_min_advance_hours', '0', 'INT', 'Минимальный срок предзаказа по умолчанию для мелкого оборудования (БП-13)'),
    ('task_type_priority_order', 'EXHIBITION,DEFENSE,TEST', 'STRING', 'Приоритет типов задач при конфликте заявок (БП-22)'),
    ('allow_student_extensions', 'true', 'BOOLEAN', 'Разрешить пользователям запрашивать продление брони (Ф-37)')
ON CONFLICT (setting_key) DO NOTHING;
