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

-- Inserting the values for the deterministic finite automata
-- Tuple-S: {1 , 2, 3, 4, 5, 6}; 6 States + the NULL states which indicates a starting node(state)
-- Tuple-A: {F, o, t, o, P, h}; Alphabet with 6 letters.
INSERT INTO
    states(stateID, letter)
VALUES
-- reference node to declare starting states, every node which is connected to this node is a starting state
    (0, NULL),
    (1,'F'), -- start state
    (2,'o'),
    (3,'t'),
    (4,'o'), -- end state
    (5,'P'), -- start state
    (6,'h')
RETURNING *;

-- Inserting the values for the Deterministic Finite Automaton(DFA)
-- Tuple-S: {1 , 2, 3, 4, 5, 6}; 6 States + the NULL states which indicates a starting node(state)
-- Tuple-A: {F, o, t, o, P, h}; Alphabet with 6 letters.
INSERT INTO
    transitions(s_a, s_b)
VALUES
    (0, 1), -- edge to start node with stateID 1 and letter "F"
    (0, 5), -- edge to start node with stateID 5 and letter "P"
    (1, 2),
    (2, 3),
    (3, 4), -- edge to end node with stateID 4 and letter "o"
    (5, 6),
    (6, 2)
RETURNING *;


-- Tuple-s_o: list all start states(nodes)
SELECT *
    FROM  states s
    LEFT JOIN transitions t on s.stateID = t.s_b
WHERE  t.s_a = 0;

-- Tuple-F: list all end/finite acceptable states(nodes)
SELECT *
FROM   states s
WHERE  NOT EXISTS (
   SELECT  -- SELECT list mostly irrelevant; can just be empty in Postgres
   FROM   transitions t
   WHERE  t.s_a = s.stateID
   );




------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------EXPERIMENTAL--------------------------------------------------------
------------------------------------------------------QUERIES-----------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

-- listing the directly connected nodes
SELECT *
  FROM states s
  LEFT JOIN transitions t ON s.stateID = t.s_b
 WHERE t.s_a = 0;

SELECT * FROM states WHERE stateID IN (
  SELECT s_a FROM transitions WHERE s_b = 1
  UNION ALL
  SELECT s_b FROM transitions WHERE s_a = 0
);

WITH RECURSIVE query(a, b, path_string, distance) AS (
  SELECT
         s_a,
         s_b,
         s_a ||''|| s_b AS path_string,
         1 AS distance
 --      ,  letter || '' AS  word
  FROM
       states AS s, transitions AS t
  WHERE s_a = 0
  UNION
        SELECT
               q.a,
               t.s_b,
               q.path_string || '' || t.s_b AS path_string,
               q.distance + 1 AS distance
--             ,  q.word || s.letter AS word
        FROM states AS s, transitions AS t
            JOIN query AS q
                ON t.s_a = q.b
) SELECT * FROM query
WHERE right(query.path_string, 1) = '4' -- abfrage wenn der pathstring mit dem finite state 4 endet
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
  WHERE s_a = 0 -- constraints that a start state(node) has to have an edge on node 0
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
WHERE query.b = 4 AND (query.word = 'Foto' OR  query.word = 'Photo')-- abfrage wenn der pathstring mit dem finite state 4 endet
ORDER BY distance;


WITH RECURSIVE t(x) AS (
  SELECT 1 AS x

  UNION ALL

  SELECT x + 1
  FROM   t
  WHERE  x < 10

) SELECT * FROM t;


-- query for all words ending with "o"
WITH RECURSIVE transitive_closure(a, b, distance, path_string, word) AS
( SELECT s_a, s_b, 1 AS distance,
    s_a || '->' || s_b || '.' AS path_string,
    letter AS word
  FROM  states, transitions

  UNION

  SELECT tc.a, t.s_b, tc.distance + 1,
  tc.path_string || t.s_b || '->' AS path_string,
  tc.word || s.letter AS word
  FROM states AS s, transitions AS t
    JOIN transitive_closure AS tc
      ON t.s_a = tc.b
  WHERE  NOT EXISTS (
   SELECT  -- SELECT list mostly irrelevant; can just be empty in Postgres
   FROM   transitions t
   WHERE  t.s_a = s.stateID
   )
)
SELECT * FROM transitive_closure
ORDER BY a, b, distance;

WITH RECURSIVE transitive_closure(actual_string) AS
( SELECT letter AS actual_string
  FROM states

  UNION

  SELECT tc.actual_string || n.letter AS actual_string
  FROM states AS n
    JOIN transitive_closure AS tc
      ON n.letter = tc.actual_string
  WHERE tc.actual_string NOT LIKE '%' || n.letter || '.%'
)
SELECT * FROM transitive_closure;
