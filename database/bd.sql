create database prestamos;
use prestamos;

create table beneficiarios(
idbeneficiario 	int 		auto_increment primary key,
apellidos 		varchar(50) not null,
nombres 		varchar(50) not null,
dni				char(8) 	not null,
telefono 		char(9) 	not null,
direccion 		varchar(90) not null,
creado 			datetime 	not null default now(),
modificado 		datetime    not null,
constraint uk_dni_ben unique (dni)
)engine = innodb;

create table contratos(
idcontrato 	    int 			auto_increment primary key,
idbeneficiario 	int 			not null,
monto 			decimal(7,2) 	not null,
interes 		decimal(5,2) 	not null,
fechainicio 	date 			not null,
diapago 		tinyint 		not null,
numcuotas 		tinyint 		not null comment 'expresado en meses',
estado 			enum('ACT','FIN') not null default 'ACT' comment 'ACT = Activo, FIN = Finalizo',
creado 			datetime 	not null default now(),
modificado 		datetime    not null,
constraint fk_idbeneficiario_con foreign key (idbeneficiario) references beneficiarios (idbeneficiario)
)engine = innodb;

create table pagos(
idpago 			int 				auto_increment primary key,
idcontrato 		int 				not null,
numcuota		tinyint 			not null comment 'se debe cancelar la cuota en su totalidad sin AMORTIZACIONES',
fechapago 		datetime 			null comment 'esta es la fecha efectiva de pago',
monto 			decimal(7,2) 		not null,
penalidad 		decimal(7,2) 		not null default 0 comment '10% valor cuota',
medio 			enum('EFC','DEP')	NULL comment 'EFC = Efectivo, DEP = Depósito',
constraint fk_idcontrato_pag foreign key (idcontrato) references contratos (idcontrato),
constraint uk_numcuota_pag unique (idcontrato,numcuota)
) engine = innodb;

insert into beneficiarios (apellidos, nombres, dni, telefono) values 
('Tasayco Yataco', 'Valentino Ismael', '76180741', '956633983');

insert into beneficiarios(apellidos,nombres,dni,telefono) values
('Tasayco Yataco','Yohies Lisbeth','80085333','912468430');

insert into contratos (idbeneficiario,monto, interes,fechainicio,diapago,numcuotas) values
(1,3000,5,'2025-03-10',15,12);

insert into contratos (idbeneficiario,monto,interes,fechainicio,diapago,numcuotas) values
(2,3000,5,'2025-03-10',15,12);
-- cronograma de 12 pagos
insert into pagos (idcontrato,numcuota,fechapago,monto,penalidad,medio) values
(1,1,'2025-04-15',338.48,0,'EFC'),
(1,2,'2025-05-17',338.48,33.85,'DEP'),
(1,3,NULL,338.48,0,NULL),
(1,4,NULL,338.48,0,NULL),
(1,5,NULL,338.48,0,NULL),
(1,6,NULL,338.48,0,NULL),
(1,7,NULL,338.48,0,NULL),
(1,8,NULL,338.48,0,NULL),
(1,9,NULL,338.48,0,NULL),
(1,10,NULL,338.48,0,NULL),
(1,11,NULL,338.48,0,NULL),
(1,12,NULL,338.48,0,NULL);

-- cuantos pagos tiene pendiente yo?
select count(*) from pagos where idcontrato = 1 AND fechapago IS NULL;

-- cuanto es el total de la deuda actual?
select count(*) * 10 from pagos where idcontrato = 1 AND fechapago IS NULL;

-- cuantos pagos se ha realizado?
select count(*) from pagos where idcontrato = 1 AND fechapago IS NOT NULL;

-- cuantos pagos se realizaron en efectivo?
select count(*) from pagos where idcontrato = 1 AND medio = 'EFC';

-- cuanto es el total de penalidades pagadas con deposito?
select SUM(penalidad) from pagos where idcontrato = 1 AND medio = 'DEP';