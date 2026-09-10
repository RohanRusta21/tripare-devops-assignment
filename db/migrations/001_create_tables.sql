-- 001: core schema
-- gen_random_uuid() is built in since PostgreSQL 13, no extension needed.

BEGIN;

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID          NOT NULL,
    hotel_id      VARCHAR(100)  NOT NULL,
    city          VARCHAR(100)  NOT NULL,
    checkin_date  DATE          NOT NULL,
    checkout_date DATE          NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    status        VARCHAR(50)   NOT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT now(),

    CONSTRAINT hotel_bookings_dates_chk  CHECK (checkout_date > checkin_date),
    CONSTRAINT hotel_bookings_amount_chk CHECK (amount >= 0),
    CONSTRAINT hotel_bookings_status_chk CHECK (
        status IN ('pending', 'confirmed', 'checked_in', 'completed', 'cancelled', 'refunded')
    )
);

CREATE TABLE IF NOT EXISTS booking_events (
    id          BIGSERIAL     PRIMARY KEY,
    booking_id  UUID          NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type  VARCHAR(100)  NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMP     NOT NULL DEFAULT now()
);

COMMENT ON TABLE hotel_bookings IS 'One row per hotel booking made by an organisation.';
COMMENT ON TABLE booking_events IS 'Append-only audit trail of state changes for a booking.';

COMMIT;
