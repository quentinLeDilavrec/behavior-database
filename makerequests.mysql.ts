import { createConnection } from 'mysql';
// import { createConnection } from 'mysql';
// import fs from 'fs';
// import es from 'event-stream';

const dirname = '/home/quentin/js_intercept_data/browser/v2/';
// let i = 0;

let connection = createConnection({
  host: 'localhost',
  port: 9992,
  user: 'ubehaviour',
  password: 'password',
  database: 'behaviour'
});

export function exportFile(inPath: string) {

  connection.connect();

  let table = 'CALLS';

  let path = inPath;
  let sql =
    'LOAD DATA LOCAL INFILE ? INTO TABLE ' + table + ' ' +
    'FIELDS TERMINATED BY ?' + // (root, path, sl, sc, el, ec, session, line, params)' +
    'OPTIONALLY ENCLOSED BY \'"\' ' +
    'ESCAPED BY \'\\\\\' ';
  let ok;
  connection.query(sql, [path, ','], function (err, _ok) {
    if (err) throw err;

    ok = _ok;
  });

  connection.end();
}
// exportFile('./output2.csv');
// exportFile('./output.csv');

function getFct(l: string[], namespace?: string) {
  return 'CONCAT(' + l.map(x => namespace ? namespace + '.' + x : x).join(",':',") + ')'
}

/**
 * 
 * @param {*} cols
 * `
 * path = 'packages/hooks/src/createRunHook.js'
 * AND sl = 12
 * AND sc = 0
 * AND el = 71
 * AND ec = 1
 * ` 
 */
function genInitReq(cols: string[], particulars?: string[]): [string, string, (s: string) => string] {
  return [`SELECT root, session, ${getFct(['path', 'sl', 'sc', 'el', 'ec'])} AS fct0, params AS params0, prev_line, next_line FROM CALLS
WHERE ` + [...cols.map(x => x + ' = ?'), ...particulars].join(' AND '), 'init', (x: string) => x + `.fct0, ` + x + `.params0, `]
}

// console.log(genInitReq(['path','sl','sc','el','ec']))

export function genBehavioralReq(init_cols: any[]) {
  const idx = 0
  return `SELECT init.root, init.session, 
    init.fct`+ idx + `, init.params` + idx + `, 
    ${getFct(['path', 'sl', 'sc', 'el', 'ec'], 'CALLS')} AS fct1, CALLS.params AS params1,
    CALLS.line, CALLS.next_line
    FROM ( ${genInitReq(init_cols)} ) AS init
       , CALLS
    WHERE init.root = CALLS.root
    AND init.session = CALLS.session
    AND init.next_line = CALLS.line)`
}

function move(dir: string, req: [string, string, (s: string) => string], idx: number): [string, string, (s: string) => string] {
  return [`SELECT ` + req[1] + `.root, ` + req[1] + `.session, 
`+ req[2](req[1]) + `
${getFct(['path', 'sl', 'sc', 'el', 'ec'], 'CALLS')} AS fct_` + dir + idx + `, CALLS.params AS params_` + dir + idx + `,
CALLS.line, CALLS.`+ dir + `_line, ` + req[1] + `.` + (dir === 'prev' ? 'next' : 'prev') + `_line
FROM (`+ req[0].split('\n').join('\n      ') + `) AS ` + req[1] + `, 
     CALLS
WHERE `+ req[1] + `.root = CALLS.root
AND `+ req[1] + `.session = CALLS.session
AND `+ req[1] + `.` + dir + `_line = CALLS.line`, dir + idx, x => req[2](x) + x + `.fct_` + dir + idx + `, ` + x + `.params_` + dir + idx + `, `]
}

function applyReq(req: string, init_params: string[]) {
  return init_params.reduce((acc, x) => acc.replace('?', x), req)
}

// const req1 = move('prev',genInitReq(['path','sl','sc','el','ec']),1)
// console.log(req1[0])
// const req2 = move('prev',req1,2)
// console.log(req2[0])
// const req3 = move('next',req2,1)
// console.log(req3[0])

// console.log(applyReq(move('prev',genInitReq(['path','sl','sc','el','ec']),1)[0],["'packages/hooks/src/createRunHook.js'",12,0,71,1]));
// console.log(applyReq(req3[0],["'packages/hooks/src/createRunHook.js'",12,0,71,1]));
/**
 * 
 * @param {string[]} keys like ['path','sl','sc','el','ec']
 * @param {any[]} values like ['packages/hooks/src/createRunHook.js', 12, 0, 71, 1]
 * @param {Array<'prev'|'next'>} moves like ['prev','next','next','prev','prev']
 */
export async function getPaths(keys: string[], values: any[], moves: ('prev' | 'next')[], particulars: string[]) {
  const reqinf = moves.reduce((acc, x, i) => move(x, acc, i), genInitReq(keys, particulars));

  connection.connect();

  connection.query(reqinf[0], values, function (err, _ok) {
    if (err) throw err;
    else console.log(JSON.stringify(_ok, undefined, '  '))
  });

  connection.end();
}

// const save1 = `SELECT init.root, init.session, 
// init.fct0, init.params0, 
// CONCAT(CALLS.path,':',CALLS.sl,':',CALLS.sc,':',CALLS.el,':',CALLS.ec) AS fct1, CALLS.params AS params1,
// CALLS.line, CALLS.next_line 
// FROM (SELECT root, session, CONCAT(path,':',sl,':',sc,':',el,':',ec) AS fct0, params AS params0, next_line FROM CALLS
//       WHERE path = 'packages/hooks/src/createRunHook.js'
//       AND sl = 12
//       AND sc = 0
//       AND el = 71
//       AND ec = 1 ) AS init
//    , CALLS
// WHERE init.root = CALLS.root
// AND init.session = CALLS.session
// AND init.next_line = CALLS.line`;

// getPaths(['root'],['gutenberg',0],['next','next'],['session < ?'])
// NOTE with DISCTINCT, 38373 for tests, ~20000 for production