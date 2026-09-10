-- Seed data: 300 bookings across 8 cities, 6 organisations and 6 statuses,
-- plus an event trail for roughly 70% of bookings.
-- setseed() makes the "random" data reproducible between runs.

BEGIN;

SELECT setseed(0.42);

-- Fixed org ids so they are easy to reference in ad-hoc queries.
CREATE TEMP TABLE seed_orgs (id UUID) ON COMMIT DROP;
INSERT INTO seed_orgs VALUES
    ('11111111-1111-1111-1111-111111111111'),
    ('22222222-2222-2222-2222-222222222222'),
    ('33333333-3333-3333-3333-333333333333'),
    ('44444444-4444-4444-4444-444444444444'),
    ('55555555-5555-5555-5555-555555555555'),
    ('66666666-6666-6666-6666-666666666666');

CREATE TEMP TABLE seed_cities (name TEXT, weight INT) ON COMMIT DROP;
INSERT INTO seed_cities VALUES
    ('delhi', 4), ('mumbai', 3), ('bengaluru', 3), ('hyderabad', 2),
    ('chennai', 2), ('pune', 2), ('kolkata', 1), ('jaipur', 1);

CREATE TEMP TABLE seed_statuses (name TEXT, weight INT) ON COMMIT DROP;
INSERT INTO seed_statuses VALUES
    ('pending', 2), ('confirmed', 5), ('checked_in', 2),
    ('completed', 6), ('cancelled', 2), ('refunded', 1);

-- Expand weighted lists so a random pick respects the weights.
CREATE TEMP TABLE seed_city_pool AS
    SELECT name FROM seed_cities, generate_series(1, weight);
CREATE TEMP TABLE seed_status_pool AS
    SELECT name FROM seed_statuses, generate_series(1, weight);

WITH base AS (
    -- random() is volatile, so it is re-evaluated for every generated row.
    -- created_at spreads over the last 120 days, so ~25% fall in the 30 day window.
    SELECT s,
           now() - (random() * INTERVAL '120 days') AS created
    FROM generate_series(1, 300) AS s
),
dated AS (
    SELECT s,
           created,
           (created + (random() * INTERVAL '45 days'))::DATE AS checkin
    FROM base
)
INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    gen_random_uuid(),
    -- "+ s * 0" correlates each subquery with the outer row so it is re-run per row
    (SELECT id   FROM seed_orgs        ORDER BY random() + s * 0 LIMIT 1),
    'HTL-' || lpad((1 + floor(random() * 60))::TEXT, 3, '0'),
    (SELECT name FROM seed_city_pool   ORDER BY random() + s * 0 LIMIT 1),
    checkin,
    checkin + (1 + floor(random() * 6))::INT,
    round((1500 + random() * 18500)::NUMERIC, 2),
    (SELECT name FROM seed_status_pool ORDER BY random() + s * 0 LIMIT 1),
    created
FROM dated;

-- Events: every booking gets 'created'; later states get their transitions.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT b.id,
       'booking.created',
       jsonb_build_object('source', 'seed', 'amount', b.amount, 'city', b.city),
       b.created_at
FROM hotel_bookings b
WHERE random() < 0.7;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT b.id,
       'booking.confirmed',
       jsonb_build_object('payment_ref', 'PAY-' || substr(md5(b.id::TEXT), 1, 10)),
       b.created_at + INTERVAL '10 minutes'
FROM hotel_bookings b
JOIN booking_events e ON e.booking_id = b.id AND e.event_type = 'booking.created'
WHERE b.status IN ('confirmed', 'checked_in', 'completed', 'cancelled', 'refunded');

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT b.id,
       CASE b.status
           WHEN 'checked_in' THEN 'booking.checked_in'
           WHEN 'completed'  THEN 'booking.completed'
           WHEN 'cancelled'  THEN 'booking.cancelled'
           WHEN 'refunded'   THEN 'booking.refunded'
       END,
       CASE b.status
           WHEN 'cancelled' THEN jsonb_build_object('reason', 'customer_request')
           WHEN 'refunded'  THEN jsonb_build_object('refund_amount', b.amount)
           ELSE '{}'::JSONB
       END,
       b.created_at + INTERVAL '1 day'
FROM hotel_bookings b
JOIN booking_events e ON e.booking_id = b.id AND e.event_type = 'booking.confirmed'
WHERE b.status IN ('checked_in', 'completed', 'cancelled', 'refunded');

COMMIT;

-- VACUUM sets the visibility map (enables index-only scans) and refreshes planner stats.
VACUUM ANALYZE hotel_bookings;
VACUUM ANALYZE booking_events;
