import { pool } from '../db.js';

/**
 * GET /api/beneficiarios
 * Devuelve la lista de todos los beneficiarios junto con su contrato más reciente, si existe.
 * SP: spGetBeneficiariosContrato()
 */
export const getBeneficiariosContrato = async (req, res) => {
  try {
    const [rows] = await pool.query('CALL spGetBeneficiariosContrato()');
    // El SP devuelve un solo resultset: rows[0]
    return res.json(rows[0]);
  } catch (error) {
    console.error('Error en getBeneficiariosContrato:', error);
    return res.status(500).json({ message: 'Error al obtener beneficiarios' });
  }
};

/**
 * POST /api/beneficiarios
 * Crea un nuevo beneficiario.
 * Body: { apellidos, nombres, dni, telefono, direccion }
 * SP: spCreateBeneficiario(...)
 */
export const createBeneficiario = async (req, res) => {
  try {
    const { apellidos, nombres, dni, telefono, direccion } = req.body;

    // Validaciones básicas
    if (!apellidos || !nombres || !dni || !telefono) {
      return res.status(400).json({ message: 'Faltan datos requeridos' });
    }
    if (dni.length !== 8) {
      return res.status(400).json({ message: 'El DNI debe tener 8 caracteres' });
    }

    const [result] = await pool.query(
      'CALL spCreateBeneficiario(?,?,?,?,?);',
      [apellidos, nombres, dni, telefono, direccion || '']
    );

    // result.affectedRows no funciona con CALL; podemos asumir que si no hay error, se ingresó correctamente.
    return res.status(201).json({ 
      status: true,
      message: 'Beneficiario creado exitosamente'
    });
  } catch (error) {
    console.error('Error en createBeneficiario:', error);
    // Si se violó la restricción UNIQUE (dni duplicado), mysql devuelve un código 1062
    if (error && error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'El DNI ya existe en la base de datos' });
    }
    return res.status(500).json({ message: 'Error al crear beneficiario' });
  }
};

/**
 * POST /api/beneficiarios/login
 * Inicia sesión con DNI. Si existe, devuelve datos del beneficiario.
 * Body: { dni }
 * SP: spLoginBeneficiario(_dni)
 */
export const loginBeneficiario = async (req, res) => {
  try {
    const { dni } = req.body;
    if (!dni || dni.length !== 8) {
      return res.status(400).json({ message: 'DNI inválido' });
    }

    const [rows] = await pool.query('CALL spLoginBeneficiario(?);', [dni]);
    const usuario = rows[0][0];
    if (!usuario) {
      return res.status(401).json({ message: 'DNI no encontrado' });
    }

    // Podrías generar un token aquí; por simplicidad devolvemos solo id y nombre.
    return res.json({
      idbeneficiario: usuario.idbeneficiario,
      apellidos: usuario.apellidos,
      nombres: usuario.nombres,
      dni: usuario.dni
    });
  } catch (error) {
    console.error('Error en loginBeneficiario:', error);
    return res.status(500).json({ message: 'Error en login' });
  }
};

/**
 * GET /api/beneficiarios/:id/contrato-activo
 * Obtiene el contrato activo (estado='ACT') de un beneficiario.
 * SP: spGetContratoActivoPorBeneficiario(_idbeneficiario)
 */
export const getContratoActivo = async (req, res) => {
  try {
    const idbeneficiario = parseInt(req.params.id);
    if (isNaN(idbeneficiario)) {
      return res.status(400).json({ message: 'ID de beneficiario inválido' });
    }

    const [rows] = await pool.query(
      'CALL spGetContratoActivoPorBeneficiario(?);',
      [idbeneficiario]
    );
    const contrato = rows[0][0];
    if (!contrato) {
      return res.status(404).json({ message: 'No existe contrato activo para este beneficiario' });
    }
    return res.json(contrato);
  } catch (error) {
    console.error('Error en getContratoActivo:', error);
    return res.status(500).json({ message: 'Error al obtener contrato activo' });
  }
};

/**
 * GET /api/beneficiarios/:id/contratos
 * Muestra el historial completo de contratos de un beneficiario.
 * SP: spGetContratosPorBeneficiario(_idbeneficiario)
 */
export const getContratosPorBeneficiario = async (req, res) => {
  try {
    const idbeneficiario = parseInt(req.params.id);
    if (isNaN(idbeneficiario)) {
      return res.status(400).json({ message: 'ID de beneficiario inválido' });
    }

    const [rows] = await pool.query(
      'CALL spGetContratosPorBeneficiario(?);',
      [idbeneficiario]
    );
    return res.json(rows[0]);
  } catch (error) {
    console.error('Error en getContratosPorBeneficiario:', error);
    return res.status(500).json({ message: 'Error al obtener contratos del beneficiario' });
  }
};

/**
 * POST /api/beneficiarios/:id/contratos
 * Crea un nuevo contrato para un beneficiario dado. Luego genera el cronograma.
 * Body: { monto, interes, fechainicio, diapago, numcuotas }
 * SP: spCreateContrato(...) + spGenerarCronograma(...)
 */
export const createContrato = async (req, res) => {
  try {
    const idbeneficiario = parseInt(req.params.id);
    const { monto, interes, fechainicio, diapago, numcuotas } = req.body;

    // Validaciones básicas
    if (
      isNaN(idbeneficiario) ||
      !monto || isNaN(monto) ||
      !interes || isNaN(interes) ||
      !fechainicio ||
      isNaN(parseInt(diapago)) ||
      isNaN(parseInt(numcuotas))
    ) {
      return res.status(400).json({ message: 'Datos de contrato inválidos' });
    }

    // 1) Insertar nuevo contrato
    await pool.query(
      'CALL spCreateContrato(?,?,?,?,?,?);',
      [idbeneficiario, monto, interes, fechainicio, diapago, numcuotas]
    );

    // 2) Obtener el ID del contrato recién creado
    const [[{ idcontrato }]] = await pool.query('SELECT LAST_INSERT_ID() AS idcontrato;');

    // 3) Generar cronograma (inserta N filas en la tabla pagos)
    await pool.query(
      'CALL spGenerarCronograma(?,?,?,?,?);',
      [idcontrato, fechainicio, diapago, numcuotas, monto]
    );

    return res
      .status(201)
      .json({ status: true, message: 'Contrato creado y cronograma generado', idcontrato });
  } catch (error) {
    console.error('Error en createContrato:', error);
    return res.status(500).json({ message: 'Error al crear contrato' });
  }
};
