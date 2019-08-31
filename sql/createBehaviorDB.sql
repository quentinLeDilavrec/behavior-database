CREATE EXTENSION ltree;

-- table storing traces
CREATE TABLE calls (
  origin text NOT NULL,
  path ltree NOT NULL,
  sl integer NOT NULL,
  sc integer NOT NULL,
  el integer NOT NULL,
  ec integer NOT NULL,
  session integer NOT NULL,
  line integer NOT NULL,
  params json DEFAULT NULL,
  PRIMARY KEY (origin,session,line)
);
create index ON calls using gist(path);
create index ON calls(path,sl,sc,el,ec);


-- contain all processed ngrams
CREATE TABLE accTable (
  n int NOT NULL, 
  hash text NOT NULL, 
  session int NOT NULL,
  "left" int NOT NULL,
  isLastPrev boolean NOT NULL,
  ori int NOT NULL,
  PRIMARY KEY (n, session, "left")
);
CREATE index ON accTable(n, hash);
-- if you want to know the number of basic symbols started to be processed, count number of distinct 1,1-gram in accTable
-- if you want to find the row of a particular function search for (1, MD5(CONCAT(formatPath(c.path),c.sl,c.sc,c.el,c.ec))) in accTable
-- you can search for missing ngrams looking for gaps in (n, session, left) when sorted
-- if you want to process a new ngram in the database you need to make apply the algorithm starting from the left symbol
-- for any given ngram you can fin how it was contructed looking at the symbol pointed by session,left+ori

-- contain statistics on ngrams, such as occurences in tests and production
CREATE TABLE groupTable (
  path ltree NOT NULL,
  sl int NOT NULL,
  sc int NOT NULL,
  el int NOT NULL,
  ec int NOT NULL,
  n int NOT NULL,
  hash text NOT NULL,
  pocc bigint NOT NULL,
  tocc bigint NOT NULL,
  PRIMARY KEY (path, sl, sc, el, ec, n, hash)
);
-- each indexed symbols statitics are accessible through the given symbol then the ngram size
-- so the size of this table should be proportional to the number of indexed symbols and the number of ngram mined through accTable

-- tests
SELECT formatPath('packages/edit-post/src/store/test/selectors.js');
DELETE FROM calls;
INSERT INTO CALLS (origin, path, sl, sc, el, ec, session, line, params) VALUES
('test1', formatPath('packages/edit-post/src/store/test/selectors.js'), 205, 40, 211, 3, -5375, 1, NULL),
('test1', formatPath('packages/edit-post/src/store/selectors.js'), 111, 7, 113, 1, -5375, 2, '["[Object]", "post-status"]'),
('test1', formatPath('packages/scripts/config/global-setup.js'), 70, 11, 76, 1, -5375, 3, NULL),
('test1', 'packages.scripts.config.globalç1setupç0ts', 70, 11, 76, 1, -5377, 3, NULL),
('test1', formatPath('packages/blocks/src/api/raw-handling/test/figure-content-reducer.js'), 35, 36, 40, 2, -5374, 1, NULL);
SELECT formatPath(path) FROM calls;


