-- The query from the assessment (Part 5). Run with EXPLAIN (ANALYZE, BUFFERS)
-- to see the index-only scan on idx_hotel_bookings_city_created_at.
EXPLAIN (ANALYZE, BUFFERS)
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
