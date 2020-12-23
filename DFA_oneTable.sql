-- SEMINAR: SQL is a Programming Language
-- TOPIC: query-pattern recognition with finite automaton
-- Bei der Analyse von Zeichenketten kann es interessant sein, ob diese einem bestimmten Muster entsprechen
-- (etwa: befindet sich das Wort "Fotografie" in einer anderen Variante, "Photographie", "Photografie" oder
-- "Fotographie" in einem Text?). Eine solche Mustererkennung kann mittels endlicher Automaten ermittelt
-- werden, welche sich in SQL auf unterschiedliche Arten darstellen lassen.

-- ROUGH APPROACH:
-- formulate regular expressions with deterministic finite automaton(dfa_t)
-- how can we represent a graph in SQL https://inviqa.com/blog/storing-graphs-database-sql-meets-social-network
-- how to split strings in SQL  https://www.postgresql.org/docs/13/functions-string.html


-- dfa_ts consists of 5-Tuple: (Q, \Sigma, \delta, q_0, F)  <--- typical variable specification
-- dfa_ts consists of 5-Tuple, (S, A, T, s_0, F)
--      S = finite set of dfa_t
--      A = input Alphabet(set of symbols)
--      T = Transition function from a state "s_x" to another State "s_y" given A
--      s_0 = start State of a word, s_0 is element of S
--      F = set of Finite dfa_t which is a subset of S

DROP TABLE dfa_t; -- Tuple S
-- Representing a dfa_t as a graph in 2 tables: (states = nodes) + (transitions = edges)
CREATE TABLE dfa_t
(   state_id     INTEGER,               -- node identifier
    letter      CHAR(1),                -- letter from alphabet
    successor   INTEGER,                -- successor
    end_state    BOOLEAN                -- is state_id an endnode?
);

-- Inserting the values for the Deterministic Finite Automata (dfa_t). Single-Entry, Single-Exit(SESE)-graph
-- where the connections to the entry(0) and exit(42) nodes indicates start(entry) and end(exit) nodes respectively.
-- Tuple-S: {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 42}; 12 dfa_t + the two entry and exit dfa_t
-- Tuple-A: {F, o, t, o, P, h, g, r, a, f, p, h}; Alphabet with 12 letters.
INSERT INTO
    dfa_t(state_id, letter, successor, end_state)
VALUES
-- reference node to declare starting dfa_t, every node which is connected to this node is a starting state
    (0, '', 1, FALSE), -- TODO: !TEST NECESSARY! if 'NULL' as value for start dfa_t is a problem during the process
    (0, '', 5, FALSE),
    (1,'F', 2, FALSE), -- start state
    (2,'o', 3, FALSE),
    (3,'t', 4, FALSE),
    (4,'o', NULL, TRUE), -- end state
    (4,'o', 7, FALSE),
    (5,'P', 6, FALSE), -- start state
    (6,'h', 2, FALSE),
    --(6,'h', NULL, TRUE), -- end state
    (7,'g', 8, FALSE),
    (8,'r', 9, FALSE),
    (9,'a', 10, FALSE),
    (9,'a', 11, FALSE),
    (10,'f', NULL, TRUE),
    (11,'p', 12, FALSE)
   ,(12,'h', NULL, TRUE)
    --(42, NULL, NULL, FALSE) -- TODO: !TEST NECESSARY! if 'NULL' as value for end dfa_t is a problem during the process
RETURNING *;

-- Inserting the connections (edges) of the dfa_t which encodes 'T', 's_0' and 'F'
-- Tuple-T: {(0, 1), (0, 5), (1, 2), (2, 3), (3, 4), (4, 42), (4, 7), (5, 6), (6, 2), (6, 42), (7, 8), (8, 9), (9, 10),
-- (10, 42), (9, 11), (11, 6)}
-- Tuple-s_0: {1, 5}; dfa_t which predecessor is the node with state_id = 0 are start dfa_t(nodes)
-- Tuple-F: {4, 6, 10}; dfa_t which successor is the node with state_id = 42 are end dfa_t(nodes)
-- End

-- Tuple-s_o: list all start dfa_t(nodes)
SELECT *
    FROM dfa_t
WHERE state_id = 0;
-- Tuple-F: list all end dfa_t(nodes)
SELECT *
    FROM dfa_t
WHERE end_state = TRUE;
--WHERE successor is null;

-- query to get ALL valid 'words', their 'path_string' and 'distance' within the dfa_t.
WITH RECURSIVE query(id, l , suc, end_s, path_string, distance, word) AS (
  SELECT
         state_id as id,
         letter as l,
         successor as suc,                                   -- sb = the successor
         end_state as end_s,
         state_id ||'' AS path_string,    -- concatinating the first state with its successor
         0 AS distance
        ,''|| letter AS  word
  FROM
       dfa_t
  --WHERE letter IN ('F','P') -- constraints that a start state(node) has to have an edge on node 0
  WHERE state_id =0 -- constraints that a start state(node) has to have an edge on node 0
  UNION
        SELECT
               q.id,
               d.letter,
               d.successor,
               d.end_state AS end_s,
               q.path_string || '-' || d.state_id AS path_string,
               q.distance + 1 AS distance
            ,  q.word || d.letter AS word
        FROM dfa_t as d
            JOIN query AS q
                --ON q.id = d.successor -- recursively checking what the next successor of q.b is, given q.b as predecessor.
                ON d.state_id = q.suc
    --WHERE "left"(q.word, 1) IN ('F','P')
    --WHERE q.end_s != TRUE AND q.id = 0
    --WHERE right(q.word, 1) = 't'
    --WHERE d.end_state = true
    --WHERE q.id = 0
    --WHERE "left"(q.word, 1) IN ('P')
) SELECT word, path_string, distance FROM query
WHERE end_s = true-- and distance > 0
ORDER BY distance;


------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------EXPERIMENTAL--------------------------------------------------------
------------------------------------------------------QUERIES-----------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- listing the directly connected nodes
SELECT *
  FROM dfa_t
WHERE successor is Null;
-- all
SELECT * FROM dfa_t WHERE state_id IN (
  SELECT s_a FROM transitions WHERE s_b = 42
  UNION ALL
  SELECT s_b FROM transitions WHERE s_a = 0
);

WITH RECURSIVE query(a, b, path_string, distance) AS (
  SELECT
         t.s_a,
         t.s_b,
         t.s_a ||''|| t.s_b AS path_string,
         1 AS distance
      ,  s.letter || '' AS  word
  FROM
       dfa_t AS s, transitions AS t
  -- declare initial state -> 0 where the start dfa_t(1 and 5) are connected to
  WHERE state_id IN (
  SELECT s_a FROM transitions WHERE s_b = 42
  UNION ALL
  SELECT s_b FROM transitions WHERE s_a = 0
)
  UNION
        SELECT
               q.a,
               t.s_b,
               q.path_string || '' || t.s_b AS path_string,
               q.distance + 1 AS distance
            ,  q.word || s.letter AS word
        FROM dfa_t AS s, transitions AS t
            JOIN query AS q
                ON t.s_a = q.b
        WHERE ("left"(q.path_string, 1) = '0' AND
                        "right"(q.path_string, 2) = '42')
) SELECT * FROM query
--WHERE right(query.path_string, 1) = '42'-- constraining output on finite state 4 (letter = "o").
--WHERE query.word = 'Foto'--("left"('Foto', 1)  OR  query.word = 'Photo')
ORDER BY distance;

WITH RECURSIVE query(a, b, path_string, distance, word) AS (
  SELECT
         s_a,
         s_b,
         s_a ||''|| s_b AS path_string,
         1 AS distance
        ,letter || '' AS  word
  FROM
       dfa_t AS s, transitions AS t
  --WHERE s_a = 0 -- constraints that a start state(node) has to have an edge on node 0
  UNION
        SELECT
               q.a,
               t.s_b,
               q.path_string || '' || t.s_b AS path_string,
               q.distance + 1 AS distance
            ,  q.word || s.letter AS word
        FROM dfa_t AS s, transitions AS t
            JOIN query AS q
                ON t.s_a = q.b
) SELECT * FROM query
WHERE query.b = 4 AND (query.word = 'Foto' OR  query.word = 'Photo')-- checking if "Foto" and "Photo" is generated by the recursive query
-- WHERE query.word = 'Foto' OR query.word = 'Photo'
ORDER BY distance;

WITH RECURSIVE transitive_closure(actual_string) AS
( SELECT letter ||'' AS actual_string
  FROM dfa_t

  UNION

  SELECT tc.actual_string || n.letter AS actual_string
  FROM dfa_t AS n
    JOIN transitive_closure AS tc
      ON n.letter = tc.actual_string
  WHERE tc.actual_string NOT LIKE '%' || n.letter || '.%'
)
SELECT * FROM transitive_closure;


-- Tuple-F: list all end/finite acceptable dfa_t(nodes)
SELECT *
FROM   dfa_t s
WHERE  NOT EXISTS (
   SELECT  -- SELECT list mostly irrelevant; can just be empty in Postgres
   FROM   transitions t
   WHERE  t.s_a = s.state_id
   );


WITH RECURSIVE t(x) AS (
  (SELECT 1 AS x

  UNION

  SELECT 1 AS x)

  UNION ALL

  SELECT x + 1
  FROM   t
  WHERE  x < 10

) SELECT * FROM t;