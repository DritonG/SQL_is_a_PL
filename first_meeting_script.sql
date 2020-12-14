-- Foto
-- Photo

--   F    o    t    o      g
-- 0 -> 1 -> 2 -> 3 -> (4) -> 8 ... -> (42)
--      ^
--      | h
--      5
--      ^
--      | P
--      6
--      ^
--      |
--      7

-- CREATE TABLE dfa
-- ( stateID int
-- , pred    int
-- , read    char
-- )



WITH RECURSIVE t(x) AS (
  (SELECT 1 AS x

  UNION

  SELECT 1 AS x)

  UNION ALL

  SELECT x + 1
  FROM   t
  WHERE  x < 10

) SELECT * FROM t;