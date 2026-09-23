# Base de datos v1 — 3FN

## Archivos

- `V1__initial_schema.sql`: esquema y seed de catálogos fijos para MySQL 8.4.
- `ERD.mmd`: diagrama ER en Mermaid.

## Claves, relaciones y catálogos

Las claves sustitutas son `BIGINT` para entidades transaccionales y `SMALLINT` para catálogos pequeños. Los identificadores naturales que deben ser únicos también tienen restricciones: email y documento de usuario, código/matrícula profesional, nombre de EPS/especialidad/régimen y código de sede. Las tablas puente `user_roles`, `professional_specialties` y `professional_locations` resuelven sus relaciones N:M con PK compuestas.

`roles`, estados de cita, estados de reprogramación, regímenes y sedes son catálogos fijos precargados. EPS, planes y especialidades incluyen `is_active`; se desactivan en lugar de borrarse cuando están referenciados. `professionals` es una extensión 1:1 de `users`; el rol `PROFESSIONAL` se asigna en `user_roles` por la aplicación.

La afiliación solo apunta a `eps_plans`; el plan determina la EPS y la EPS determina el régimen. Por ello no se repiten nombres ni IDs de EPS/régimen/plan en `users` o `appointments`.

## Dependencias funcionales relevantes

| Determinante | Dependientes |
|---|---|
| `users.id` | datos personales, hash, estado |
| `(document_type, document_number)` | `users.id` |
| `eps_plans.id` | `eps_id`, nombre, estado |
| `eps.id` | `regime_id`, nombre, estado |
| `specialties.id` | nombre, tipo, duración, estado |
| `professionals.user_id` | código, matrícula, estado |
| `appointments.id` | paciente, profesional, especialidad, sede, instante, duración, estado |
| `availability_slots.id` | bloque, inicio, fin |
| `availability_slots.id` en `slot_reservations` | a lo sumo una retención activa |

## De 1FN a 3FN

**1FN.** Cada columna contiene un valor atómico. Especialidades, roles, sedes y slots no se almacenan como listas: cada asignación es una fila de una tabla puente y cada franja de 30 minutos es una fila de `availability_slots`.

**2FN.** Las tablas puente tienen como clave la pareja completa de sus FKs; por ejemplo, `is_primary` depende de `(professional_id, specialty_id)`, no únicamente de especialidad. Los atributos de entidades propias se mantienen fuera de esas relaciones.

**3FN.** Los nombres y atributos de los catálogos están en su propia tabla. La cadena `afiliación → plan → EPS → régimen` elimina dependencias transitivas del usuario. Citas y auditorías guardan códigos FK de estado, no textos libres divergentes.

## Agenda, reservas y reprogramación

Al crear un bloque, la aplicación genera sus filas de `availability_slots` de 30 minutos. Para reservar, en una sola transacción bloquea los slots candidatos con `SELECT ... FOR UPDATE`, verifica que pertenecen al profesional/sede solicitados y que son consecutivos, e inserta una fila de `slot_reservations` por slot. Una cita de 30 minutos inserta una fila; una de 60 inserta dos. `UNIQUE(availability_slot_id)` protege la doble reserva incluso ante concurrencia.

Los cambios de estado y la liberación/creación de reservas se hacen en la misma transacción. Al rechazar o cancelar se eliminan las reservas vivas. Al solicitar una reprogramación se crean reservas asociadas a `reschedule_requests`, mientras las reservas de la cita original siguen asociadas a `appointments`. Al aprobar, se eliminan las originales, se transfieren las nuevas a la cita y se actualiza su horario; al rechazar, solo se eliminan las reservas provisionales. De este modo la cita original no se pierde mientras la decisión está pendiente.

`appointments.duration_minutes`, hora de inicio y hora de fin son snapshots operativos: preservan exactamente lo que se reservó aunque luego cambie la duración configurable de una especialidad. En cambio, profesional, sede, especialidad, paciente, plan y estados se guardan por FK. `appointment_status_history` es solo de inserción desde el flujo de dominio y guarda actor, fuente, motivo e instante.

Los índices `ix_appointment_agenda`, `ix_slot_time`, `ix_block_calendar`, `ix_appointment_patient`, `ix_appointment_admin` y los de bandeja/historial cubren agenda, disponibilidad, mis citas y colas administrativas. La aplicación debe validar además: membresía profesional-sede/especialidad, bloque futuro y no solapamiento de bloques del mismo profesional; esos controles abarcan varias filas y se realizan transaccionalmente.
