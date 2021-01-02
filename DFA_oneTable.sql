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
    --(0, '', 1, FALSE), -- TODO: !TEST NECESSARY! if 'NULL' as value for start dfa_t is a problem during the process
    --(0, '', 5, FALSE),
    (0,'F', 1, FALSE), -- start state
    (1,'o', 2, FALSE),
    (2,'t', 3, FALSE),
    (3,'o', 4, TRUE), -- end state
    --(3,'o', 7, FALSE),
    (0,'P', 5, FALSE), -- start state
    (5,'h', 6, FALSE),
    (6,'o', 2, FALSE), -- end state
    (4,'g', 7, FALSE),    (7,'r', 8, FALSE),
    (8,'a', 9, FALSE),
    --(8,'a', 11, FALSE),
    (9,'f', 10, TRUE),
    (9,'p', 11, FALSE)
   ,(11,'h', 12, TRUE)
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

-- query to get ALL valid 'words', their 'path_string' and 'distance' within the dfa_t. "TRANSITIVE-HÜLLE"
WITH RECURSIVE query(id, l , suc, end_s, path_string, distance, word) AS (
  SELECT
         state_id as id,
         letter as l,
         successor as suc,                                   -- sb = the successor
         end_state as end_s,
         state_id ||'-'||successor AS path_string,    -- concatinating the first state with its successor
         1 AS distance
        ,letter||''  AS  word
  FROM
       dfa_t
  WHERE state_id = 0 -- constraints that a start state(node) has to have an edge on node 0
  UNION
        SELECT
               d.state_id AS id,
               d.letter AS l,
               d.successor as suc,
               d.end_state AS end_s,
               q.path_string || '-' || d.successor AS path_string,
               q.distance + 1 AS distance
            ,  q.word || d.letter AS word
        FROM dfa_t as d
            JOIN query AS q
                --ON q.id = d.successor -- recursively checking what the next successor of q.b is, given q.b as predecessor.
                ON d.state_id = q.suc -- WHERE ("left"(word_input, 1) = "left"(word, 1))-- OR ("right"(word_input, 1) = "right"(word, 1))
    --WHERE left(q.word, 1) IN ('F','P')
    --WHERE right(q.word, 1) IN ('o', 'f', 'h') AND q.end_s = true
    --WHERE d.end_state = TRUE AND d.state_id = 0
    --WHERE d.end_state = true
    --WHERE q.id = 0
    --WHERE "left"(q.word_input, length(q.word_input)) in ('Foto')
) SELECT word, path_string, distance FROM query
--WHERE id = 0 and end_s = true
WHERE end_s = true
ORDER BY distance;

-- implementing the recursive query into a function with input parameter.
-- the parameter "input" equals the string which patterns we are watching for in our table
drop function if exists check_text_pattern(input char);
create or replace function check_text_pattern(input char) RETURNS TABLE(first char, second char, path char, dist int) AS $$
    WITH RECURSIVE query(id, l , suc, end_s, path_string, distance, word) AS (
        SELECT
               state_id as id,
               letter as l,
               successor as suc,                                   -- sb = the successor
               end_state as end_s,
               state_id ||'-'||successor AS path_string,    -- concatinating the first state with its successor
               1 AS distance
               ,letter||''  AS  word
        FROM
             dfa_t
        WHERE state_id = 0 -- constraints that a start state(node) has to have an edge on node 0
        --WHERE letter = "left"(input,1) -- constraints that a start state(node) has to have an edge on node 0
        UNION
        SELECT
               d.state_id AS id,
               d.letter AS l,
               d.successor as suc,
               d.end_state AS end_s,
               q.path_string || '-' || d.successor AS path_string,
               q.distance + 1 AS distance
            ,  q.word || d.letter AS word
        FROM dfa_t as d
            JOIN query AS q
                --ON q.id = d.successor -- recursively checking what the next successor of q.b is, given q.b as predecessor.
                ON d.state_id = q.suc WHERE (right(left(input, q.distance),1) = q.l)-- OR ("right"(word_input, 1) = "right"(word, 1))
        ) SELECT input, word, path_string, distance FROM query
    WHERE end_s = true
    ORDER BY distance;
$$ LANGUAGE SQL;
-- function with input pattern to be checked
SELECT check_text_pattern('Photograph');



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
  SELECT s_a FROM transitions WHERE s_b is null
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

------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------EXPERIMENTAL--------------------------------------------------------
-----------------------------------------------------FUNCTIONS----------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

drop function if exists check_text_pattern(input char);
create or replace function check_text_pattern(input char) RETURNS TABLE(first char, second char, path char, dist int) AS $$
    WITH RECURSIVE query(id, l , suc, end_s, path_string, distance, word) AS (
        SELECT
               state_id as id,
               letter as l,
               successor as suc,                                   -- sb = the successor
               end_state as end_s,
               state_id ||'-'||successor AS path_string,    -- concatinating the first state with its successor
               1 AS distance
               ,letter||''  AS  word
        FROM
             dfa_t
        WHERE state_id = 0 -- constraints that a start state(node) has to have an edge on node 0
        --WHERE letter = "left"(input,1) -- constraints that a start state(node) has to have an edge on node 0
        UNION
        SELECT
               d.state_id AS id,
               d.letter AS l,
               d.successor as suc,
               d.end_state AS end_s,
               q.path_string || '-' || d.successor AS path_string,
               q.distance + 1 AS distance
            ,  q.word || d.letter AS word
        FROM dfa_t as d
            JOIN query AS q
                --ON q.id = d.successor -- recursively checking what the next successor of q.b is, given q.b as predecessor.
                ON d.state_id = q.suc WHERE (right(left(input, q.distance),1) = q.l)-- OR ("right"(word_input, 1) = "right"(word, 1))
        ) SELECT input, word, path_string, distance FROM query
    WHERE end_s = true
    ORDER BY distance;
$$ LANGUAGE SQL;
-- function with input pattern to be checked
SELECT check_text_pattern('Photograph');