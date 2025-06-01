import { pool } from '../db.js';

/**
 * GET /api/pagos/contrato/:idcontrato
 * Devuelve TODO el cronograma (pagos pagados + pendientes) para un contrato.
 * SP: spGetPagosByContrato(_idcontrato)
 */
export const getPagosByContrato = async (req, res) => {
  try {
    const idcontrato = parseInt(req.params.idcontrato);
    if (isNaN(idcontrato)) {
      return res.status(400).json({ message: 'ID de contrato inválido' });
    }

    const [rows] = await pool.query('CALL spGetPagosByContrato(?);', [idcontrato]);
    return res.json(rows[0]);
  } catch (error) {
    console.error('Error en getPagosByContrato:', error);
    return res.status(500).json({ message: 'Error al obtener cronograma de pagos' });
  }
};

/**
 * POST /api/pagos/contrato/:idcontrato/cuota/:numcuota
 * Registra el pago de una cuota específica, aplicando penalidad diaria y cerrando el contrato si corresponde.
 * Body: { medio }  // 'EFC' o 'DEP'
 * SP: spRegisterPagoConPenalidad(_idcontrato, _numcuota, _fechaPago, _medio)
 */
export const registerPagoConPenalidad = async (req, res) => {
  try {
    const idcontrato = parseInt(req.params.idcontrato);
    const numcuota = parseInt(req.params.numcuota);
    const { medio } = req.body;
    const fechaPago = new Date(); // Hora actual

    if (isNaN(idcontrato) || isNaN(numcuota)) {
      return res.status(400).json({ message: 'ID de contrato o número de cuota inválido' });
    }
    if (medio !== 'EFC' && medio !== 'DEP') {
      return res.status(400).json({ message: 'Medio de pago inválido (usar "EFC" o "DEP")' });
    }

    // Llamar al SP que registra el pago con penalidad y cierra contrato si es la última cuota
    await pool.query(
      'CALL spRegisterPagoConPenalidad(?,?,?,?);',
      [idcontrato, numcuota, fechaPago, medio]
    );

    return res.json({ status: true, message: 'Pago registrado correctamente' });
  } catch (error) {
    console.error('Error en registerPagoConPenalidad:', error);
    return res.status(500).json({ message: 'Error al registrar el pago' });
  }
};

/**
 * GET /api/pagos/contrato/:idcontrato/realizados
 * Devuelve todos los pagos realizados para un contrato + total pagado.
 * SP: spGetPagosRealizadosPorContrato(_idcontrato)
 */
export const getPagosRealizadosPorContrato = async (req, res) => {
  try {
    const idcontrato = parseInt(req.params.idcontrato);
    if (isNaN(idcontrato)) {
      return res.status(400).json({ message: 'ID de contrato inválido' });
    }

    const [rows] = await pool.query('CALL spGetPagosRealizadosPorContrato(?);', [idcontrato]);
    // El SP devuelve dos resultsets:
    // rows[0] = filas de pagos realizados
    // rows[1] = [{ total_pagado: X }]
    const pagosRealizados = rows[0];
    const totalPagado = rows[1][0]?.total_pagado || 0;
    return res.json({ pagosRealizados, totalPagado });
  } catch (error) {
    console.error('Error en getPagosRealizadosPorContrato:', error);
    return res.status(500).json({ message: 'Error al obtener pagos realizados' });
  }
};

/**
 * GET /api/pagos/contrato/:idcontrato/pendientes
 * Devuelve todos los pagos pendientes (fechapago IS NULL) para un contrato + total pendiente.
 * SP: spGetPagosPendientesPorContrato(_idcontrato)
 */
export const getPagosPendientesPorContrato = async (req, res) => {
  try {
    const idcontrato = parseInt(req.params.idcontrato);
    if (isNaN(idcontrato)) {
      return res.status(400).json({ message: 'ID de contrato inválido' });
    }

    const [rows] = await pool.query('CALL spGetPagosPendientesPorContrato(?);', [idcontrato]);
    // rows[0] = filas pendientes, rows[1] = [{ total_pendiente: Y }]
    const pagosPendientes = rows[0];
    const totalPendiente = rows[1][0]?.total_pendiente || 0;
    return res.json({ pagosPendientes, totalPendiente });
  } catch (error) {
    console.error('Error en getPagosPendientesPorContrato:', error);
    return res.status(500).json({ message: 'Error al obtener pagos pendientes' });
  }
};
