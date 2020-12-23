-- SEMINAR: SQL is a Programming Language
-- TOPIC: query-pattern recognition with finite automaton
-- Bei der Analyse von Zeichenketten kann es interessant sein, ob diese einem bestimmten Muster entsprechen
-- (etwa: befindet sich das Wort "Fotografie" in einer anderen Variante, "Photographie", "Photografie" oder
-- "Fotographie" in einem Text?). Eine solche Mustererkennung kann mittels endlicher Automaten ermittelt
-- werden, welche sich in SQL auf unterschiedliche Arten darstellen lassen.

-- ROUGH APPROACH:
-- formulate regular expressions with deterministic finite automaton(DFA)
-- how can we represent a graph in SQL https://inviqa.com/blog/storing-graphs-database-sql-meets-social-network
-- how to split strings in SQL  https://www.postgresql.org/docs/13/functions-string.html


-- DFAs consists of 5-Tuple: (Q, \Sigma, \delta, q_0, F)  <--- typical variable specification
-- DFAs consists of 5-Tuple, (S, A, T, s_0, F)
--      S = finite set of states
--      A = input Alphabet(set of symbols)
--      T = Transition function from a state "s_x" to another State "s_y" given A
--      s_0 = start State of a word, s_0 is element of S
--      F = set of Finite states which is a subset of S

DROP TABLE  states; -- Tuple S
DROP TABLE  transitions; -- Tuple T

-- Representing a DFA as a graph in 2 tables: states = nodes + transitions = edges
CREATE TABLE states
(   stateID INTEGER PRIMARY KEY,                                                                -- node identifier
    letter  CHAR(1)                                                                             -- letter from alphabet
);

CREATE TABLE transitions
(   s_a INTEGER NOT NULL REFERENCES states(stateID) ON UPDATE CASCADE ON DELETE CASCADE,   -- the "from" state (s_a)
    s_b INTEGER NOT NULL REFERENCES states(stateID) ON UPDATE CASCADE ON DELETE CASCADE,   -- the "to" state (s_b)
    PRIMARY KEY (s_a, s_b)
);
CREATE INDEX s_a_idx ON transitions (s_a);
CREATE INDEX s_b_idx ON transitions (s_b);

-- Inserting the values for the Deterministic Finite Automata (DFA). We use a Single-Entry, Single-Exit(SESE)-graph
-- where the connections to the entry and exit nodes indicates start(entry) and end(exit) nodes respectively.
-- Tuple-S: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}; 11 States + the two entry and exit states
-- Tuple-A: {F, o, t, o, P, h, g, r, a, f, p}; Alphabet with 11 letters.
INSERT INTO
    states(stateID, letter)
VALUES
-- reference node to declare starting states, every node which is connected to this node is a starting state
    (0, NULL), -- TODO: !TEST NECESSARY! if 'NULL' as value for start states is a problem during the process
    (1,'F'), -- start state
    (2,'o'),
    (3,'t'),
    (4,'o'), -- end state
    (5,'P'), -- start state
    (6,'h'),
    (7,'g'),
    (8,'r'),
    (9,'a'),
    (10,'f'),
    (11,'p'),
    (12,'h'),
    (13,'i'),
    (14,'e')
    ,(42, NULL) -- TODO: !TEST NECESSARY! if 'NULL' as value for end states is a problem during the process
RETURNING *;

-- Inserting the connections (edges) of the DFA which encodes 'T', 's_0' and 'F'
-- Tuple-T: {(0, 1), (0, 5), (1, 2), (2, 3), (3, 4), (4, 42), (4, 7), (5, 6), (6, 2), (6, 42), (7, 8), (8, 9), (9, 10),
-- (10, 42), (9, 11), (11, 6)}
-- Tuple-s_0: {1, 5}; states which predecessor is the node with stateID = 0 are start states(nodes)
-- Tuple-F: {4, 6, 10}; states which successor is the node with stateID = 42 are end states(nodes)
-- End
INSERT INTO
    transitions(s_a, s_b)
VALUES
    (0, 1), -- edge to start node with stateID 1 and letter "F" --> predecessor 0
    (0, 5), -- edge to start node with stateID 5 and letter "P" --> predecessor 0
    (1, 2),
    (2, 3),
    (3, 4), -- edge to end node with stateID 4 and letter "o"
    (4, 42), --´edge which indicates 4 to be a end state(node) --> successor 42
    (4, 7), --´edge which indicates 4 to be a end state(node)
    (5, 6),
    (6, 2),
    --(6, 42), -- (6,'h') = endstate --> successor = 42
    (7, 8),
    (8, 9),
    (9, 10),
    (9, 11),
    (10, 42), -- (10, 'f') = endstate --> successor = 42
    (10, 13),
    (11, 12),
    (12, 42),
    (12, 13),
    (13, 14),
    (14, 42)
RETURNING *;


-- Tuple-s_o: list all start states(nodes)
SELECT *
    FROM  states s
    LEFT JOIN transitions t on s.stateID = t.s_b
WHERE  t.s_a = 0;
-- Tuple-F: list all end states(nodes)
SELECT *
    FROM  states s
    LEFT JOIN transitions t on s.stateID = t.s_a
WHERE  t.s_b = 42;

-- query to get ALL valid 'words', their 'path_string' and 'distance' within the DFA.
WITH RECURSIVE query(b, path_string, distance, word) AS (
  SELECT
         s_b,                               -- sb = the successor
         s_a ||'-'|| s_b AS path_string,    -- concatinating the first state with its successor
         0 AS distance
        ,''||'' AS  word
  FROM
       states, transitions
  WHERE s_a = 0 -- constraints that a start state(node) has to have an edge on node 0
  UNION
        SELECT
               t.s_b,
               q.path_string || '-' || t.s_b AS path_string,
               q.distance + 1 AS distance
            ,  q.word || s.letter AS word
        FROM states AS s, transitions AS t
            JOIN query AS q
                ON t.s_a = q.b -- recursively checking what the next successor of q.b is, given q.b as predecessor.
        WHERE q.b = s.stateID
) SELECT word, path_string, distance FROM query
WHERE query.b = 42  -- constraining the end of a word to be at 42
ORDER BY distance;

-- query to get ALL valid 'words', their 'path_string' and 'distance' within the DFA.
WITH RECURSIVE query(b, path_string, distance, word) AS (
  SELECT
         s_b,                               -- sb = the successor
         s_a ||'-'|| s_b AS path_string,    -- concatinating the first state with its successor
         0 AS distance
        ,''||'' AS  word
  FROM
       states, transitions
  WHERE s_a = 0 -- constraints that a start state(node) has to have an edge on node 0
  UNION
        SELECT
               t.s_b,
               q.path_string || '-' || t.s_b AS path_string,
               q.distance + 1 AS distance
            ,  q.word || s.letter AS word
        FROM states AS s, transitions AS t
            JOIN query AS q
                ON t.s_a = q.b -- recursively checking what the next successor of q.b is, given q.b as predecessor.
        WHERE q.b = s.stateID
        --WHERE distance < 5
) SELECT word, path_string, distance FROM query
WHERE query.b = 42  -- constraining the end of a word to be at 42
ORDER BY distance;


------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------EXPERIMENTAL--------------------------------------------------------
------------------------------------------------------QUERIES-----------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- listing the directly connected nodes
SELECT *
  FROM states s
  LEFT JOIN transitions t ON s.stateID = t.s_b
 WHERE t.s_a = 0;
-- all
SELECT * FROM states WHERE stateID IN (
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
       states AS s, transitions AS t
  -- declare initial state -> 0 where the start states(1 and 5) are connected to
  WHERE stateID IN (
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
        FROM states AS s, transitions AS t
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
       states AS s, transitions AS t
  --WHERE s_a = 0 -- constraints that a start state(node) has to have an edge on node 0
  UNION
        SELECT
               q.a,
               t.s_b,
               q.path_string || '' || t.s_b AS path_string,
               q.distance + 1 AS distance
            ,  q.word || s.letter AS word
        FROM states AS s, transitions AS t
            JOIN query AS q
                ON t.s_a = q.b
) SELECT * FROM query
WHERE query.b = 4 AND (query.word = 'Foto' OR  query.word = 'Photo')-- checking if "Foto" and "Photo" is generated by the recursive query
-- WHERE query.word = 'Foto' OR query.word = 'Photo'
ORDER BY distance;

WITH RECURSIVE transitive_closure(actual_string) AS
( SELECT letter ||'' AS actual_string
  FROM states

  UNION

  SELECT tc.actual_string || n.letter AS actual_string
  FROM states AS n
    JOIN transitive_closure AS tc
      ON n.letter = tc.actual_string
  WHERE tc.actual_string NOT LIKE '%' || n.letter || '.%'
)
SELECT * FROM transitive_closure;


-- Tuple-F: list all end/finite acceptable states(nodes)
SELECT *
FROM   states s
WHERE  NOT EXISTS (
   SELECT  -- SELECT list mostly irrelevant; can just be empty in Postgres
   FROM   transitions t
   WHERE  t.s_a = s.stateID
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