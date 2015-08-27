-- Referencia para como hacer un scheduler 
http://www.oradev.com/dbms_scheduler.jsp

-- ver los jobs y el scheduler 
 select owner,job_name,job_action,program_name,repeat_interval, state,failure_count,
 LAST_START_DATE,LAST_RUN_DURATION,NEXT_RUN_DATE,
 JOB_CLASS ,schedule_name,schedule_owner
 from dba_scheduler_jobs where owner='AVAIL';
 where job_name like 'myjob%';

 -- jobs y schedulers pero forma antigua 
 select job,what,to_char(last_date,'dd-mm-yyyy hh24:mi'),to_char(next_date,'dd-mm-yyyy hh24:mi'),interval,failures,broken from dba_jobs;

-- todas las ventanas del scheduer 
set pagesize 300 linesize 200
select * from dba_scheduler_windows

-- todos los schedulers 
select schedule_name, schedule_type, start_date, repeat_interval from dba_scheduler_schedules

-- los jobs que estan corriendo actualmente (metodo antiguo)
SELECT 
dba_jobs.JOB,
instance,
SCHEMA_USER,
LAST_DATE,
NEXT_DATE,
interval,
BROKEN,
FAILURES,
RUNNING,
SID,
what
FROM DBA_JOBS 
LEFT OUTER JOIN (SELECT
JOB,'YES' RUNNING,SID
FROM DBA_JOBS_RUNNING )  running
ON DBA_JOBS.JOB = RUNNING.JOB
ORDER BY SCHEMA_USER, last_date;

-- metodo nuevo para ver los jobs que estan corriendo 
 select * from dba_scheduler_running_jobs;


--historico de los jobs ejecutados
 select job_name,status,req_start_date,actual_start_date,run_duration from  DBA_SCHEDULER_JOB_RUN_DETAILS where  job_name like 'REFRESH_BSP_COMP_MVIEWS%' and req_start_date> sysdate-3 order by req_start_date;

 select log_date
 ,      job_name
 ,      status
 from dba_scheduler_job_log where ;
 
-- control de jobs 
exec dbms_scheduler.stop_job('owner.job');   
exec dbms_scheduler.enable('owner.job'); 




DECLARE
exist_flag number(1):=0;
err_msg varchar2(200);
BEGIN
--Crear una ventana de scheduler, donde le defines la frecuencia de horas
exist_flag:=0;
        select count(*) into exist_flag
        from dba_scheduler_schedules
        where schedule_name='HOURLY_STATISTICS';
IF exist_flag=0 THEN
        sys.dbms_scheduler.create_schedule(
        repeat_interval => 'FREQ=HOURLY',
        start_date => systimestamp,
        comments => 'Collect statistics each hour',
        schedule_name => '"SYSTEM"."HOURLY_STATISTICS"');
END IF;
dbms_output.put_line('Succeeded to create new schedules');
EXCEPTION
when others then
err_msg:=substr(sqlerrm,1,200);
dbms_output.put_line('Error during definition of new schedule '||err_msg);
END;


DECLARE
exist_flag number(1):=0;
err_msg varchar2(200);
BEGIN
-- este es un ejemplo de job que corre cada hora en el esquema CMDB y recolecta estadisticas con el parametro de ghater auto 

        select count(*)
        into exist_flag
        from dba_scheduler_jobs
        where job_name='HOURLY_REFRESH_CMDB_STATS';
IF exist_flag=0 THEN
        sys.dbms_scheduler.create_job(
        job_name => '"SYSTEM"."HOURLY_REFRESH_CMDB_STATS"',
        job_type => 'PLSQL_BLOCK',
        job_action => 'begin
           DBMS_STATS.GATHER_SCHEMA_STATS(''&cmdb_schema'',OPTIONS=>''GATHER AUTO'');
        end;',
        schedule_name => 'SYSTEM.HOURLY_STATISTICS',
        job_class => 'DEFAULT_JOB_CLASS',
        comments => 'CMDB missing statistics refresh by the hour',
        auto_drop => FALSE,
        enabled => TRUE);
END IF;
dbms_output.put_line('Succeeded to define hourly statistics job');
EXCEPTION
when others then
err_msg:=substr(sqlerrm,1,200);
dbms_output.put_line('Error during job creation  '||err_msg);
END;

-- Job definido en el create job
 exec DBMS_SCHEDULER.create_job (
    job_name        => 'strmadmin.Streams_HeartBeat',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'begin update strmadmin.prod2_heartbeat set DB_CHANGE_TIME=sysdate where db_name=''PROD2''; commit; end;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'freq=MINUTELY; interval=10',
    end_date        => NULL,
    enabled         => TRUE,
    comments        => 'Generate streams heartbeat every 10 minutes');