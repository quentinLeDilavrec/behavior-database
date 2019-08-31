import * as fs from "fs";
import * as path from "path";
import * as es from "event-stream";
import stream = require('stream');

function ltreeFormat(s: string): string {
  return s.replace(/\ç/g, 'çç').replace(/\-/g, 'ç1').replace(/\./g, 'ç0').replace(/\//g, '.')
}

function reformatLine(session: number) {
  return function (line: string, cb: (err?: string, data?: string) => void, idx: number) {
    if (idx === undefined) throw 'no idx, modify parameters given to mapper in map-stream module';
    if (line.trim().length === 0) {
      cb(); return;
    }
    if (line[0] !== 'g') throw 'bad format: ' + line;
    const tmp_replace_key = 'gutenberg/';
    if (line.substr(0, tmp_replace_key.length) === tmp_replace_key) {
      line = line.substr(tmp_replace_key.length)
    }
    const first_space_idx = line.indexOf(' ');
    const first_dpoint_idx = line.indexOf(':');
    if (first_space_idx === -1) {
      cb(null, 'gutenberg,' + ltreeFormat(line.substr(0, first_dpoint_idx))
        + ',' + line.substr(first_dpoint_idx + 1).replace(/:/g, ',') + ',' + session + ',' + idx + ',\\N');
    } else {
      cb(null,
        'gutenberg,'
        + ltreeFormat(line.substr(0, first_dpoint_idx))
        + ',' + line.substr(first_dpoint_idx + 1, first_space_idx - first_dpoint_idx - 1).replace(/:/g, ',')
        + ',' + session
        + ',' + idx
        + ',"' + line.substr(first_space_idx + 1).replace(/\\/g, '\\\\').replace(/"/g, '\\"')
        + '"');
    }
  }
}


export function reformatFile(inPath: string[] | string, outPath: string, getSession: number | ((i: number) => number), pattern?: RegExp) {
  let _getSession:((i: number) => number);
  if (typeof getSession === 'number') {
    const base = getSession;
    _getSession = (getSession < 0) ?
      i => base - i : i => base + i
  } else {
    _getSession = getSession;
  }
  if (pattern === undefined && (typeof inPath === 'string' || inPath.length === 1)) {
    const readStream = fs.createReadStream(typeof inPath === 'string' ? inPath : inPath[0]);
    const writeStream = fs.createWriteStream(outPath);
    readStream
      .pipe(es.split())
      .pipe(es.map(reformatLine(_getSession(0))))
      .pipe(es.join('\n'))
      .pipe(writeStream);
  } else {
    if (typeof inPath !== 'string' && pattern !== undefined) {
      throw 'multidir selection don\'t work';
    } else {
      const flist = (typeof inPath === 'string') ?
        fs.readdirSync(inPath).filter(x => x.match(pattern)) :
        inPath.filter(x => fs.statSync(x).isFile());
      const writeStreams = flist
        .map((x: string, i: number) => {
          const readStream = fs.createReadStream((typeof inPath === 'string') ? path.join(inPath, x):x);
          const writeStream = new stream.PassThrough();
          readStream
            .pipe(es.split())
            .pipe(es.map(
              reformatLine(_getSession(i))))
            .pipe(writeStream);
          return writeStream
        })
      es.merge(writeStreams)
        .pipe(es.join('\n'))
        .pipe(fs.createWriteStream(outPath))
    }
  }
}

if (typeof require != 'undefined' && require.main == module) {
  reformatFile(process.argv.slice(2), 'output.csv', 4);
  // reformatFile('/home/quentin/js_intercept_data/unit/v2/', 'output2.csv', -1, /^0\.[0-9]+$/);
  // reformatFile('/home/quentin/Documents/cours/M1/stage/ongit/start-instrumented-chrome/logs/', 'output.csv', 1, /^[0-9]+$/);

  // count_ngrams(readStream, parseInt(process.argv[3]),process.argv[4] as any).pipe(process.stdout)
  // count_ngrams('/home/quentin/Documents/cours/M1/stage/ongit/logs/from_sandboxes/1', 10)
//   ../logs/gutenberg/from_systemtest/just_open_new_post/0 4
// ../logs/gutenberg/from_systemtest/just_open_new_post/1 5
// ../logs/gutenberg/from_systemtest/just_open_new_post/2 6
// ../logs/gutenberg/from_systemtest/just_open_new_post/3 7
// ../logs/gutenberg/from_systemtest/just_open_new_post/4 8
// ../logs/gutenberg/from_systemtest/just_open_new_post/5 9
// ../logs/gutenberg/from_systemtest/just_open_new_post/6 10
// ../logs/gutenberg/from_systemtest/just_open_new_post/7 11
// ../logs/gutenberg/from_systemtest/just_open_new_post/8 12
// ../logs/gutenberg/from_systemtest/just_open_new_post/9 13
}