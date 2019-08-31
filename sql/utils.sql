-- ltree formating with unix paths

CREATE OR REPLACE FUNCTION public.formatPath (
  s char
)
  RETURNS ltree
  AS $BODY$
BEGIN
  RETURN text2ltree (REPLACE(REPLACE(REPLACE(REPLACE(s, 'ç', 'çç'), '-', 'ç1'), '.', 'ç0'), '/', '.'));
END;
$BODY$
LANGUAGE plpgsql
IMMUTABLE;

CREATE OR REPLACE FUNCTION public.formatPath (
  l ltree
)
  RETURNS char
  AS $BODY$
BEGIN
  RETURN REPLACE(REPLACE(REPLACE(REPLACE(ltree2text (l), '.', '/'), 'ç0', '.'), 'ç1', '-'), 'çç', 'ç');
END;
$BODY$
LANGUAGE plpgsql
IMMUTABLE;


-- Procedure to instanciate a 1-gram in accTable
-- Caution it shouldn't be used anymore (useless) because entirely computed from calls table and statics in groupTable
INSERT INTO accTable (n, hash, session, "left", isLastPrev, ori)
SELECT n, MD5(CONCAT(formatPath(c.path),c.sl,c.sc,c.el,c.ec)),
        c.session, c.line, false, 0
FROM CALLS c
WHERE origin = c.origin
AND path @> formatPath(initPath)
AND sl = c.sl
AND sc = c.sc
AND el = c.el
AND ec = c.ec;
