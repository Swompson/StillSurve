# Coordinated glass investigation

Patrol destinations use a bounded breadth-first search within four corridors.
Cells near uncollected figurines receive a preference; hunters do not maintain
a checklist of all figurines. Shorter legs, a six-cell visit history, and avoiding
the other hunter's destination reduce long crossings and immediate repetition.
Dead ends permit backtracking. `tests/local_patrol_regression.gd` validates all
121 starting cells, nearby figurine approaches, and dead-end fallback.

The two default hunters compare navigable route lengths when glass is heard.
The nearer hunter uses the shortest route. The farther hunter approaches through
a different final corridor when that corridor is reachable. Dead ends retain the
normal route. The hardcore stalker keeps its separate behavior.

Flanking follows explicit cell waypoints so visibility shortcuts cannot erase
the alternate approach. Repeated noise in the same cell preserves that route.
Sight of the player interrupts investigation and starts the normal chase.

The patrol destination is saved before investigation or visual detection. After
an unsuccessful search, including a search following a lost chase, the hunter
returns to that destination before choosing another patrol target.

Validation: `tests/coordinated_hunters_regression.gd` checks alternate approaches,
distance-based role reversal, repeated noise, patrol restoration, graph restoration,
and dead-end fallback. `tests/gameplay_smoke.gd` checks the main gameplay rules.
