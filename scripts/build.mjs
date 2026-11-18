import fs from 'node:fs/promises';import path from 'node:path';import zlib from 'node:zlib';import vm from 'node:vm';
const root=path.resolve(import.meta.dirname,'..'),out=path.join(root,'public');await fs.mkdir(out,{recursive:true});
let html=await fs.readFile(path.join(root,'src/application-shell.html'),'utf8'),app=await fs.readFile(path.join(root,'src/application.html'),'utf8');
const hostedAssets=JSON.parse(await fs.readFile(path.join(root,'src/hosted-assets.json'),'utf8'));app=app.replace(/(<script type="application\/json" id="atw69-assets">)[\s\S]*?(<\/script>)/,(_,a,b)=>a+JSON.stringify(hostedAssets)+b);
html=html.replace(/<script type="application\/octet-stream" id="atw100-offline-data">[\s\S]*?<\/script>/,'').replace(/<script id="atw100-offline-bootstrap">[\s\S]*?<\/script>/,'').replace(/<script type="application\/json" id="atw103-audio-data">[\s\S]*?<\/script>/,'').replace(/<script>window.ATW103AudioPacked=JSON.parse\(document.getElementById\("atw103-audio-data"\).textContent\);<\/script>/,'');
app=app.replace(/const INTERNAL_USERS=\[[\s\S]*?\];/,'const INTERNAL_USERS=[];');
app=app.replace(/<script id="atw110-empty-reset">[\s\S]*?<\/script>/,'');
const restore=`<script id="atw-cloud-restore">if(window.ATWCloud){const ns='ATW_CLOUD_111::'+ATWCloud.session.user.id+'::';for(const e of ATWCloud.entries){const key=e.key.startsWith('ATW_CLOUD::')?ns+e.key.slice(11):e.key;if(e.value===null)ATWStorageSafe.storage.removeItem(key);else ATWStorageSafe.storage.setItem(key,e.value);}}</script>`;
app=app.replace('<head>','<head>'+restore);
const bridge=await fs.readFile(path.join(root,'src/bridge.js'),'utf8');new vm.Script(bridge);app+='\n<script id="atw-cloud-bridge">'+bridge+'</script>';
if(!app.includes('id="atw-cloud-bridge"'))throw Error('Cloud bridge was not inserted.');
if(process.env.SUPABASE_URL){const origin=new URL(process.env.SUPABASE_URL).origin;if(!origin.endsWith('.supabase.co')||!origin.startsWith('https:'))throw Error('Invalid Supabase project URL.');app=app.replace("connect-src &apos;self&apos;;","connect-src &apos;self&apos; "+origin+';').replace("frame-src &apos;self&apos; blob: data:;","frame-src &apos;self&apos; blob: data: "+origin+';');}
for(const match of app.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi))if(!/application\//.test(match[1])&&match[2].trim())new vm.Script(match[2]);
html=html.replace(/(<script type="application\/json" id="atw72-application">)[\s\S]*?(<\/script>)/,(_,a,b)=>a+zlib.gzipSync(Buffer.from(app),{level:9}).toString('base64')+b);
await fs.writeFile(path.join(out,'application.html'),html);await fs.copyFile(path.join(root,'src/index.html'),path.join(out,'index.html'));await fs.copyFile(path.join(root,'src/launcher.js'),path.join(out,'launcher.js'));await fs.cp(path.join(root,'src/assets'),path.join(out,'assets'),{recursive:true});await fs.cp(path.join(root,'src/vendor'),path.join(out,'vendor'),{recursive:true});
console.log('Built ATW Source for Vercel. No runtime secret is bundled.');
