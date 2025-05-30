import { Router } from 'express';
import { getAllPagos,registerPago  } from '../controllers/pagos.controller.js';

const router = Router();

router.get('/pagos/:idcontrato', getAllPagos);
router.post('/pagos', registerPago);

export default router;