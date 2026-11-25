export type Service={name:string;price:number;duration:number};
export type Barber={id:string;name:string;shop:string;area:string;bio:string;initials:string;color:string;distance:number;rating:number|null;reviews:number;lat:number;lng:number;services:Service[]};
export type Booking={id:string;barberId:string;barberName:string;shop:string;service:string;start:string;end:string;price:number;currency:string;status:string};
const root=process.env.EXPO_PUBLIC_API_URL||'http://localhost:4000';
export async function api<T>(path:string,options:RequestInit={},token?:string):Promise<T>{
 const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),15000);
 try{
  const res=await fetch(root+path,{...options,signal:controller.signal,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`} :{}),...options.headers}});
  const body=await res.json();if(!res.ok)throw Error(body.message||'Could not complete your request.');return body;
 }catch(error){if((error as Error).name==='AbortError')throw Error('The server took too long. Please try again.');throw error;}finally{clearTimeout(timer);}
}
