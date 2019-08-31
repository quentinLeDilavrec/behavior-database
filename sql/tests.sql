
--SELECT compute2gram('packages/hooks/src/createRunHook.js',12,0,71,1);

SELECT c.*, g.*
FROM getngrams('packages/hooks/src/createRunHook.js',12,0,71,1,2::smallint) as g,
     calls c
WHERE 'gutenberg' = c.origin
AND c.session = g.session
AND line >= g.left
AND line < g.left+g.n
ORDER BY g.n, g.hash,g.session,c.line;



    SELECT g.*
    FROM groupTable g
    WHERE 'gutenberg' = g.origin
    AND g.path @> formatPath('packages/hooks/src/createRunHook.js');

  WITH g1 AS (
    SELECT g.*
    FROM groupTable g
    WHERE 'gutenberg' = g.origin
    AND g.path <@ formatPath('packages/hooks/src/createRunHook.js')
    AND 12 = g.sl
    AND 0 = g.sc
    AND 71 = g.el
    AND 1 = g.ec
  ), dir as (
    SELECT n-1 as n, MIN(shift)>0 as next, MAX(shift)<n-1 as prev
    FROM g1 as g
    GROUP BY n
    HAVING MIN(shift)>0 OR MAX(shift)<n-1
    UNION
    SELECT MAX(n) as n, true as next, true as prev FROM g1
  )
  select * from g1;

SELECT continuecomputengram('packages/hooks/src/createRunHook.js',12,0,71,1,True,True);

    SELECT g.*
    FROM groupTable g
    WHERE 'gutenberg' = g.origin
    AND g.path @> formatPath('packages/hooks/src/createRunHook.js');

  WITH g1 AS (
    SELECT g.*
    FROM groupTable g
    WHERE 'gutenberg' = g.origin
    AND g.path @> formatPath('packages/hooks/src/createRunHook.js')
    AND 12 = g.sl
    AND 0 = g.sc
    AND 71 = g.el
    AND 1 = g.ec
  ), dir as (
    SELECT n-1 as n, MIN(shift)>0 as next, MAX(shift)<n-1 as prev
    FROM g1 as g
    GROUP BY n
    HAVING MIN(shift)>0 OR MAX(shift)<n-1
    UNION
    SELECT MAX(n) as n, true as next, true as prev FROM g1
  )
  select MIN(dir.n) = 3 from dir where dir.prev;

SELECT continuecomputengram('packages/hooks/src/createRunHook.js',12,0,71,1,True,True);


SELECT c.*, g.*
FROM getngrams('packages/hooks/src/createRunHook.js',12,0,71,1,5::smallint) as g,
     calls c
WHERE 'gutenberg' = c.origin
AND c.session = g.session
AND line >= g.left
AND line < g.left+g.n
ORDER BY g.n, g.hash,g.session,c.line;

