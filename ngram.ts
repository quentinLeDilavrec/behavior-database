import * as es from "event-stream";
import * as fs from "fs";
import { spawn } from 'child_process';

function duplicator(size: number) {
  const mem = (new Array(size)).fill('$')
  let pos = 0;
  return function (line: string) {
    let r = '';
    for (let i = 1; i < size + 1; i++) {
      r += mem[(pos + i) % size];
    }
    mem[pos = ((pos + 1) % size)] = line;
    return r + line + '\n';
  }
}

/**
 * 
 * @param readStream input stream to process
 * @param n ngram size
 * @param type 
 */
export function count_ngrams(readStream:fs.ReadStream, n:number, type?:'count'|'print'|'uniq_count') {
  let cmd:[string,string[]];
  if (type === 'count') {
    cmd = ['sh', ['-c', "sort | uniq -c | awk '{print $1;}' | sort -nr"]];
  } else if (type === 'print') {
    cmd = ['cat', []];
  } else if (type === 'uniq_count') {
    cmd = ['sh', ['-c', "sort | uniq | wc -l"]];
  } else {
    throw "don't know this way of processing the stream"
  }
  const exe = spawn(cmd[0], cmd[1], { stdio: ['pipe', 'pipe', 2, 'ipc'] })

  readStream
    .pipe(es.split())
    .pipe(es.mapSync(duplicator(n - 1)))
    .pipe(es.join('\n'))
    .pipe(exe.stdin);

  return exe.stdout;
}

if (typeof require != 'undefined' && require.main==module) {
  const readStream = fs.createReadStream(process.argv[2]);
  count_ngrams(readStream, parseInt(process.argv[3]),process.argv[4] as any).pipe(process.stdout)
  // count_ngrams('/home/quentin/Documents/cours/M1/stage/ongit/logs/from_sandboxes/1', 10)
}