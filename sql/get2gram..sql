CREATE OR REPLACE FUNCTION public.get2gram (
  initPath text,
  sl int,
  sc int,
  el int,
  ec int
)
  RETURNS TABLE (
      n int,
      HASH text,
      session int,
    LEFT int,
    pocc bigint,
    tocc bigint
)
AS $BODY$
  # variable_conflict use_variable
DECLARE
  n int;
  origin text;
BEGIN
  origin: = 'gutenberg';
  n: = 1;
  WITH a AS (
    -- instanciate 1-gram
    SELECT
      n,
      MD5(CONCAT(formatPath (c.path), c.sl, c.sc, c.el, c.ec)),
      c.session,
      c.line,
      FALSE,
      0
    FROM
      CALLS c
    WHERE
      origin = c.origin
      AND path @> formatPath (initPath)
      AND sl = c.sl
      AND sc = c.sc
      AND el = c.el
      AND ec = c.ec
)
-- Procedure to instanciate statics of 1-gram in groupTable
INSERT INTO groupTable (path, sl, sc, el, ec, n, HASH, pocc, tocc)
SELECT
  initPath, sl, sc, el, ec, a.n, a.hash, SUM((SIGN(a.session) > 0)::int), SUM((SIGN(a.session) < 0)::int)
FROM
  a
GROUP BY
  a.n, a.hash;
  n: = n + 1;
  -- n = 2
  WITH g AS (
    SELECT
      *
    FROM
      groupTable g
    ORDER BY
      g.pocc DESC,
      g.n DESC,
      g.tocc
      --LIMIT 4*ceil(log(n,n))
),
a AS (
  -- move to previous line, n=2
  INSERT INTO accTable (n,
    HASH,
    session,
    "left",
    isLastPrev,
    ori)
SELECT
  n,
  MD5(CONCAT(formatPath (c.path), c.sl, c.sc, c.el, c.ec, a.hash)),
  a.session,
  a. "left" - 1,
  TRUE,
  a.ori + 1
FROM
  accTable a,
  g,
  calls c
WHERE
  -- n-1 = a.n AND n-1 = g.n AND
  a.hash = g.hash
  AND a.session = c.session
  AND a.left - 1 = c.line
  AND origin = c.origin
  AND NOT (formatPath (initPath) @> c.path
    AND sl = c.sl
    AND sc = c.sc
    AND el = c.el
    AND ec = c.ec);
UNION ALL
-- move to next line, n=2
SELECT
  n,
  MD5(CONCAT(a.hash, formatPath (c.path), c.sl, c.sc, c.el, c.ec)),
  a.session,
  a.left,
  FALSE,
  a.ori
FROM
  accTable a,
  g,
  calls c
WHERE
  --n-1 = a.n AND n-1 = g.n
  a.hash = g.hash
  AND origin = c.origin
  AND a.session = c.session
  AND a.left + (n - 1) = c.line)
INSERT INTO groupTable (n, HASH, pocc, tocc)
SELECT
  a.n, a.hash, SUM((SIGN(a.session) > 0)::int), SUM((SIGN(a.session) < 0)::int)
FROM
  a RETURN QUERY
  SELECT
    g.n, g.hash, a.session, a.left, g.pocc, g.tocc
  FROM
    groupTable g
  CROSS JOIN LATERAL (
    SELECT
      a.session, a.left
    FROM
      accTable a
    WHERE
      g.n = a.n
      AND g.hash = a.hash -- lateral reference
    LIMIT 1) a;
END;
$BODY$
LANGUAGE plpgsql;

