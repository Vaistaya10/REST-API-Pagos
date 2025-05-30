import { pool } from '../db.js';

export const getAllPagos = async (req, res) => {
  try {
    const querySQL = ` CALL spGetPagosByContrato(?)`;
    const [rows] = await pool.query(querySQL);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: 'Error al obtener los pagos' });
  }
}

export const registerPago = async (req, res) => {
  try {
    const { idcontrato, numcuota,fechaPago, monto, penalidad,medio } = req.body;
    if (monto <= 0) {
      return res.status(400).json({
        status: false,
        message: 'El monto debe ser mayor a 0'
      });
    }
    const querySQL = `CALL spInsertPago(?,?,?, ?, ?, ?)`;
    const [results] = await pool.query(querySQL, [idcontrato,numcuota, fechaPago, monto, penalidad,medio]);


    if (results.affectedRows = 0) {
      res.send({
        status: false,
        message: "No se pudo completar el proceso",
        id: null
      })
    } else {
      res.send({
        status : true,
        message : "Registrado correctamente"
      })
    }
  } catch {
    console.error("No se pudo concretar POST")
  }
}

