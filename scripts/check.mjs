import fs from 'node:fs/promises';import path from 'node:path';import zlib from 'node:zlib';
const root=path.resolve(import.meta.dirname,'..'),html=await fs.readFile(path.join(root,'public/application.html'),'utf8'),app=zlib.gunzipSync(Buffer.from(html.match(/id="atw72-application">([^<]*)/)[1],'base64')).toString();
if(!app.includes('const INTERNAL_USERS=[];')||!app.includes('id="atw-cloud-bridge"')||app.includes('id="atw110-empty-reset"'))throw Error('Hosted application isolation failed.');
const fixture=JSON.parse(app.match(/id="atw68-data">([\s\S]*?)<\/script>/)[1]);for(const [key,value]of Object.entries(fixture))if(Array.isArray(value)&&!['item','access'].includes(key)&&value.length)throw Error('Public business records in '+key);
for(const key of ['SUPABASE_SECRET_KEY','AUTH_RATE_SALT'])if(process.env[key]&&html.includes(process.env[key]))throw Error('Secret found in public application.');
console.log('Hosted application isolation and empty canonical dataset verified.');
