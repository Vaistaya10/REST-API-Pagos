import express from 'express';
import beneficiarioRoutes from './routes/beneficiario.routes.js';
import pagosRoutes from './routes/pagos.routes.js';

const app = express();

// Habilitar recepción de JSON en los cuerpos de las peticiones
app.use(express.json());

// Prefijo para todas las rutas de la API
app.use('/api', beneficiarioRoutes);
app.use('/api', pagosRoutes);

// Ruta raíz simple para verificar que el servidor está vivo
app.get('/', (req, res) => {
  res.json({ message: 'API REST de Préstamos en funcionamiento' });
});

export default app;
