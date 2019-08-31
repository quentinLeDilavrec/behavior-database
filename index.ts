import { count_ngrams } from "./ngram";
import * as fs from "fs";
import { PassThrough, Readable } from "stream"
import { merge, MapStream } from "event-stream";
function ordered_merge(l: Readable[]): Readable {
    l.forEach(x => x.pause())
    const final = new PassThrough()
    const f = (i: number) => {
        l[i].pipe(final, { end: i + 1 === l.length })
        l[i].on('end', () => {
            if (i+1 < l.length) f(i + 1)
        })
        l[i].resume()
    }
    f(0)
    return final
}
function applyOn(fn: (path: string) => Readable, data_paths: string[]) {
    return ordered_merge(data_paths.filter(x => fs.statSync(x).isFile()).map(x => fn(x)))
}

function dummy(readStream: fs.ReadStream, n: number, type?: 'count' | 'print' | 'uniq_count'): Readable {
    const s = new PassThrough()
    s.write('coucou')
    s.end()
    return s
}

if (process.argv[2] === 'counts') {
    applyOn(x => ordered_merge(Array(2).fill(0).map((y, i) => {
        const s = new PassThrough()
        s.write(x + ' ' + (i + 1) + ' ')
        const tmp = count_ngrams(fs.createReadStream(x), i + 1, 'uniq_count')
        tmp.pipe(s, { end: false })
        tmp.on('end', () => {
            // s.write('\n')
            s.end()
        })
        return s
    })), process.argv.slice(3)).pipe(process.stdout)
} else {

}