-- SEMINAR: SQL is a Programming Language
-- TOPIC: Textmuster-Erkennung mittels endlicher Automaten
-- Bei der Analyse von Zeichenketten kann es interessant sein, ob diese einem bestimmten Muster entsprechen
-- (etwa: befindet sich das Wort "Fotografie" in einer anderen Variante, "Photographie", "Photografie" oder
-- "Fotographie" in einem Text?). Eine solche Mustererkennung kann mittels endlicher Automaten ermittelt
-- werden, welche sich in SQL auf unterschiedliche Arten darstellen lassen.

-- ROUGH APPROACH:
-- formulate regular expressions with a deterministic finite automata(DFA)
-- how can we represent a graph in SQL https://inviqa.com/blog/storing-graphs-database-sql-meets-social-network
-- how to split strings in SQL  https://www.postgresql.org/docs/13/functions-string.html

DROP TABLE  dfa_nodes;
DROP TABLE  dfa_edges;

-- create the nodes table where the nodes represent a state of the automata(dfa)
-- where 'stateID' is the identifier for the individual an state
-- and 'letter' includes the value at this state, a-z, A-Z
CREATE TABLE dfa_nodes
(   stateID INTEGER PRIMARY KEY,                                                                -- node identifier
    letter  CHAR(1)                                                                             -- letter from alphabet
);
-- edges table, declare transition possibilities between states(nodes)
-- every single row represents an edge between the nodes.
-- 'stateID's are coded in dfa_a and dfa_b
CREATE TABLE dfa_edges
(   dfa_a INTEGER NOT NULL REFERENCES dfa_nodes(stateID) ON UPDATE CASCADE ON DELETE CASCADE,   -- edge from note a to b
    dfa_b INTEGER NOT NULL REFERENCES dfa_nodes(stateID) ON UPDATE CASCADE ON DELETE CASCADE,   -- edge from node b to a
    PRIMARY KEY (dfa_a, dfa_b)
);
CREATE INDEX dfa_a_idx ON dfa_edges (dfa_a);
CREATE INDEX dfa_b_idx ON dfa_edges (dfa_b);

-- Inserting the values for the deterministic finite automata represented as a graph in 2 tables nodes and edges
INSERT INTO
    dfa_nodes(stateID, letter)
VALUES
    (1,'F'),
    (2,'o'),
    (3,'t'),
    (4,'o'),
    (5,'P'),
    (6,'h')
RETURNING *;

INSERT INTO
    dfa_edges(dfa_a, dfa_b)
VALUES
    (1, 2),
    (2, 3),
    (3, 4),
    (5, 6),
    (6, 2)
RETURNING *;

-- listing the directly connected nodes
SELECT *
  FROM dfa_nodes n
  LEFT JOIN dfa_edges e ON n.stateID = e.dfa_b
 WHERE e.dfa_a = 2;

SELECT * FROM dfa_nodes WHERE stateID IN (
  SELECT dfa_a FROM dfa_edges WHERE dfa_b = 1
  UNION ALL
  SELECT dfa_b FROM dfa_edges WHERE dfa_a = 1
);

-- transitive closure with WITH RECURSIVE
WITH RECURSIVE transitive_closure(a, b, distance, path_string) AS
( SELECT dfa_a, dfa_b, 1 AS distance,
    dfa_a || '.' || dfa_b || '.' AS path_string
  FROM dfa_edges

  UNION ALL

  SELECT tc.a, e.dfa_b, tc.distance + 1,
  tc.path_string || e.dfa_b || '.' AS path_string
  FROM dfa_edges AS e
    JOIN transitive_closure AS tc
      ON e.dfa_a = tc.b
  WHERE tc.path_string NOT LIKE '%' || e.dfa_b || '.%'
)
SELECT * FROM transitive_closure
ORDER BY a, b, distance;


------------- experiments
WITH RECURSIVE transitive_closure(l, actual_string) AS
( SELECT letter AS l,
         letter || '.' AS actual_string
  FROM dfa_nodes

  UNION

  SELECT n.letter, tc.actual_string || n.letter || '.' AS actual_string
  FROM dfa_nodes AS n
    JOIN transitive_closure AS tc
      ON n.letter = tc.l
  WHERE tc.actual_string NOT LIKE '%' || n.letter || '.%'
)
SELECT * FROM transitive_closure;
