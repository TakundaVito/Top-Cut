import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import {rateLimit} from 'express-rate-limit';
import {createClient} from '@supabase/supabase-js';
import {z} from 'zod';
import {barbers,services,searchBarbers,DemoStore} from './domain.js';
const uuid=z.string().uuid();
const date=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(s=>!Number.isNaN(Date.parse(s))&&new Date(s).toISOString().startsWith(s));
export function createApp(config={}) {
 const app=express(); const mode=config.mode??process.env.DATA_MODE??'demo';
 if(!['demo','supabase'].includes(mode))throw Error('Invalid DATA_MODE');
 if(process.env.NODE_ENV==='production'&&mode!=='supabase')throw Error('Production requires DATA_MODE=supabase');
 const url=config.url??process.env.SUPABASE_URL,key=config.key??process.env.SUPABASE_ANON_KEY;
 if(mode==='supabase'&&(!url||!key))throw Error('Supabase URL and anon key required');
 const store=new DemoStore();const clients=token=>createClient(url,key,{auth:{persistSession:false},global:{headers:token?{Authorization:`Bearer ${token}`}:{}}});
 app.use(helmet(),cors({origin:config.origin??process.env.WEB_ORIGIN??'http://localhost:8081'}),express.json({limit:'16kb'}),rateLimit({windowMs:60000,limit:120,message:{message:'Too many requests. Please wait a minute and try again.'}}));
 app.get('/health',(_req,res)=>res.json({status:'ok',mode,version:'0.1.0'}));
 app.get('/services',(_req,res)=>res.json(services));
 app.get('/barbers',async(req,res)=>{const q=z.object({service:z.enum(services).optional(),maxPrice:z.coerce.number().min(0).max(1000).default(100),lat:z.coerce.number().min(-90).max(90).default(-17.805),lng:z.coerce.number().min(-180).max(180).default(31.045),radius:z.coerce.number().min(.1).max(100).default(20)}).parse(req.query);if(mode==='demo')return res.json(searchBarbers(barbers,q));const {data,error}=await clients().rpc('search_barbers',{p_lat:q.lat,p_lng:q.lng,p_radius:q.radius,p_service:q.service??null,p_max_price:q.maxPrice});if(error)throw error;res.json(data);});
 app.get('/barbers/:id/availability',async(req,res)=>{const id=uuid.parse(req.params.id);const q=z.object({date,service:z.enum(services)}).parse(req.query);if(mode==='demo')return res.json(store.slots(id,q.date,q.service));const {data,error}=await clients().rpc('available_slots',{p_barber:id,p_date:q.date,p_service:q.service});if(error)throw error;res.json(data);});
 app.use(async(req,res,next)=>{if(mode==='demo'){req.userId='demo-customer';return next();}const token=req.headers.authorization?.replace(/^Bearer /,'');if(!token)return res.status(401).json({message:'Please sign in to continue.'});const db=clients(token);const {data,error}=await db.auth.getUser(token);if(error||!data.user)return res.status(401).json({message:'Your session has expired. Please sign in again.'});req.userId=data.user.id;req.db=db;next();});
 app.get('/bookings',async(req,res)=>{if(mode==='demo')return res.json(store.bookings.filter(b=>b.userId===req.userId));const {data,error}=await req.db.from('bookings').select('*').order('start',{ascending:true});if(error)throw error;res.json(data);});
 app.post('/bookings',async(req,res)=>{const body=z.object({barberId:uuid,service:z.enum(services),start:z.iso.datetime({offset:true})}).parse(req.body);if(mode==='demo')return res.status(201).json(store.book(body,req.userId));const {data,error}=await req.db.rpc('create_booking',{p_barber:body.barberId,p_service:body.service,p_start:body.start});if(error){if(error.code==='23P01'||error.code==='P0001')return res.status(409).json({message:'That appointment is unavailable. Refresh and choose another slot.'});throw error;}res.status(201).json(data);});
 app.post('/bookings/:id/cancel',async(req,res)=>{const id=uuid.parse(req.params.id);if(mode==='demo'){const booking=store.bookings.find(b=>b.id===id&&b.userId===req.userId);if(!booking)return res.status(404).json({message:'Booking not found.'});if(booking.status!=='confirmed'||+new Date(booking.start)<=Date.now())return res.status(409).json({message:'This booking cannot be cancelled.'});booking.status='cancelled';return res.json(booking);}const {data,error}=await req.db.rpc('cancel_booking',{p_booking:id});if(error)return res.status(409).json({message:'This booking cannot be cancelled.'});res.json(data);});
 app.use((_req,res)=>res.status(404).json({message:'Not found.'}));
 app.use((err,_req,res,_next)=>{if(err instanceof z.ZodError)return res.status(400).json({message:'Check your request fields.',issues:err.issues});if(err.type==='entity.parse.failed')return res.status(400).json({message:'Invalid JSON.'});if(err.status)return res.status(err.status).json({message:err.message});console.error('Request failed',{code:err.code??'internal'});res.status(500).json({message:'Something went wrong. Please try again.'});});return app;
}
