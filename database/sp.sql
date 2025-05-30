use prestamos;
call spGenerarCronograma(2,null);
-- select * from pagos where idcontrato = 2;
DROP PROCEDURE IF EXISTS spGenerarCronograma;
DELIMITER $$
CREATE PROCEDURE spGenerarCronograma(
  IN _idcontrato     INT,
  IN _cuotainicial  DECIMAL(12,2)  -- puede pasar NULL o 0 si no hay pago inicial
)
BEGIN
  DECLARE _montoTotal     DECIMAL(12,2);
  DECLARE _numCuotas      INT;
  DECLARE _interesAnual   DECIMAL(5,2);
  DECLARE _fechaInicio    DATE;
  DECLARE _tasaMensual    DECIMAL(12,8);
  DECLARE _montoFinanciar DECIMAL(12,2);
  DECLARE _cuotaMensual   DECIMAL(12,2);
  DECLARE _saldoCapital   DECIMAL(12,2);
  DECLARE _interesMes     DECIMAL(12,2);
  DECLARE _abonoCapital   DECIMAL(12,2);
  DECLARE _baseImponible  DECIMAL(12,2);
  DECLARE _igv            DECIMAL(12,2);
  DECLARE _fechaPago      DATE;
  DECLARE _contador       INT DEFAULT 1;

  -- 0) Si no pasaron cuota inicial, la dejamos en cero
  IF _cuotainicial IS NULL THEN
    SET _cuotainicial = 0;
  END IF;

  -- 1) Recuperar datos del contrato activo
  SELECT monto, interes, fechainicio, numcuotas
    INTO _montoTotal, _interesAnual, _fechaInicio, _numCuotas
  FROM contratos
  WHERE idcontrato = _idcontrato
    AND estado = 'ACT';

  -- 2) Calcular tasa y montos
  SET _tasaMensual    = POW(1 + _interesAnual/100, 1/12) - 1;
  SET _montoFinanciar = _montoTotal - _cuotainicial;

  IF _tasaMensual = 0 THEN
    SET _cuotaMensual = _montoFinanciar / _numCuotas;
  ELSE
    SET _cuotaMensual = (_montoFinanciar * _tasaMensual)
      / (1 - POW(1 + _tasaMensual, -_numCuotas));
  END IF;

  SET _saldoCapital = _montoFinanciar;

  -- 3) Fila 0: saldo antes de pagar primera cuota
  SELECT
    0                    AS numcuota,
    _fechaInicio        AS fecha,
    NULL                 AS base_imponible,
    NULL                 AS igv,
    NULL                 AS interes,
    NULL                 AS abono_capital,
    NULL                 AS cuota,
    ROUND(_saldoCapital, 2) AS saldo_capital;

  -- 4) Generar cada cuota
  WHILE _contador <= _numCuotas DO
    SET _fechaPago = DATE_ADD(_fechaInicio, INTERVAL _contador MONTH);
    SET _interesMes   = _tasaMensual * _saldoCapital;
    SET _abonoCapital = _cuotaMensual - _interesMes;

    -- si es la última cuota, lleva todo lo que quede de capital
    IF _contador = _numCuotas THEN
      SET _abonoCapital = _abonoCapital + _saldoCapital;
    END IF;

    SET _saldoCapital = _saldoCapital - _abonoCapital;
    SET _baseImponible = _interesMes / 1.18;
    SET _igv           = _baseImponible * 0.18;

    SELECT
      _contador                    AS numcuota,
      _fechaPago                   AS fecha,
      ROUND(_baseImponible, 2)     AS base_imponible,
      ROUND(_igv, 2)               AS igv,
      ROUND(_interesMes, 2)        AS interes,
      ROUND(_abonoCapital, 2)      AS abono_capital,
      ROUND(_cuotaMensual, 2)      AS cuota,
      ROUND(_saldoCapital, 2)      AS saldo_capital;

    SET _contador = _contador + 1;
  END WHILE;

END$$
DELIMITER ;


