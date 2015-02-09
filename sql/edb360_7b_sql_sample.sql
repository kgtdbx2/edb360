@@edb360_0g_tkprof.sql
DEF files_prefix = '';
SET VER OFF FEED OFF SERVEROUT ON HEAD OFF PAGES 50000 LIN 32767 TRIMS ON TRIM ON TI OFF TIMI OFF ARRAY 100;
DEF section_name = 'SQL Sample';
SPO &&main_report_name..html APP;
PRO <h2 title="Top SQL considering ASH presence for past 1 hr, 4 hrs, 1 day, 7 days and &&history_days. days">&&section_name.</h2>
SPO OFF;

COL hh_mm_ss NEW_V hh_mm_ss NOPRI FOR A8;
SPO 9997_&&common_prefix._top_sql_driver.sql;
DECLARE
  PROCEDURE put_line(p_line IN VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(p_line);
  END put_line;
  PROCEDURE update_log(p_module IN VARCHAR2) IS
  BEGIN
        put_line('COL hh_mm_ss NEW_V hh_mm_ss NOPRI FOR A8;');
		put_line('SELECT TO_CHAR(SYSDATE, ''HH24:MI:SS'') hh_mm_ss FROM DUAL;');
		put_line('-- update log');
		put_line('SPO &&edb360_log..txt APP;');
		put_line('PRO '||CHR(38)||chr(38)||'hh_mm_ss. '||p_module);
		put_line('SPO OFF;');
  END update_log;
BEGIN
  FOR i IN (WITH high_load_sql AS (
            SELECT /*+ &&sq_fact_hints. &&ds_hint. */
                   dbid,
                   sql_id,
                   ROUND(COUNT(*) / 360, 6) db_time_hrs,
                   ROUND(SUM(CASE session_state WHEN 'ON CPU' THEN 1 ELSE 0 END) / 360, 6) cpu_time_hrs
              FROM dba_hist_active_sess_history
             WHERE sql_id IS NOT NULL
               AND snap_id BETWEEN &&minimum_snap_id. AND &&maximum_snap_id.
               AND dbid = &&edb360_dbid.
             GROUP BY
                   dbid,
                   sql_id
            HAVING COUNT(*) > 60 -- >10mins
            --HAVING COUNT(*) > 360 -- >1hr
            ),
            ranked_sql AS (
            SELECT /*+ &&sq_fact_hints. */
                   dbid,
                   sql_id,
                   db_time_hrs,
                   cpu_time_hrs,
                   RANK () OVER (ORDER BY db_time_hrs DESC, cpu_time_hrs DESC) rank_num
              FROM high_load_sql
            ),
            top_sql AS (
            SELECT /*+ &&sq_fact_hints. */
                   r.sql_id,
                   TO_CHAR(ROUND(r.db_time_hrs, 2), '9990.00') db_time_hrs,
                   TO_CHAR(ROUND(r.cpu_time_hrs, 2), '9990.00') cpu_time_hrs,
                   r.rank_num,
                   h.sql_text,
                   CASE 
                   WHEN h.sql_text IS NULL THEN 'unknown'
                   ELSE REPLACE(REPLACE(REPLACE(REPLACE(DBMS_LOB.SUBSTR(h.sql_text, 1000), CHR(10), ' '), '"', CHR(38)||'#34;'), '>', CHR(38)||'#62;'), '<', CHR(38)||'#60;')
                   END sql_text_1000
              FROM ranked_sql r,
                   dba_hist_sqltext h
             WHERE r.rank_num <= 32
               AND h.dbid(+) = r.dbid
               AND h.sql_id(+) = r.sql_id
             ORDER BY
                   r.sql_id
            )
            SELECT * FROM top_sql ORDER BY sql_id)
  LOOP
    put_line('COL hh_mm_ss NEW_V hh_mm_ss NOPRI FOR A8;');
    put_line('SELECT TO_CHAR(SYSDATE, ''HH24:MI:SS'') hh_mm_ss FROM DUAL;');
    put_line('-- update log');
    put_line('SPO &&edb360_log..txt APP;');
    put_line('PRO');
    put_line('PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    put_line('PRO');
    put_line('PRO rank:'||i.rank_num||' sql_id:'||i.sql_id);
    put_line('SPO OFF;');
    put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&edb360_log..txt');
    put_line('-- update main report');
    put_line('SPO &&main_report_name..html APP;');
    put_line('PRO <li title="'||i.sql_text_1000||'">'||i.sql_id||' rank:'||i.rank_num||' et:'||i.db_time_hrs||'h cpu:'||i.cpu_time_hrs||'h');
    put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&main_report_name..html');
    put_line('SPO OFF;');
    IF i.rank_num <= 32 THEN
      update_log('PLANX');
      put_line('@@sql/planx.sql &&diagnostics_pack. '||i.sql_id);
      put_line('-- update main report');
      put_line('SPO &&main_report_name..html APP;');
      put_line('PRO <a href="planx_'||i.sql_id||'_'||CHR(38)||chr(38)||'current_time..txt">planx(text)</a>');
      put_line('SPO OFF;');
      put_line('-- zip');
      put_line('HOS zip -mq &&main_compressed_filename._&&file_creation_time. planx_'||i.sql_id||'_'||CHR(38)||chr(38)||'current_time..txt');
      put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&main_report_name..html');
    END IF;
    IF i.rank_num <= 24 AND '&&skip_10g.' IS NULL AND '&&skip_diagnostics.' IS NULL AND '&&skip_tuning.' IS NULL THEN
      update_log('SQLMON');
      put_line('@@sql/sqlmon.sql &&tuning_pack. '||i.sql_id);
      put_line('-- update main report');
      put_line('SPO &&main_report_name..html APP;');
      put_line('PRO <a href="sqlmon_'||i.sql_id||'_'||CHR(38)||chr(38)||'current_time..zip">sqlmon(zip)</a>');
      put_line('SPO OFF;');
      put_line('-- zip');
      put_line('HOS zip -mq &&main_compressed_filename._&&file_creation_time. sqlmon_'||i.sql_id||'_'||CHR(38)||chr(38)||'current_time..zip');
      put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&main_report_name..html');
    END IF;
    IF i.rank_num <= 16 AND '&&skip_diagnostics.' IS NULL THEN
      update_log('SQLASH');
      put_line('@@sql/sqlash.sql &&diagnostics_pack. '||i.sql_id);
      put_line('-- update main report');
      put_line('SPO &&main_report_name..html APP;');
      put_line('PRO <a href="sqlash_'||i.sql_id||'.zip">sqlash(zip)</a>');
      put_line('SPO OFF;');
      put_line('-- zip');
      put_line('HOS zip -mq &&main_compressed_filename._&&file_creation_time. sqlash_'||i.sql_id||'.zip');
      put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&main_report_name..html');
    END IF;
    IF i.rank_num <= 8 THEN
      update_log('SQLHC');
      put_line('@@sql/sqlhc.sql &&license_pack. '||i.sql_id);
      put_line('-- update main report');
      put_line('SPO &&main_report_name..html APP;');
      put_line('PRO <a href="'||CHR(38)||chr(38)||'files_prefix..zip">sqlhc(zip)</a>');
      put_line('SPO OFF;');
      put_line('-- zip');
      put_line('HOS zip -mq &&main_compressed_filename._&&file_creation_time. '||CHR(38)||chr(38)||'files_prefix..zip');
      put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&main_report_name..html');
    END IF;
    put_line('-- update main report');
    put_line('SPO &&main_report_name..html APP;');
    put_line('PRO </li>');
    put_line('SPO OFF;');
    put_line('HOS zip -q &&main_compressed_filename._&&file_creation_time. &&main_report_name..html');
  END LOOP;
END;
/
SPO OFF;
@@edb360_0g_tkprof.sql
@9997_&&common_prefix._top_sql_driver.sql;
SET SERVEROUT OFF HEAD ON PAGES &&def_max_rows.;
HOS zip -mq &&main_compressed_filename._&&file_creation_time. 9997_&&common_prefix._top_sql_driver.sql
SET HEA ON LIN 32767 NEWP NONE PAGES &&def_max_rows. LONG 32000 LONGC 2000 WRA ON TRIMS ON TRIM ON TI OFF TIMI OFF ARRAY 100 NUM 20 SQLBL ON BLO . RECSEP OFF;
CL COL;
COL row_num FOR 9999999 HEA '#' PRI;


