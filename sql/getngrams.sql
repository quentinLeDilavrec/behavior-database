-- pgFormatter-ignore


DROP FUNCTION public.getngrams; DROP FUNCTION public.compute2gram;
DELETE FROM acctable;DELETE FROM grouptable;
CREATE OR REPLACE FUNCTION public.compute2gram(initPath text, sl int, sc int, el int, ec int)
 RETURNS void AS $BODY$
#variable_conflict use_variable
DECLARE
  origin text;
BEGIN
  origin:='gutenberg';

  WITH a1 AS (
    -- get 1-grams of initPath:sl:sc:el:ec
    SELECT MD5(CONCAT(formatPath(c.path),c.sl,c.sc,c.el,c.ec)) as hash,
           c.session as session, c.line as "left"
    FROM CALLS c
    WHERE origin = c.origin
    AND path @> formatPath(initPath)
    AND sl = c.sl
    AND sc = c.sc
    AND el = c.el
    AND ec = c.ec
  ), g1 AS (
    -- Procedure to instanciate statics of 1-gram in groupTable
    INSERT INTO groupTable (origin, path, sl, sc, el, ec, n, hash, shift, pocc, tocc)
    SELECT origin, formatPath(initPath), sl, sc, el, ec, 1, a.hash, 0,
           SUM((SIGN(a.session)>0)::int),
           SUM((SIGN(a.session)<0)::int)
    FROM a1 a
    GROUP BY a.hash
    ON CONFLICT ON CONSTRAINT grouptable_pkey
    DO UPDATE SET pocc = excluded.pocc, tocc = excluded.tocc
    RETURNING pocc, tocc
  ), a2 AS (
    INSERT INTO accTable (origin, n, hash, session, "left", isback, isfront, shift)
    -- move to previous line, n=2
    SELECT origin, 2, MD5(CONCAT(formatPath(c.path),c.sl,c.sc,c.el,c.ec,MD5(CONCAT(formatPath(initPath),sl,sc,el,ec)))) as hash2,
    a.session, a."left"-1, true, false, 1
    FROM a1 a, g1 g, calls c
    WHERE origin = c.origin
    AND a.session = c.session
    AND a.left-1 = c.line 
    AND NOT (
        formatPath(initPath) <@ c.path
        AND sl = c.sl
        AND sc = c.sc
        AND el = c.el
        AND ec = c.ec)
    UNION ALL
    -- move to next line, n=2
    SELECT origin, 2, MD5(CONCAT(MD5(CONCAT(formatPath(initPath),sl,sc,el,ec)),formatPath(c.path),c.sl,c.sc,c.el,c.ec)) as hash2,
    a.session, a.left, false, true, 0
    FROM a1 a, g1 g, calls c
    WHERE origin = c.origin
    AND a.session = c.session
    AND a.left+(2-1) = c.line
      ON CONFLICT ON CONSTRAINT acctable_pkey
      DO UPDATE
      SET hash = accTable.hash, shift = excluded.shift --LEAST(excluded.shift,accTable.shift)
      --need to update group table  (change hash)
    RETURNING acctable.hash, acctable.session, acctable.shift
  )
  INSERT INTO groupTable (origin, path, sl, sc, el, ec, n, hash, shift, pocc, tocc)
  SELECT origin, formatPath(initPath), sl, sc, el, ec, 2 as n, a.hash, MIN(a.shift),
         SUM((SIGN(a.session)>0)::int),
         SUM((SIGN(a.session)<0)::int)
  FROM a2 a
  WHERE NOT a.hash is NULL
  GROUP BY a.hash
  ON CONFLICT ON CONSTRAINT grouptable_pkey 
  DO UPDATE SET pocc = excluded.pocc, tocc = excluded.tocc;

END;
$BODY$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.getngrams(initPath text, sl int, sc int, el int, ec int, max_n smallint)
 RETURNS TABLE(n int, hash text, session int, left int, pocc bigint, tocc bigint, shift smallint) AS $BODY$
#variable_conflict use_variable
DECLARE
  origin text;
  checkpoint_n smallint;
BEGIN
  origin:='gutenberg';
  -- checkpoint_n := (
  --   select MAX(g.n)
  --   from groupTable g
  --   where origin = g.origin
  --   AND g.path @> formatPath(initPath)
  --   AND sl = g.sl
  --   AND sc = g.sc
  --   AND el = g.el
  --   AND ec = g.ec
  --   GROUP BY g.path, g.sl, g.sc, g.el, g.ec
  -- );
  -- IF checkpoint_n is NULL
  -- THEN
  --   PERFORM compute2gram(initPath, sl, sc, el, ec);
  -- END IF;

  RETURN QUERY SELECT g.n, g.hash, a.session, a.left, g.pocc, g.tocc, g.shift
  FROM   groupTable g
  CROSS  JOIN LATERAL (
  SELECT a.session, a.left
  FROM   accTable a, calls c
  WHERE 
    g.path @> formatPath(initPath)
    AND sl = g.sl
    AND sc = g.sc
    AND el = g.el
    AND ec = g.ec
    AND g.n = a.n AND g.hash = a.hash         -- lateral reference
  --ORDER BY c.session, c.line
  LIMIT  1
  ) a
  UNION ALL
  SELECT g.n, g.hash, a.session, a.left, g.pocc, g.tocc, g.shift
  FROM   groupTable g
  CROSS  JOIN LATERAL (
  SELECT c.session as session, c.line as "left"
    FROM CALLS c
    WHERE g.n=1
    AND g.path @> formatPath(initPath)
    AND sl = g.sl    AND sc = g.sc    AND el = g.el    AND ec = g.ec
    AND origin = c.origin
    AND c.path @> formatPath(initPath)
    AND sl = c.sl    AND sc = c.sc    AND el = c.el    AND ec = c.ec
    --ORDER BY c.session, c.line
    LIMIT 1) a;
END;
$BODY$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION public.getngrams(initPath text, sl int, sc int, el int, ec int)
 RETURNS TABLE(n int, hash text, session int, left int, pocc bigint, tocc bigint, shift smallint) AS $BODY$
#variable_conflict use_variable
DECLARE
  origin text;
  checkpoint_n smallint;
BEGIN
   RETURN QUERY SELECT *
   FROM getngrams(initPath, sl, sc, el, ec, 0::smallint);
END;
$BODY$ LANGUAGE plpgsql;
  

CREATE OR REPLACE FUNCTION public.continuecomputengram(initPath text, sl int, sc int, el int, ec int,go_prev boolean, go_next boolean)
 RETURNS void AS $BODY$
#variable_conflict use_variable
DECLARE
  origin text;
BEGIN
  origin:='gutenberg';
  
  WITH g1 AS (
    SELECT g.*
    FROM groupTable g
    WHERE origin = g.origin
    AND g.path @> formatPath(initPath)
    AND sl = g.sl
    AND sc = g.sc
    AND el = g.el
    AND ec = g.ec
  ), dir as (
    SELECT n-1 as n, MIN(shift)>0 as next, MAX(shift)<n-1 as prev
    FROM g1 as g
    GROUP BY n
    HAVING MIN(shift)>0 OR MAX(shift)<n-1
    UNION
    SELECT MAX(n) as n, true as next, true as prev FROM g1
  ), a1 AS (
    INSERT INTO accTable (origin, n, hash, session, "left", isback, isfront, shift)
    -- move to previous line
    SELECT (CASE WHEN g.n=3 THEN origin ELSE origin END), g.n+1, MD5(CONCAT(formatPath(c.path),c.sl,c.sc,c.el,c.ec,g.hash)),
    a.session, a.left-1, a.isback,false, g.shift+1
    FROM accTable a, g1 g, calls c
    WHERE go_prev AND (select MIN(dir.n) from dir where dir.prev) = g.n AND g.n = a.n AND (a.isback OR g.n%2=0)
    AND origin = a.origin
    AND g.hash = a.hash
    AND origin = c.origin
    AND a.session = c.session
    AND a.left-1 = c.line
    AND NOT (
        formatPath(initPath) @> c.path
        AND sl = c.sl
        AND sc = c.sc
        AND el = c.el
        AND ec = c.ec)
    UNION ALL
    -- move to next line
    SELECT origin, g.n+1, MD5(CONCAT(g.hash,formatPath(c.path),c.sl,c.sc,c.el,c.ec)),
    a.session, a.left, false, isfront, g.shift
    FROM accTable a, g1 g, calls c
    WHERE go_next AND (select MIN(dir.n)from dir where dir.next) = g.n AND g.n = a.n AND (a.isfront OR g.n%2=1)
    AND origin = a.origin
    AND origin = c.origin
    AND g.hash = a.hash
    AND a.session = c.session
    AND a.left+a.n = c.line
      ON CONFLICT ON CONSTRAINT acctable_pkey
      DO UPDATE
      SET hash = accTable.hash, shift = excluded.shift --LEAST(excluded.shift,accTable.shift)
      --need to update group table  (change hash)
    RETURNING acctable.hash, acctable.session, acctable.shift, acctable.n, accTable.origin
  )
  INSERT INTO groupTable (origin, path, sl, sc, el, ec, n, hash, shift, pocc, tocc)
  SELECT a.origin, formatPath(initPath), sl, sc, el, ec, MAX(a.n), a.hash, MIN(a.shift),
         SUM((SIGN(a.session)>0)::int),
         SUM((SIGN(a.session)<0)::int)
  FROM a1 a
  WHERE NOT a.hash is NULL
  GROUP BY a.origin, a.hash
  ON CONFLICT ON CONSTRAINT grouptable_pkey 
  DO UPDATE SET pocc = excluded.pocc, tocc = excluded.tocc;

END;
$BODY$ LANGUAGE plpgsql;

-- features:
-- - previous initial symbol merging
-- - reapeting patterns merging
-- - incremental
-- - 
CREATE OR REPLACE FUNCTION public.computengramsv2(initPath text, sl int, sc int, el int, ec int)
 RETURNS TABLE(n int, hash text, session int, left int, pocc bigint, tocc bigint, shift smallint) AS $BODY$
#variable_conflict use_variable
DECLARE
  origin text;
  checkpoint_n smallint;
BEGIN
  
END;
$BODY$ LANGUAGE plpgsql;
  
-- my thing represent the behavior of the program across multiple executions
-- values are statics and exact
-- its use is mainly to descibe behaviors contained in traces
-- then it can be used to generate new tests that represent those behaviors
-- either fixing the important one in time
-- or crating a sligtly different test representing the good alternative to some behavior