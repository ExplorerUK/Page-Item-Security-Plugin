CREATE OR REPLACE PACKAGE BODY com_uk_explorer_pis
IS
 
  -- Array
  TYPE tt_errors IS TABLE of apex_error.t_error INDEX BY BINARY_INTEGER;
  tb_errors   tt_errors;

FUNCTION mysql
return varchar2
is
begin
  begin return 'select ename, empno from emp'; end;
end;
  /*------------------------------------------------------------------------------
  * Author       Matt Mulvaney
  */-----------------------------------------------------------------------------

  PROCEDURE kp_native_select_list( p_item_meta apex_application_page_items%ROWTYPE)
  IS
    l_context      apex_exec.t_context;      
    l_filters      apex_exec.t_filters;
    l_item_value   VARCHAR2(32767) DEFAULT NULL;
    l_sqlerrm      VARCHAR2(512) DEFAULT NULL;

    -- Types/Records
    TYPE t_sql_info IS RECORD ( sql_statement       CLOB,
                                return_column        VARCHAR2(255),
                                page_item_value      VARCHAR2(32767) );
    sql_info                    t_sql_info;                                
    tb_sql_parameters           apex_exec.t_parameters DEFAULT apex_exec.c_empty_parameters;
    

    -- Modules
    PROCEDURE get_lov_as_sql( p_sql_info IN OUT t_sql_info, 
                              p_tb_sql_parameters IN OUT apex_exec.t_parameters, 
                              p_item_meta apex_application_page_items%ROWTYPE,
                              p_sqlerrm OUT VARCHAR2 )
    IS
          -- l_plsql_fn_sql   VARCHAR2(32767) DEFAULT NULL;
          l_context        apex_exec.t_context; 
          l_t_column       apex_exec.t_column; 
          l_sql_parameters apex_exec.t_parameters;
          l_plsql_code     CLOB DEFAULT NULL;
          l_item_value     VARCHAR2(32767) DEFAULT NVL( p_sql_info.page_item_value, v(p_item_meta.item_name));
          l_static_sting CONSTANT VARCHAR2(32767) DEFAULT q'[
            WITH DATA AS
            ( SELECT REGEXP_REPLACE(:LOVDEFINITION,'STATIC\d?:','') str FROM dual
            ),
            asRows AS (
            SELECT trim(regexp_substr(str, '[^,]+', 1, LEVEL)) str
              FROM DATA
            CONNECT BY instr(str, ',', 1, LEVEL - 1) > 0 )
            SELECT regexp_substr(str, '[^;]+', 1, 1) d,
                  regexp_substr(str, '[^;]+', 1, 2) r
              FROM asrows]';
              
              rec_named_lov             apex_application_lovs%ROWTYPE;
    BEGIN
      apex_debug.message('>fn_get_return_column');
      apex_debug.message('Inital Item Value: ' || l_item_value); 

      IF p_item_meta.lov_named_lov IS NOT NULL
      THEN
        SELECT * 
          INTO rec_named_lov 
          FROM apex_application_lovs 
         WHERE list_of_values_name = p_item_meta.lov_named_lov 
           AND application_id = g_app_id_c;

        IF rec_named_lov.lov_type = 'Static'
        THEN
          apex_debug.message('Static Named LOV: ' || p_item_meta.lov_named_lov); 
          p_tb_sql_parameters(1).name := 'LOV_NAMED_LOV';
          p_tb_sql_parameters(1).data_type := apex_exec.c_data_type_varchar2;
          p_tb_sql_parameters(1).value.varchar2_value := p_item_meta.lov_named_lov;
          p_tb_sql_parameters(2).name := 'APPLICATION_ID';
          p_tb_sql_parameters(2).data_type := apex_exec.c_data_type_number;
          p_tb_sql_parameters(2).value.number_value := g_app_id_c;
          p_sql_info.sql_statement := 'SELECT display_value, return_value FROM apex_application_lov_entries WHERE list_of_values_name = :LOV_NAMED_LOV AND application_id = :APPLICATION_ID';
        ELSIF rec_named_lov.lov_type = 'Dynamic'
        THEN
            p_sql_info.sql_statement := rec_named_lov.list_of_values_query;
        END IF;
      ELSIF p_item_meta.lov_definition IS NOT NULL
      THEN
        -- SQL / Static Based
        IF p_item_meta.lov_definition LIKE 'STATIC%'
        THEN
          -- Static list of values  
          p_tb_sql_parameters(1).name := 'LOVDEFINITION';
          p_tb_sql_parameters(1).data_type := apex_exec.c_data_type_varchar2;
          p_tb_sql_parameters(1).value.varchar2_value := p_item_meta.lov_definition;
          p_sql_info.sql_statement := l_static_sting;
        ELSE
          -- PL/SQL or SQL Statement
          p_sql_info.sql_statement := p_item_meta.lov_definition;
          -- In case its a PLSQL statement, try to grab that now
          BEGIN 
            -- Due to Bug 30786289 we place the return SQL in the select item itself.
            l_plsql_code := '
              declare function x return varchar2 is begin ' || RTRIM( p_sql_info.sql_statement,';')  || '; 
              return null; end; begin :' || p_item_meta.item_name ||' := x; end;
              ';
            apex_debug.message(l_plsql_code);     
            apex_exec.execute_plsql(
                p_plsql_code      => l_plsql_code, 
                p_auto_bind_items => true,
                p_sql_parameters  => l_sql_parameters );  
            -- Fetch SQL from Item
            p_sql_info.sql_statement := v(p_item_meta.item_name);
            apex_debug.message('Now calculated/set to ' || p_sql_info.sql_statement  );
            -- Set back to Original Value
            apex_util.set_session_state(
                p_name => p_item_meta.item_name
              , p_value => l_item_value
              , p_commit => false
            );
            apex_debug.message('Set Back to Initial Value ' || v(p_item_meta.item_name) );
          exception
            when OTHERS 
            then
              apex_exec.close( l_context );
          END;
        END IF;
      END IF; 

      apex_debug.message('Opening Context SQL ...');
      apex_debug.message(p_sql_info.sql_statement);
 

      -- We should have a SQL statment by now
      l_context := apex_exec.open_query_context(
            p_location          => apex_exec.c_location_local_db,
            p_sql_query         => p_sql_info.sql_statement,
            p_max_rows          => 0, 
            p_sql_parameters    => p_tb_sql_parameters );

      apex_debug.message('Parsed SQL');
      l_t_column := apex_exec.get_column( l_context, 2);
      p_sql_info.return_column := l_t_column.name;
      apex_exec.close( l_context ); 
      apex_debug.message('FIN Return Column: ' || p_sql_info.return_column ); 

    EXCEPTION
      WHEN OTHERS 
      THEN
        apex_debug.message('When Others in get_lov_as_sql');
        p_sqlerrm := SUBSTR(SQLERRM, 1, 512);

    END get_lov_as_sql;
  BEGIN

    apex_debug.message('kp_native_select_list');
    apex_debug.message('Page Item: ' || p_item_meta.item_name );

    l_item_value := v(p_item_meta.item_name);
    apex_debug.message('Page Item Value: ' || l_item_value );

    -- Prepare call to get_lov_as_sql which transforms all LOV types to SQL
    sql_info.page_item_value := l_item_value; -- Performance
    get_lov_as_sql(sql_info, tb_sql_parameters, p_item_meta, l_sqlerrm ); 
  
   IF l_sqlerrm IS NULL AND
      NOT ( p_item_meta.lov_display_null = 'Yes' AND l_item_value IS NULL ) AND -- Dont bother when Item is NULL and NULL is allowed
      NVL( p_item_meta.lov_display_extra, 'No' ) = 'No'
   THEN  
      apex_exec.close( l_context ); 
      apex_exec.add_filter(
          p_filters     => l_filters,
          p_filter_type =>  CASE WHEN l_item_value IS NULL THEN apex_exec.c_filter_null ELSE apex_exec.c_filter_eq END,
          p_column_name => sql_info.return_column,
          p_value => l_item_value);  

      l_context := apex_exec.open_query_context(
          p_location          => apex_exec.c_location_local_db,
          p_sql_query         => sql_info.sql_statement,
          p_filters          => l_filters,
          p_max_rows         => 1,
          p_total_row_count  => true,
          p_total_row_count_limit => 1,
          p_sql_parameters    => tb_sql_parameters );

      apex_debug.message( 'Total Row Count: ' || NVL( apex_exec.get_total_row_count( l_context ), 0 ) );

      IF NVL( apex_exec.get_total_row_count( l_context ), 0 ) = 0
      THEN
          -- apex_error.add_error(
          --   p_message => 'Invalid value for ' || p_item_meta.label
          -- , p_additional_info =>  null
          -- , p_display_location => apex_error.c_INLINE_IN_NOTIFICATION
          -- );
          tb_errors(tb_errors.COUNT+1).message := 'Invalid value for ' || p_item_meta.label;
          tb_errors(tb_errors.COUNT).display_location := 'page';
      END IF;

      apex_exec.close( l_context );
    
    END IF; 
 
    EXCEPTION
      WHEN OTHERS THEN
          APEX_EXEC.CLOSE( l_context );
          RAISE;    

    END kp_native_select_list;
PROCEDURE kp_page_items
  IS

  BEGIN

    apex_debug.message('>Processing Page Items');
    FOR x in ( select * from apex_application_page_items where application_id = g_app_id_c and page_id = g_app_page_id_c  and item_name = 'P1_NEW' )
    LOOP

        IF x.DISPLAY_AS_CODE = 'NATIVE_SELECT_LIST'
        THEN
            kp_native_select_list(x);
        END IF;
    END LOOP;

  END kp_page_items;

  function execute
      ( p_process in apex_plugin.t_process
      , p_plugin  in apex_plugin.t_plugin
      )
  return apex_plugin.t_process_exec_result
  as
      l_exec_result apex_plugin.t_process_exec_result;

      l_include                 varchar2(4000) := p_process.attribute_01;
      l_exclude                 varchar2(4000) := p_process.attribute_02; 
  
      -- Types
      rec_apex_application_pages  apex_application_pages%ROWTYPE;
  begin

      apex_debug.message('>Page Item Security');

      apex_plugin_util.debug_process
          ( p_plugin  => p_plugin
          , p_process => p_process
          );

        kp_page_items;
      
        SELECT * 
        INTO rec_apex_application_pages 
        FROM apex_application_pages 
        WHERE application_id = g_app_id_c 
        AND page_id = g_app_page_id_c;
        
        -- apex_json.initialize_clob_output;
        IF NVL(tb_errors.COUNT,0) > 0
        THEN
          IF rec_apex_application_pages.reload_on_submit_code = 'A'
          THEN
            FOR x in tb_errors.FIRST..tb_errors.LAST
            LOOP
              apex_error.add_error(
                p_message =>  apex_escape.html(tb_errors(x).message)
              , p_additional_info =>  null
              , p_display_location => apex_error.c_inline_in_notification
              );
              -- Unfortunately Developers need to conditionally stop their processes running.
            END LOOP;
          -- apex_application.stop_apex_engine;
          ELSE /* S = Only for Success */
            apex_json.open_object;  
            -- apex_json.write('success', true);  
              apex_json.open_array('errors'); -- "array": [
              FOR x in tb_errors.FIRST..tb_errors.LAST
              LOOP
              apex_json.open_object; 
                apex_json.write('message', apex_escape.html(tb_errors(x).message)); 
                apex_json.write('isEscaped', 'true'); 
                apex_json.open_array('location');
                apex_json.write(tb_errors(x).display_location);
                apex_json.close_array;
              apex_json.close_object; 
              END LOOP;
            apex_json.close_array;
            apex_json.close_object; 
            
          apex_application.stop_apex_engine;
        END IF;

        apex_debug.message('Melta');
          -- apex_debug.message(apex_json.get_clob_output);

--  apex_json.free_output;

        END IF;


      return l_exec_result;
  end execute;

END com_uk_explorer_pis;
/
show err