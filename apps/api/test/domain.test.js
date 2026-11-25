import test from 'node:test';
import assert from 'node:assert/strict';
import {barbers,DemoStore,searchBarbers} from '../src/domain.js';

test('nearby search combines radius, haircut and budget',()=>{
 const found=searchBarbers(barbers,{service:'Skin fade',maxPrice:8,lat:-17.790,lng:31.033,radius:1});
 assert.equal(found.length,1);
 assert.equal(found[0].name,'Tendai Moyo');
 assert.deepEqual(found[0].services.map(s=>s.name),['Skin fade']);
 assert.equal(searchBarbers(barbers,{maxPrice:0}).length,0);
});

test('service duration prevents adjacent overlapping appointments',()=>{
 const store=new DemoStore();const id=barbers[0].id;
 const start=store.slots(id,'2099-01-02','Skin fade')[0];
 const booking=store.book({barberId:id,service:'Skin fade',start},'customer-a');
 assert.throws(()=>store.book({barberId:id,service:'Skin fade',start},'customer-b'),/no longer available/);
 const overlap=new Date(+new Date(start)+30*60000).toISOString();
 assert(!store.slots(id,'2099-01-02','Classic cut').includes(overlap));
 booking.status='cancelled';
 assert(store.slots(id,'2099-01-02','Skin fade').includes(start));
});

test('bookings retain their price when the service catalog changes',()=>{
 const store=new DemoStore();const barber=barbers[0];const service=barber.services[0];
 const start=store.slots(barber.id,'2099-01-03',service.name)[0];
 const booked=store.book({barberId:barber.id,service:service.name,start},'customer-a');
 const price=service.price;
 try{service.price=price+10;assert.equal(booked.price,price);}finally{service.price=price;}
});
