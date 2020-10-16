CREATE OR REPLACE PACKAGE com_uk_explorer_pis
IS

  /*------------------------------------------------------------------------------
  * Author       Matt Mulvaney
  */-----------------------------------------------------------------------------

g_app_id_c            CONSTANT apex_application_pages.application_id%TYPE DEFAULT v('APP_ID');
g_app_page_id_c       CONSTANT apex_application_pages.page_id%TYPE DEFAULT nv('APP_PAGE_ID');

FUNCTION mysql
return varchar2;

  function execute
      ( p_process in apex_plugin.t_process
      , p_plugin  in apex_plugin.t_plugin
      )
  return apex_plugin.t_process_exec_result;

END com_uk_explorer_pis;
/
