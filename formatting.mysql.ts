import * as fs from "fs";
import * as path from "path";
import * as es from "event-stream";
import stream = require('stream');


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
    const tmp = line.indexOf(' ')
    if (tmp === -1) {
      cb(null, 'gutenberg,' + line.replace(/:/g, ',') + ',' + session + ',' + idx + ',\\N');
    } else {
      cb(null,
        'gutenberg,'
        + line.substr(0, tmp).replace(/:/g, ',')
        + ',' + session + ','
        + idx + ',"'
        + line.substr(tmp + 1).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"');
    }
  }
}


export function reformatFile(inPath: string, outPath: string, getSession: number | ((i: number) => number), pattern?: RegExp) {
  let _getSession: undefined | ((i: number) => number);
  if (typeof getSession === 'number') {
    const base = getSession;
    getSession = (getSession < 0) ?
      i => base - i : i => base + i
  } else {
    _getSession = getSession;
  }
  if (pattern === undefined) {
    const readStream = fs.createReadStream(inPath);
    const writeStream = fs.createWriteStream(outPath);
    readStream
      .pipe(es.split())
      .pipe(es.map(reformatLine(getSession(0))))
      .pipe(es.join('\n'))
      .pipe(writeStream);
  } else {
    const writeStreams = fs.readdirSync(inPath).filter(x => x.match(pattern))
      .map((x: string, i: number) => {
        const readStream = fs.createReadStream(path.join(inPath, x));
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



if (typeof require != 'undefined' && require.main==module) {
  reformatFile(process.argv[2],'output2.csv',1);
// reformatFile('/home/quentin/js_intercept_data/unit/v2/', 'output2.csv', -1, /^0\.[0-9]+$/);
// reformatFile('/home/quentin/Documents/cours/M1/stage/ongit/start-instrumented-chrome/logs/', 'output.csv', 1, /^[0-9]+$/);

  // count_ngrams(readStream, parseInt(process.argv[3]),process.argv[4] as any).pipe(process.stdout)
  // count_ngrams('/home/quentin/Documents/cours/M1/stage/ongit/logs/from_sandboxes/1', 10)
}