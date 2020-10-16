prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_190200 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2019.10.04'
,p_release=>'19.2.0.00.18'
,p_default_workspace_id=>72616447716734322
,p_default_application_id=>306
,p_default_id_offset=>0
,p_default_owner=>'E'
);
end;
/
 
prompt APPLICATION 306 - Context
--
-- Application Export:
--   Application:     306
--   Name:            Context
--   Date and Time:   17:26 Friday October 16, 2020
--   Exported By:     ADMIN
--   Flashback:       0
--   Export Type:     Component Export
--   Manifest
--     PLUGIN: 7600611227590959
--   Manifest End
--   Version:         19.2.0.00.18
--   Instance ID:     218269090184964
--

begin
  -- replace components
  wwv_flow_api.g_mode := 'REPLACE';
end;
/
prompt --application/shared_components/plugins/process_type/com_uk_explorer_apris
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(7600611227590959)
,p_plugin_type=>'PROCESS TYPE'
,p_name=>'COM.UK.EXPLORER.APRIS'
,p_display_name=>'Page Item Security'
,p_supported_ui_types=>'DESKTOP'
,p_api_version=>2
,p_execution_function=>'com_uk_explorer_pis.execute'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_version_identifier=>'1.0'
);
end;
/
prompt --application/end_environment
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false));
commit;
end;
/
set verify on feedback on define on
prompt  ...done
