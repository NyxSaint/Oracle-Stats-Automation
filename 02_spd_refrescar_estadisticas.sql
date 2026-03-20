/*******************************************************************************
  PROYECTO: Actualización de Estadísticas - Oracle
  AUTOR: Luis Felipe Barba Sosa
  DESCRIPCIÓN: Procedimiento especializado para la recolección de estadísticas
               en entornos de alto volumen (Data Warehouse).
               Implementa una lógica de discriminación por período (Mes/Año)
               para particiones activas.
  FECHA MOD: 18/03/2025 (Inclusión de Index Partitions)
*******************************************************************************/

create or replace procedure sys.spd_refrescar_estadisticas is
    vi_fecha     varchar2(50);
    vi_grupo     number;
    vi_avance    number := 1;
    vi_condicion number;
    vi_periodo   varchar2(20);
    
    -- Cursor para identificar esquemas de aplicación basados en perfiles y tablespaces
    cursor cur_schemas_db is
        select t.username from dba_users t
        where t.profile in ('APP_USER','PROFILE_USER','DEFAULT') 
        and t.default_tablespace in ('TSD_DATA','TDS_DATA01')
        order by t.username asc;

begin
    -- Inicialización de Bitácora y Definición de Período Vigente
    select nvl(max(grupo), 0) + 1 into vi_grupo from sys.gbd_bitacora_estat;
    -- Formato esperado de partición: P_MM_YYYY
    select 'P_' || to_char(sysdate, 'mm') || '_' || to_char(sysdate, 'yyyy') 
    into vi_periodo from dual;

    ----------------------------------------------------------------------------
    -- PASO 1: FIXED OBJECTS STATS (Metadatos de memoria y rendimiento del motor)
    ----------------------------------------------------------------------------
    select to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') into vi_fecha from dual;
    insert into gbd_bitacora_estat (grupo, paso, proceso, hi)
    values (vi_grupo, vi_avance, 'FIXED_OBJECTS_STATS', vi_fecha);
    commit;

    dbms_stats.gather_fixed_objects_stats();

    select to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') into vi_fecha from dual;
    update gbd_bitacora_estat set hf = vi_fecha where grupo = vi_grupo and paso = vi_avance;
    commit;

    vi_avance := vi_avance + 1;

    ----------------------------------------------------------------------------
    -- PASO 2: GATHER DICTIONARY STATS (Salud del Diccionario de Datos)
    ----------------------------------------------------------------------------
    select to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') into vi_fecha from dual;
    insert into gbd_bitacora_estat (grupo, paso, proceso, hi)
    values (vi_grupo, vi_avance, 'GATHER_DICTIONARY_STATS', vi_fecha);
    commit;

    dbms_stats.gather_dictionary_stats(
        cascade          => true,
        estimate_percent => dbms_stats.auto_sample_size,
        degree           => 8,
        no_invalidate    => dbms_stats.auto_invalidate,
        granularity      => 'AUTO',
        method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
        options          => 'GATHER'
    );

    select to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') into vi_fecha from dual;
    update gbd_bitacora_estat set hf = vi_fecha where grupo = vi_grupo and paso = vi_avance;
    commit;

    vi_avance := vi_avance + 1;

    ----------------------------------------------------------------------------
    -- PASO 3: RECOLECCIÓN SELECTIVA (Tablas e Índices Particionados)
    ----------------------------------------------------------------------------
    for vl_schema_cursor in cur_schemas_db loop
        select to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') into vi_fecha from dual;
        insert into gbd_bitacora_estat (grupo, paso, proceso, hi)
        values (vi_grupo, vi_avance, 'SCHEMA_STATS -> '||vl_schema_cursor.username, vi_fecha);
        commit;

        -- Verificación de existencia de particiones para el período actual
        select count(1) into vi_condicion from dba_objects t 
        where t.owner = vl_schema_cursor.username and t.object_type = 'TABLE PARTITION';

        if (vi_condicion > 0) then
            -- A. Actualización de Particiones de Tabla (Excluyendo Recycle Bin)
            for vl_obj_schema_cursor in (
                select t.OBJECT_NAME, t.SUBOBJECT_NAME from dba_objects t
                where t.owner = vl_schema_cursor.username 
                and t.subobject_name = vi_periodo 
                and t.object_type = 'TABLE PARTITION' 
                and t.OBJECT_NAME not like ('BIN$%')
            ) loop
                dbms_stats.gather_table_stats(
                    ownname          => vl_schema_cursor.username,
                    tabname          => vl_obj_schema_cursor.OBJECT_NAME,
                    partname         => vl_obj_schema_cursor.SUBOBJECT_NAME,
                    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
                    granularity      => 'PARTITION',
                    cascade          => TRUE,
                    degree           => 8,
                    no_invalidate    => TRUE,
                    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
                    options          => 'GATHER'
                );
            end loop;

            -- B. Actualización de Particiones de Índices
            for vl_obj_schema_cursor_ind in (
                select t.OBJECT_NAME, t.SUBOBJECT_NAME from dba_objects t
                where t.owner = vl_schema_cursor.username 
                and t.subobject_name = vi_periodo 
                and t.object_type = 'INDEX PARTITION' 
                and t.OBJECT_NAME not like ('BIN$%')
            ) loop
                dbms_stats.gather_index_stats(
                    ownname  => vl_schema_cursor.username,
                    indname  => vl_obj_schema_cursor_ind.OBJECT_NAME,
                    partname => vl_obj_schema_cursor_ind.SUBOBJECT_NAME,
                    degree   => 8
                );
            end loop;
        end if;

        select to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss') into vi_fecha from dual;
        update gbd_bitacora_estat set hf = vi_fecha where grupo = vi_grupo and paso = vi_avance;
        commit;

        vi_avance := vi_avance + 1;
    end loop;

end spd_refrescar_estadisticas;
