import { Router } from 'express';
import {
  getPagosByContrato,
  registerPagoConPenalidad,
  getPagosRealizadosPorContrato,
  getPagosPendientesPorContrato
} from '../controllers/pagos.controller.js';

const router = Router();

/**
 * Rutas para pagos:
 * ---------------------------------------------
 * GET    /api/pagos/contrato/:idcontrato
 * POST   /api/pagos/contrato/:idcontrato/cuota/:numcuota
 * GET    /api/pagos/contrato/:idcontrato/realizados
 * GET    /api/pagos/contrato/:idcontrato/pendientes
 */

router.get('/pagos/contrato/:idcontrato', getPagosByContrato);
router.post('/pagos/contrato/:idcontrato/cuota/:numcuota', registerPagoConPenalidad);
router.get('/pagos/contrato/:idcontrato/realizados', getPagosRealizadosPorContrato);
router.get('/pagos/contrato/:idcontrato/pendientes', getPagosPendientesPorContrato);

export default router;
