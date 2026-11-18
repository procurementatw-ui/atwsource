import {createApp} from '../server/app.mjs';
const app=createApp(process.env);
export default async function handler(req,res){
 const origin=process.env.APP_ORIGIN||'https://unconfigured.invalid',url=new URL(req.url,origin),headers=new Headers();for(const [key,value]of Object.entries(req.headers))if(value!==undefined)headers.set(key,Array.isArray(value)?value.join(','):value);
 const method=req.method||'GET',hasBody=!['GET','HEAD'].includes(method),payload=req.body===undefined?req:typeof req.body==='string'||Buffer.isBuffer(req.body)?req.body:JSON.stringify(req.body),request=new Request(url,{method,headers,...hasBody?{body:payload,duplex:'half'}:{}}),response=await app(request);
 res.statusCode=response.status;for(const [key,value]of response.headers)if(key!=='set-cookie')res.setHeader(key,value);const cookies=response.headers.getSetCookie();if(cookies.length)res.setHeader('Set-Cookie',cookies);res.end(Buffer.from(await response.arrayBuffer()));
}
