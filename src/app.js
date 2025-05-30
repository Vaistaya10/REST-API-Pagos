import express from 'express';
import pagosRoutes from './routes/pagos.routes.js';

const app = express();
app.use(express.json());
app.use('/api/', pagosRoutes);
export default app;