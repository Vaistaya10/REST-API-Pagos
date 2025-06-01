import { Router } from 'express';
import {
  getBeneficiariosContrato,
  createBeneficiario,
  loginBeneficiario,
  getContratoActivo,
  getContratosPorBeneficiario,
  createContrato
} from '../controllers/beneficiario.controller.js';

const router = Router();

/**
 * Rutas para beneficiarios:
 * ---------------------------------------------
 * GET    /api/beneficiarios
 * POST   /api/beneficiarios
 * POST   /api/beneficiarios/login
 * GET    /api/beneficiarios/:id/contrato-activo
 * GET    /api/beneficiarios/:id/contratos
 * POST   /api/beneficiarios/:id/contratos
 */

router.get('/beneficiarios', getBeneficiariosContrato);
router.post('/beneficiarios', createBeneficiario);
router.post('/beneficiarios/login', loginBeneficiario);
router.get('/beneficiarios/:id/contrato-activo', getContratoActivo);
router.get('/beneficiarios/:id/contratos', getContratosPorBeneficiario);
router.post('/beneficiarios/:id/contratos', createContrato);

export default router;
