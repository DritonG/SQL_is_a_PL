DROP TABLE  states;

-- Representing a DFA as a graph in 1 table with 'stateID' as an state identifier and with "letter" as its value.
-- 'prevState' is the state which the automata has kept before -> previousState
CREATE TABLE states
(   stateID INTEGER PRIMARY KEY, -- node identifier
    -- since we have a directed graph, we know where this state came from (previous state)
    -- TODO: prevState has to be an array according to multiple previous states!! TBD
    prevState INTEGER NOT NULL REFERENCES states(stateID) ON UPDATE CASCADE  ON DELETE CASCADE,
    letter  CHAR(1)              -- letter in alphabet (Tuple-A)
);

-- Inserting the values for the deterministic finite automata
-- Tuple-S: {1 , 2, 3, 4, 5, 6}; 6 States + the NULL states which indicates a starting node(state)
-- Tuple-A: {F, o, t, o, P, h}; Alphabet with 6 letters.
INSERT INTO
    -- TODO: prevState has to be an array according to multiple previous states!! TBD
    states(stateID, prevState, letter)
VALUES
-- reference node to declare starting states, every node which is connected to this node is a starting state
    (0, 0, NULL),
    (1, 0,'F'), -- start state
    (2, 1,'o'),
    (3, 2,'t'),
    (4, 3,'o'), -- end state
    (5, 0,'P'), -- start state
    (6, 5,'h')
RETURNING *;