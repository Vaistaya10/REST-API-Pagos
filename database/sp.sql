USE prestamos;

DELIMITER $$
DROP PROCEDURE IF EXISTS spGetBeneficiariosContrato $$
CREATE PROCEDURE spGetBeneficiariosContrato()
BEGIN
  SELECT
    b.idbeneficiario,
    b.apellidos,
    b.nombres,
    b.dni,
    b.telefono,
    b.direccion,
    c.contrato_reciente,
    c.fechainicio
  FROM beneficiarios AS b
  LEFT JOIN (
    SELECT
      idbeneficiario,
      idcontrato AS contrato_reciente,
      fechainicio
    FROM contratos
    WHERE (idbeneficiario, fechainicio) IN (
      SELECT
        idbeneficiario,
        MAX(fechainicio) AS fechainicio
      FROM contratos
      GROUP BY idbeneficiario
    )
  ) AS c
    ON b.idbeneficiario = c.idbeneficiario
  ORDER BY b.apellidos, b.nombres;
END $$

DROP PROCEDURE IF EXISTS spGetContratosActivos $$
CREATE PROCEDURE spGetContratosActivos()
BEGIN
  SELECT
    c.idcontrato,
    b.idbeneficiario,
    CONCAT(b.apellidos, ', ', b.nombres) AS beneficiario,
    c.monto,
    c.interes,
    c.fechainicio,
    c.diapago,
    c.numcuotas
  FROM contratos AS c
  JOIN beneficiarios AS b
    ON c.idbeneficiario = b.idbeneficiario
  WHERE c.estado = 'ACT'
  ORDER BY c.fechainicio DESC;
END $$


DROP PROCEDURE IF EXISTS spGetContratoById $$
CREATE PROCEDURE spGetContratoById(
  IN p_idcontrato INT
)
BEGIN
  SELECT
    idcontrato,
    idbeneficiario,
    monto,
    interes,
    fechainicio,
    diapago,
    numcuotas,
    estado
  FROM contratos
  WHERE idcontrato = p_idcontrato;
END $$
-- select * from beneficiarios
-- call spCreateBeneficiario('ejemplo','ejemplo','88888888','999999999','su casa')
DROP PROCEDURE IF EXISTS spCreateBeneficiario $$
CREATE PROCEDURE spCreateBeneficiario(
  IN _apellidos VARCHAR(50),
  IN _nombres   VARCHAR(50),
  IN _dni       CHAR(8),
  IN _telefono  CHAR(9),
  IN _direccion VARCHAR(90)
)
BEGIN
  INSERT INTO beneficiarios
    (apellidos, nombres, dni, telefono, direccion, creado)
  VALUES
    (_apellidos, _nombres, _dni, _telefono, _direccion, NOW());
END$$

DROP PROCEDURE IF EXISTS spCreateContrato $$
CREATE PROCEDURE spCreateContrato(
  IN _idbeneficiario INT,
  IN _monto          DECIMAL(7,2),
  IN _interes        DECIMAL(5,2),
  IN _fechainicio    DATE,
  IN _diapago        TINYINT,
  IN _numcuotas      TINYINT
)
BEGIN
  INSERT INTO contratos
    (idbeneficiario, monto, interes, fechainicio, diapago, numcuotas, estado, creado)
  VALUES
    (_idbeneficiario, _monto, _interes, _fechainicio, _diapago, _numcuotas, 'ACT', NOW());
END $$

-- call spGetPagosByContrato(1)

DROP PROCEDURE IF EXISTS spRegisterPago $$
CREATE PROCEDURE spRegisterPago(
  IN  _idcontrato  INT,
  IN  _numcuota    TINYINT,
  IN  _fechapago   DATETIME,
  IN  _monto       DECIMAL(7,2),
  IN  _penalidad   DECIMAL(7,2),
  IN  _medio       ENUM('EFC','DEP')
)
BEGIN
  INSERT INTO pagos
    (idcontrato, numcuota, fechapago, monto, penalidad, medio)
  VALUES
    (_idcontrato, _numcuota, _fechapago, _monto, _penalidad, _medio);
END $$


DROP PROCEDURE IF EXISTS spLoginBeneficiario $$
CREATE PROCEDURE spLoginBeneficiario(
  IN _dni CHAR(8)
)
BEGIN
  SELECT
    idbeneficiario,
    apellidos,
    nombres,
    dni
  FROM beneficiarios
  WHERE dni = _dni;
END$$

DROP PROCEDURE IF EXISTS spGetContratoActivoPorBeneficiario $$
CREATE PROCEDURE spGetContratoActivoPorBeneficiario(
  IN _idbeneficiario INT
)
BEGIN
  SELECT
    idcontrato,
    idbeneficiario,
    monto,
    interes,
    fechainicio,
    diapago,
    numcuotas,
    estado
  FROM contratos
  WHERE idbeneficiario = _idbeneficiario
    AND estado = 'ACT'
  LIMIT 1;
END $$


DROP PROCEDURE IF EXISTS spGetPagosByContrato $$
CREATE PROCEDURE spGetPagosByContrato(
  IN _idcontrato INT
)
BEGIN
  SELECT
    idpago,
    idcontrato,
    numcuota,
    fechapago,
    monto,
    penalidad,
    medio
  FROM pagos
  WHERE idcontrato = _idcontrato
  ORDER BY numcuota;
END $$

DROP PROCEDURE IF EXISTS spGetPagosRealizadosPorContrato $$
CREATE PROCEDURE spGetPagosRealizadosPorContrato(
  IN _idcontrato INT
)
BEGIN
  -- 1) Lista de cuotas ya pagadas
  SELECT
    idpago,
    numcuota,
    fechapago,
    monto,
    penalidad,
    medio
  FROM pagos
  WHERE idcontrato = _idcontrato
    AND fechapago IS NOT NULL
  ORDER BY numcuota;

  -- 2) Total pagado (monto + penalidad) hasta la fecha
  SELECT
    IFNULL(SUM(monto + penalidad), 0) AS total_pagado
  FROM pagos
  WHERE idcontrato = _idcontrato
    AND fechapago IS NOT NULL;
END $$

DROP PROCEDURE IF EXISTS spGetPagosPendientesPorContrato $$
CREATE PROCEDURE spGetPagosPendientesPorContrato(
  IN _idcontrato INT
)
BEGIN
  -- 1) Filas pendientes (fechapago IS NULL)
  SELECT
    idpago,
    numcuota,
    monto
  FROM pagos
  WHERE idcontrato = _idcontrato
    AND fechapago IS NULL
  ORDER BY numcuota;

  -- 2) Sumatoria de lo pendiente (solo monto)
  SELECT
    IFNULL(SUM(monto), 0) AS total_pendiente
  FROM pagos
  WHERE idcontrato = _idcontrato
    AND fechapago IS NULL;
END $$


DROP PROCEDURE IF EXISTS spRegisterPagoConPenalidad $$
CREATE PROCEDURE spRegisterPagoConPenalidad(
  IN _idcontrato INT,
  IN _numcuota   TINYINT,
  IN _fechaPago  DATETIME,
  IN _medio      ENUM('EFC','DEP')
)
BEGIN
  DECLARE montoCuota       DECIMAL(7,2);
  DECLARE fechaVenc        DATE;
  DECLARE diaPagoContrato   TINYINT;
  DECLARE fechaBase         DATE;
  DECLARE pen               DECIMAL(7,2);
  DECLARE diasAtraso        INT;
  DECLARE totalPendientes   INT;

  -- 1) Obtener el monto de la cuota desde la tabla `pagos` (cronograma generado):
  SELECT monto
    INTO montoCuota
  FROM pagos
  WHERE idcontrato = _idcontrato
    AND numcuota   = _numcuota;

  -- 2) Obtener la fecha de inicio y el día de pago del contrato
  SELECT fechainicio, diapago
    INTO fechaBase, diaPagoContrato
  FROM contratos
  WHERE idcontrato = _idcontrato;

  -- 3) Calcular la fecha de vencimiento de la cuota:
  --    fechainicio + (numcuota - 1) meses, forzando día = diapago
  SET fechaVenc = DATE_ADD(fechaBase, INTERVAL (_numcuota - 1) MONTH);
  SET fechaVenc = STR_TO_DATE(
    CONCAT(
      YEAR(fechaVenc), '-',
      LPAD(diaPagoContrato, 2, '0'), '-',
      LPAD(DAY(fechaVenc), 2, '0')
    ), '%Y-%m-%d'
  );

  -- 4) Calcular días de atraso (solo si se pasa de la medianoche del día vencido)
  IF _fechaPago > CONCAT(fechaVenc, ' 23:59:59') THEN
    SET diasAtraso = DATEDIFF(DATE(_fechaPago), fechaVenc);
    SET pen = ROUND(diasAtraso * (0.10 * montoCuota), 2);
  ELSE
    SET pen = 0;
  END IF;

  -- 5) Actualizar la fila de pagos (cronograma preexistente) para marcarla como pagada
  UPDATE pagos
     SET fechapago = _fechaPago,
         penalidad = pen,
         medio     = _medio
   WHERE idcontrato = _idcontrato
     AND numcuota   = _numcuota
     AND fechapago  IS NULL;  -- evita doble pago

  -- 6) Verificar si ya no quedan cuotas pendientes; si no quedan, cerrar el contrato
  SELECT COUNT(*) 
    INTO totalPendientes
  FROM pagos
  WHERE idcontrato = _idcontrato
    AND fechapago IS NULL;

  IF totalPendientes = 0 THEN
    UPDATE contratos
       SET estado = 'FIN',
           modificado = NOW()
     WHERE idcontrato = _idcontrato;
  END IF;
END $$

DROP PROCEDURE IF EXISTS spGetContratosPorBeneficiario $$
CREATE PROCEDURE spGetContratosPorBeneficiario(
  IN _idbeneficiario INT
)
BEGIN
  SELECT
    idcontrato,
    monto,
    interes,
    fechainicio,
    diapago,
    numcuotas,
    estado,
    creado,
    modificado
  FROM contratos
  WHERE idbeneficiario = _idbeneficiario
  ORDER BY fechainicio DESC;
END$$

DROP PROCEDURE IF EXISTS spGenerarCronograma $$
CREATE PROCEDURE spGenerarCronograma(
  IN _idcontrato   INT,
  IN _fechaInicio  DATE,
  IN _diapago      TINYINT,
  IN _numcuotas    TINYINT,
  IN _montoTotal   DECIMAL(7,2)
)
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE fechaCuota DATE;
  DECLARE montoCuota DECIMAL(7,2);

  -- Dividir el monto total entre numcuotas para obtener el valor fijo de cada cuota
  SET montoCuota = ROUND(_montoTotal / _numcuotas, 2);

  WHILE i <= _numcuotas DO
    -- 1) Calcular la fecha base: fechainicio + (i - 1) meses
    SET fechaCuota = DATE_ADD(_fechaInicio, INTERVAL (i - 1) MONTH);

    -- 2) Ajustar la fecha al día de pago (_diapago)
    SET fechaCuota = STR_TO_DATE(
      CONCAT(
        YEAR(fechaCuota), '-',
        LPAD(_diapago, 2, '0'), '-',
        LPAD(DAY(fechaCuota), 2, '0')
      ), '%Y-%m-%d'
    );

    -- 3) Insertar la cuota “pendiente”
    INSERT INTO pagos (
      idcontrato,
      numcuota,
      fechapago,    -- NULL porque aún no se ha pagado
      monto,
      penalidad,    -- 0 por defecto
      medio         -- NULL por defecto
    ) VALUES (
      _idcontrato,
      i,
      NULL,
      montoCuota,
      0,
      NULL
    );

    SET i = i + 1;
  END WHILE;
END $$



