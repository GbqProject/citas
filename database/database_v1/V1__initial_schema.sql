-- MySQL 8.4 | Sistema ficticio FCV de agendamiento
-- Todas las fechas se guardan en UTC; la aplicación presenta America/Bogota.
CREATE DATABASE IF NOT EXISTS fcv_citas_v1
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE fcv_citas_v1;

CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  document_type VARCHAR(20) NOT NULL,
  document_number VARCHAR(30) NOT NULL,
  email VARCHAR(254) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_users_document UNIQUE (document_type, document_number),
  CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE roles (
  code VARCHAR(30) PRIMARY KEY,
  description VARCHAR(100) NOT NULL
);

CREATE TABLE user_roles (
  user_id BIGINT UNSIGNED NOT NULL,
  role_code VARCHAR(30) NOT NULL,
  assigned_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id, role_code),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_user_roles_role FOREIGN KEY (role_code) REFERENCES roles(code)
);

CREATE TABLE insurance_regimes (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  CONSTRAINT uq_regime_name UNIQUE (name)
);

CREATE TABLE eps (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  regime_id SMALLINT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_eps_name UNIQUE (name),
  CONSTRAINT fk_eps_regime FOREIGN KEY (regime_id) REFERENCES insurance_regimes(id)
);

CREATE TABLE eps_plans (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  eps_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(150) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_eps_plan UNIQUE (eps_id, name),
  CONSTRAINT fk_plan_eps FOREIGN KEY (eps_id) REFERENCES eps(id)
);

CREATE TABLE user_insurance_affiliations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  eps_plan_id BIGINT UNSIGNED NOT NULL,
  affiliate_number VARCHAR(60) NOT NULL,
  is_current BOOLEAN NOT NULL DEFAULT TRUE,
  starts_on DATE NOT NULL,
  ends_on DATE NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_affiliation_number UNIQUE (eps_plan_id, affiliate_number),
  CONSTRAINT ck_affiliation_dates CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CONSTRAINT fk_affiliation_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_affiliation_plan FOREIGN KEY (eps_plan_id) REFERENCES eps_plans(id),
  INDEX ix_affiliation_current (user_id, is_current)
);

CREATE TABLE locations (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(180) NOT NULL,
  address VARCHAR(255) NOT NULL,
  CONSTRAINT uq_location_code UNIQUE (code)
);

CREATE TABLE specialties (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  appointment_kind ENUM('GENERAL','SPECIALIZED') NOT NULL,
  duration_minutes TINYINT UNSIGNED NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_specialty_name UNIQUE (name),
  CONSTRAINT ck_specialty_duration CHECK (duration_minutes IN (30, 60))
);

CREATE TABLE professionals (
  user_id BIGINT UNSIGNED PRIMARY KEY,
  professional_code VARCHAR(40) NOT NULL,
  license_number VARCHAR(60) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_professional_code UNIQUE (professional_code),
  CONSTRAINT uq_professional_license UNIQUE (license_number),
  CONSTRAINT fk_professional_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE professional_specialties (
  professional_id BIGINT UNSIGNED NOT NULL,
  specialty_id BIGINT UNSIGNED NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  primary_professional_id BIGINT UNSIGNED GENERATED ALWAYS AS
    (CASE WHEN is_primary THEN professional_id ELSE NULL END) STORED,
  PRIMARY KEY (professional_id, specialty_id),
  CONSTRAINT uq_one_primary_specialty UNIQUE (primary_professional_id),
  CONSTRAINT fk_prof_spec_professional FOREIGN KEY (professional_id) REFERENCES professionals(user_id),
  CONSTRAINT fk_prof_spec_specialty FOREIGN KEY (specialty_id) REFERENCES specialties(id)
);

CREATE TABLE professional_locations (
  professional_id BIGINT UNSIGNED NOT NULL,
  location_id SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (professional_id, location_id),
  CONSTRAINT fk_prof_location_professional FOREIGN KEY (professional_id) REFERENCES professionals(user_id),
  CONSTRAINT fk_prof_location_location FOREIGN KEY (location_id) REFERENCES locations(id)
);

CREATE TABLE availability_blocks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  professional_id BIGINT UNSIGNED NOT NULL,
  location_id SMALLINT UNSIGNED NOT NULL,
  availability_date DATE NOT NULL,
  starts_at TIME NOT NULL,
  ends_at TIME NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_block_start UNIQUE (professional_id, availability_date, starts_at),
  CONSTRAINT ck_block_times CHECK (ends_at > starts_at),
  CONSTRAINT fk_block_professional FOREIGN KEY (professional_id) REFERENCES professionals(user_id),
  CONSTRAINT fk_block_location FOREIGN KEY (location_id) REFERENCES locations(id),
  INDEX ix_block_calendar (professional_id, availability_date, starts_at)
);

CREATE TABLE availability_slots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  availability_block_id BIGINT UNSIGNED NOT NULL,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NOT NULL,
  CONSTRAINT uq_slot_start UNIQUE (availability_block_id, starts_at),
  CONSTRAINT ck_slot_duration CHECK (ends_at = starts_at + INTERVAL 30 MINUTE),
  CONSTRAINT fk_slot_block FOREIGN KEY (availability_block_id) REFERENCES availability_blocks(id),
  INDEX ix_slot_time (starts_at)
);

CREATE TABLE appointment_statuses (
  code VARCHAR(30) PRIMARY KEY,
  description VARCHAR(100) NOT NULL,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE appointments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id BIGINT UNSIGNED NOT NULL,
  professional_id BIGINT UNSIGNED NOT NULL,
  specialty_id BIGINT UNSIGNED NOT NULL,
  location_id SMALLINT UNSIGNED NOT NULL,
  scheduled_starts_at DATETIME NOT NULL,
  scheduled_ends_at DATETIME NOT NULL,
  duration_minutes TINYINT UNSIGNED NOT NULL,
  status_code VARCHAR(30) NOT NULL,
  rejection_reason VARCHAR(500) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT ck_appointment_duration CHECK (duration_minutes IN (30, 60)),
  CONSTRAINT ck_appointment_interval CHECK (scheduled_ends_at = scheduled_starts_at + INTERVAL duration_minutes MINUTE),
  CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id) REFERENCES users(id),
  CONSTRAINT fk_appointment_professional FOREIGN KEY (professional_id) REFERENCES professionals(user_id),
  CONSTRAINT fk_appointment_specialty FOREIGN KEY (specialty_id) REFERENCES specialties(id),
  CONSTRAINT fk_appointment_location FOREIGN KEY (location_id) REFERENCES locations(id),
  CONSTRAINT fk_appointment_status FOREIGN KEY (status_code) REFERENCES appointment_statuses(code),
  INDEX ix_appointment_patient (patient_id, scheduled_starts_at),
  INDEX ix_appointment_agenda (professional_id, location_id, scheduled_starts_at),
  INDEX ix_appointment_admin (status_code, scheduled_starts_at)
);

CREATE TABLE reschedule_statuses (
  code VARCHAR(30) PRIMARY KEY,
  description VARCHAR(100) NOT NULL
);

CREATE TABLE reschedule_requests (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  requested_by_user_id BIGINT UNSIGNED NOT NULL,
  proposed_starts_at DATETIME NOT NULL,
  proposed_ends_at DATETIME NOT NULL,
  status_code VARCHAR(30) NOT NULL DEFAULT 'PENDING',
  decision_reason VARCHAR(500) NULL,
  decided_by_user_id BIGINT UNSIGNED NULL,
  decided_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT ck_reschedule_interval CHECK (proposed_ends_at > proposed_starts_at),
  CONSTRAINT fk_reschedule_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  CONSTRAINT fk_reschedule_requester FOREIGN KEY (requested_by_user_id) REFERENCES users(id),
  CONSTRAINT fk_reschedule_status FOREIGN KEY (status_code) REFERENCES reschedule_statuses(code),
  CONSTRAINT fk_reschedule_decider FOREIGN KEY (decided_by_user_id) REFERENCES users(id),
  INDEX ix_reschedule_inbox (status_code, created_at)
);

-- Una fila existe solo mientras el slot está reservado o retenido.
-- La unicidad de availability_slot_id impide que dos citas/solicitudes ocupen el mismo slot.
CREATE TABLE slot_reservations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  availability_slot_id BIGINT UNSIGNED NOT NULL,
  appointment_id BIGINT UNSIGNED NULL,
  reschedule_request_id BIGINT UNSIGNED NULL,
  reserved_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_reserved_slot UNIQUE (availability_slot_id),
  CONSTRAINT ck_reservation_owner CHECK (
    (appointment_id IS NOT NULL AND reschedule_request_id IS NULL)
    OR (appointment_id IS NULL AND reschedule_request_id IS NOT NULL)
  ),
  CONSTRAINT fk_reservation_slot FOREIGN KEY (availability_slot_id) REFERENCES availability_slots(id),
  CONSTRAINT fk_reservation_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  CONSTRAINT fk_reservation_reschedule FOREIGN KEY (reschedule_request_id) REFERENCES reschedule_requests(id),
  INDEX ix_reservation_appointment (appointment_id),
  INDEX ix_reservation_reschedule (reschedule_request_id)
);

CREATE TABLE appointment_status_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  status_code VARCHAR(30) NOT NULL,
  actor_user_id BIGINT UNSIGNED NULL,
  source ENUM('SYSTEM','USER','ADMIN','PROFESSIONAL') NOT NULL,
  reason VARCHAR(500) NULL,
  occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_status_history_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  CONSTRAINT fk_status_history_status FOREIGN KEY (status_code) REFERENCES appointment_statuses(code),
  CONSTRAINT fk_status_history_actor FOREIGN KEY (actor_user_id) REFERENCES users(id),
  INDEX ix_status_history_appointment (appointment_id, occurred_at)
);

CREATE TABLE refresh_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash),
  CONSTRAINT fk_refresh_token_user FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX ix_refresh_token_active (user_id, expires_at, revoked_at)
);

CREATE TABLE password_reset_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  used_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_reset_token_hash UNIQUE (token_hash),
  CONSTRAINT fk_reset_token_user FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX ix_reset_token_active (user_id, expires_at, used_at)
);

-- Catálogos fijos.
INSERT INTO roles (code, description) VALUES
  ('USER', 'Paciente ficticio'), ('PROFESSIONAL', 'Profesional ficticio'), ('ADMIN', 'Administrador');
INSERT INTO appointment_statuses (code, description, is_terminal) VALUES
  ('REQUESTED', 'Solicitud especializada pendiente', FALSE),
  ('APPROVED', 'Cita aprobada', FALSE),
  ('REJECTED', 'Solicitud rechazada', TRUE),
  ('CANCELLED', 'Cita cancelada', TRUE),
  ('COMPLETED', 'Atención completada', TRUE),
  ('NO_SHOW', 'Paciente no asistió', TRUE);
INSERT INTO reschedule_statuses (code, description) VALUES
  ('PENDING', 'Pendiente de decisión'), ('APPROVED', 'Reprogramación aprobada'),
  ('REJECTED', 'Reprogramación rechazada'), ('CANCELLED', 'Solicitud cancelada');
INSERT INTO insurance_regimes (name) VALUES ('Contributivo'), ('Subsidiado'), ('Especial');
INSERT INTO locations (code, name, address) VALUES
  ('HIC', 'Hospital Internacional de Colombia (HIC)', 'Km 7 Autopista Bucaramanga–Piedecuesta, Valle de Menzulí, Santander'),
  ('ICV', 'Fundación Cardiovascular de Colombia / Instituto Cardiovascular (ICV)', 'Calle 155A No. 23-58, Urbanización El Bosque, Floridablanca, Santander');
INSERT INTO specialties (name, appointment_kind, duration_minutes) VALUES
  ('Medicina General', 'GENERAL', 30);
