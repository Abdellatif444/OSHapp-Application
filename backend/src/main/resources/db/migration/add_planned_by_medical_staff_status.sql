-- Add PLANNED_BY_MEDICAL_STAFF to appointments status constraint
-- This allows the new medical visit planning scenario to work without database errors

ALTER TABLE appointments 
DROP CONSTRAINT IF EXISTS appointments_status_check;

ALTER TABLE appointments 
ADD CONSTRAINT appointments_status_check 
CHECK (status IN (
    'REQUESTED_EMPLOYEE',
    'PROPOSED_MEDECIN', 
    'PLANNED_BY_MEDICAL_STAFF',  -- Nouveau statut pour planification par service médical
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED',
    'OBLIGATORY'
));
