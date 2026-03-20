# Oracle Stats Automation 📊

Este repositorio contiene una solución personalizada en **PL/SQL** para la recolección de estadísticas de objetos en bases de datos Oracle (específicamente probado en entornos Data Warehouse). 

Esta herramienta fue diseñada para resolver escenarios donde el job nativo de Oracle (`auto optimizer stats collection`) es insuficiente debido a ventanas de tiempo restringidas o volúmenes masivos de datos.

## 🛠️ Componentes de la Solución

1. **Tabla de Bitácora:** Registro detallado de cada ejecución (inicio, fin, duración, estado).
2. **Procedimiento PL/SQL:** Lógica inteligente que diferencia entre tablas planas y particionadas, priorizando la última partición vigente.
3. **Oracle Scheduler Job:** Configuración del job interno para ejecución diaria a las 08:00 PM.

## 📋 Requisitos
- Oracle Database 12c o superior (Probado en 19c).
- Privilegios de `SYSDBA` o rol de `DBA`.

## ⚙️ Guía de Instalación

### 1. Crear la tabla de monitoreo
Ejecuta el script para crear la bitácora que almacenará el historial de ejecuciones.
```sql
-- Ver script: gbd_bitacora_estat.sql
```

### 2. Crear el procedimiento
Ejecuta el script para crear el procedimiento almacenado que contiene la lógica inteligente que diferencia entre tablas planas y particionadas, priorizando la última partición vigente.
```sql
-- Ver script: spd_refrescar_estadisticas.sql
```

### 3. Desactivar el Job Nativo de Oracle
Para evitar conflictos de bloqueos y competencia por recursos, deshabilitamos la tarea automática:

BEGIN
  DBMS_AUTO_TASK_ADMIN.DISABLE(
    client_name => 'auto optimizer stats collection',
    operation   => NULL,
    window_name => NULL);
END;
/

### 4.Programar el Nuevo Job (DBMS_SCHEDULER)
Configuramos la ejecución automática diaria:

BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'JOB_STATS_CUSTOM_DAILY',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'SPD_REFRESCAR_ESTADISTICAS',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=20; BYMINUTE=0; BYSECOND=0',
    enabled         => TRUE,
    comments        => 'Job personalizado para recoleccion de estadisticas');
END;
/
