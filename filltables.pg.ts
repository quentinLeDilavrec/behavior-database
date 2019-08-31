import { Client } from 'pg';
import { from as copyFrom } from "pg-copy-streams";
import * as fs from "fs";

const client = new Client({
  user: 'ubehavior',
  host: 'localhost',
  database: 'behaviordb',
  password: 'password',
  port: 5432,
})

export async function exportFile(inPath: string) {
  const table = 'public.calls';
  const path = inPath;

  await client.connect();

  const stream = client.query(copyFrom(`
COPY ${table} FROM STDIN
WITH (FORMAT csv,
  QUOTE '"',
  ESCAPE '\\',
  NULL '\\N')
  `));
  const fileStream = fs.createReadStream(path)
  fileStream.on('error', (...x) => {
    console.error(x)
    client.end()});
  stream.on('error', x => {
    console.error(x)
    client.end()});
  stream.on('end', (...x) => {
    console.log(x)
    client.end()});
  fileStream.pipe(stream)
}

if (typeof require != 'undefined' && require.main == module) {
  exportFile(process.argv[2]);
}