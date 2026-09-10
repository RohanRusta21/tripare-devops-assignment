-- 002: indexes
-- See README "Query optimisation" for the reasoning.

BEGIN;

-- Target query:
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Column order: equality predicate (city) first, range predicate (created_at)
-- second, so the planner can seek straight to the delhi block and range-scan
-- the recent rows. INCLUDE adds the projected/aggregated columns as non-key
-- payload so the query is satisfied by an index-only scan - no heap fetches.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at DESC)
    INCLUDE (org_id, status, amount);

-- Supports "events for a booking" lookups and the FK check on delete.
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id_created_at
    ON booking_events (booking_id, created_at);

-- Common secondary access path: an org listing its own bookings by state.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_org_id_status
    ON hotel_bookings (org_id, status);

COMMIT;
