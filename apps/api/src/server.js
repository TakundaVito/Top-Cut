import {createApp} from './app.js';
const port=Number(process.env.PORT??4000);
createApp().listen(port,'0.0.0.0',()=>console.log(`ClipNear API ready on port ${port} (${process.env.DATA_MODE??'demo'} mode)`));
