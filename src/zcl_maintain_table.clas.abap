class ZCL_MAINTAIN_TABLE definition
  public
  final
  create public .

public section.
  type-pools RSDS .

  methods CONSTRUCTOR
    importing
      !IV_TABLE_NAME type DDOBJNAME .
  methods DOWNLOAD_TEMPLATE .
  methods SHOW_DYNAMIC_SELECTION .
  methods SHOW_SE16N
    importing
      !IT_FIELD_RANGES type RSSELDYN_TAB .
  methods UPLOAD_FILE .
  methods DROP_TABLE .
  methods GET_FIELDS
    returning
      value(RT_FIELDS) type RSDSFIELDS_T .
  type-pools ABAP .
  methods IS_STANDARD
    returning
      value(RT_STANDARD) type ABAP_BOOL .
protected section.
private section.

  types:
    BEGIN OF ty_fields,
        fieldname TYPE fieldname,
        scrtext_m TYPE scrtext_m,
        END OF ty_fields .
  types:
    tt_fields TYPE STANDARD TABLE OF ty_fields WITH DEFAULT KEY .

  data GV_TABLE_NAME type DDOBJNAME .
  data GT_DD03P type DD03PTAB .
  data GO_STRUCT type ref to DATA .
  data GO_TABLE type ref to DATA .
  data GV_SELECTION_ID type DYNSELID .
  data GS_DD02V_WA type DD02V .
  type-pools ABAP .
  data GT_COMPONENTS type ABAP_COMPONENT_TAB .
  data GT_FIELDS type TT_FIELDS .
  data GV_STANDARD type ABAP_BOOL .

  methods ON_ADDED_FUNCTION
    for event ADDED_FUNCTION of CL_SALV_EVENTS_TABLE
    importing
      !E_SALV_FUNCTION .
  methods SHOW_ALV
    changing
      !IT_TABLE type ANY TABLE .
ENDCLASS.



CLASS ZCL_MAINTAIN_TABLE IMPLEMENTATION.


  METHOD constructor.

    DATA:
      lo_struct_source TYPE REF TO cl_abap_structdescr.

    TRY .
        "Get table name
        gv_table_name = iv_table_name.

        "Get table structure and components
        lo_struct_source ?= cl_abap_tabledescr=>describe_by_name( gv_table_name ).
        gt_components = lo_struct_source->get_components( ).
        DELETE gt_components WHERE name = 'MANDT' OR name = '.INCLUDE' OR name = '.INCLU--AP'.

        TRY.
            "Create new structure without Client
            DATA(lo_struct_target) =
              cl_abap_structdescr=>create(
                  p_components          = gt_components
              ).

            CREATE DATA go_struct TYPE HANDLE lo_struct_target.

            "Create table without Client using
            DATA(lo_table) =
              cl_abap_tabledescr=>create(
                  p_line_type          =  lo_struct_target
              ).

            CREATE DATA go_table TYPE HANDLE lo_table.

          CATCH cx_sy_table_creation
             cx_sy_struct_creation INTO DATA(lo_msg).  "
            MESSAGE lo_msg->get_longtext( ) TYPE 'E'.
        ENDTRY.

        "Get table structure
        CALL FUNCTION 'DDIF_TABL_GET'
          EXPORTING
            name          = gv_table_name
            langu         = sy-langu
          IMPORTING
            dd02v_wa      = gs_dd02v_wa
          TABLES
            dd03p_tab     = gt_dd03p
          EXCEPTIONS
            illegal_input = 1
            OTHERS        = 2.
        IF sy-subrc <> 0
          OR gt_dd03p IS INITIAL.
          MESSAGE text-e04 TYPE 'E' DISPLAY LIKE 'I'.
        ENDIF.

        DELETE gt_dd03p WHERE fieldname = 'MANDT' OR fieldname = '.INCLUDE' OR fieldname = '.INCLU--AP'.

        "Only can edit Z tables
        gv_standard =
          COND #(
            WHEN gv_table_name CP 'Z*' "find( val = gv_table_name regex = 'Z.' ) < 0
              THEN abap_false
            ELSE
              abap_true ).

**********************************************************************

      CATCH cx_sy_table_creation.
        MESSAGE text-e01 TYPE 'E' DISPLAY LIKE 'I'. "There is no table assigned to transaction
    ENDTRY.


  ENDMETHOD.


  METHOD download_template.
    DATA:
      lv_filename    TYPE string,
      lv_path        TYPE string,
      lv_fullpath    TYPE string,
      lv_user_action TYPE i.

    FIELD-SYMBOLS:
      <fs_table> TYPE ANY TABLE.

    ASSIGN go_table->* TO <fs_table>.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid
        TYPE sy-msgty
        NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    SELECT *
      FROM (gv_table_name)
      INTO CORRESPONDING FIELDS OF TABLE <fs_table>
      UP TO 10 ROWS.

    TRY.
        "Create Excel
        DATA(lo_excel) = NEW zcl_excel( ).
        "Get worksheet
        DATA(lo_worksheet) = lo_excel->get_active_worksheet( ).
        lo_worksheet->set_title( CONV zexcel_sheet_title( gv_table_name ) ).
        DATA(ls_settings) =
          VALUE zexcel_s_table_settings(
            nofilters           = abap_true
        ).

        lo_worksheet->bind_table(
          EXPORTING
            ip_table          = <fs_table>
            is_table_settings = ls_settings    " Excel table binding settings
        ).

        lo_worksheet->set_default_excel_date_format( ip_default_excel_date_format = zcl_excel_style_number_format=>c_format_date_ddmmyyyy ).

        DATA(lo_excel_writer) = NEW zcl_excel_writer_2007( ).
        DATA(lv_content) = lo_excel_writer->zif_excel_writer~write_file( lo_excel ).

        cl_gui_frontend_services=>file_save_dialog(
          EXPORTING
            default_file_name       = gv_table_name && '_template'    " Default File Name
            default_extension       = 'xlsx'    " Default Extension
            file_filter             = 'Excel (*.xlsx)|*.xlsx' ##NO_TEXT
          CHANGING
            filename                  = lv_filename    " File Name to Save
            path                      = lv_path    " Path to File
            fullpath                  = lv_fullpath    " Path + File Name
            user_action               = lv_user_action    " User Action (C Class Const ACTION_OK, ACTION_OVERWRITE etc)
          EXCEPTIONS
            cntl_error                = 1
            error_no_gui              = 2
            not_supported_by_gui      = 3
            invalid_default_file_name = 4
            OTHERS                    = 5
        ).

        IF sy-subrc <> 0.
         MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

        IF lv_user_action = cl_gui_frontend_services=>action_cancel.
          MESSAGE text-e02 TYPE 'I' DISPLAY LIKE 'E'.
        ELSE.
          DATA(lt_content) = cl_document_bcs=>xstring_to_solix( lv_content ).

          cl_gui_frontend_services=>gui_download(
            EXPORTING
              bin_filesize              = xstrlen( lv_content )    " File length for binary files
              filename                  = lv_fullpath    " Name of file
              filetype                  = 'BIN'    " File type (ASCII, binary ...)
            CHANGING
              data_tab                  = lt_content    " Transfer table
            EXCEPTIONS
              file_write_error          = 1
              no_batch                  = 2
              gui_refuse_filetransfer   = 3
              invalid_type              = 4
              no_authority              = 5
              unknown_error             = 6
              header_not_allowed        = 7
              separator_not_allowed     = 8
              filesize_not_allowed      = 9
              header_too_long           = 10
              dp_error_create           = 11
              dp_error_send             = 12
              dp_error_write            = 13
              unknown_dp_error          = 14
              access_denied             = 15
              dp_out_of_memory          = 16
              disk_full                 = 17
              dp_timeout                = 18
              file_not_found            = 19
              dataprovider_exception    = 20
              control_flush_error       = 21
              not_supported_by_gui      = 22
              error_no_gui              = 23
              OTHERS                    = 24
          ).
          IF sy-subrc <> 0.
     MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          ENDIF.
        ENDIF.



      CATCH zcx_excel.
      MESSAGE text-e06 TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD drop_table.
*DATA PARAMETER TYPE STANDARD TABLE OF SPAR.
    DATA:
      lv_answer.

    DATA(lv_question) = replace( val = text-003 sub = '&' with = gv_table_name ).


    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        text_question         = lv_question
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
*     TABLES
*       PARAMETER             = PARAMETER
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.
    IF sy-subrc = 0 AND lv_answer = '1'.
      DELETE FROM (gv_table_name).
      IF sy-subrc = 0.
        COMMIT WORK.
        DATA(lv_message) = replace( val = text-004 sub = '&' with = gv_table_name ).
        MESSAGE lv_message TYPE 'I' DISPLAY LIKE 'S'.
      ELSE.
        ROLLBACK WORK.
        lv_message = replace( val = text-005 sub = '&' with = gv_table_name ).
        MESSAGE lv_message TYPE 'I' DISPLAY LIKE 'E'.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD GET_FIELDS.

    IF lines( gt_dd03p ) < 75.
      rt_fields =
        CORRESPONDING rsdsfields_t(
          gt_dd03p
            MAPPING
              tablename = tabname
        ).
      RETURN.
    ENDIF.

    DATA(lt_fields) =
      CORRESPONDING tt_fields( gt_dd03p ).

    cl_salv_table=>factory(
      IMPORTING
        r_salv_table   = DATA(lo_salv)    " Basis Class Simple ALV Tables
      CHANGING
        t_table        = lt_fields
    ).

    lo_salv->set_screen_popup(
      EXPORTING
        start_column = 1
        end_column   = 60
        start_line   = 1
        end_line     = 70
    ).

    lo_salv->get_selections( )->set_selection_mode(
      if_salv_c_selection_mode=>row_column
    ).

    lo_salv->get_columns( )->set_optimize( ).

    DO.
      lo_salv->display( ).

      DATA(lt_selection) = lo_salv->get_selections( )->get_selected_rows( ).
      IF lines( lt_selection ) > 75.
        MESSAGE 'Menos de 75' TYPE 'I'.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.

    rt_fields =
      VALUE rsdsfields_t(
        FOR <fs_aux> IN lt_selection
          tablename = gv_table_name
        ( fieldname = lt_fields[ <fs_aux> ]-fieldname )
    ).

  ENDMETHOD.


  METHOD is_standard.
    rt_standard = gv_standard.
  ENDMETHOD.


  METHOD on_added_function.
    DATA:
      lo_table TYPE REF TO data.
    FIELD-SYMBOLS:
      <fs_table>          TYPE STANDARD TABLE,
      <fs_table_original> TYPE STANDARD TABLE.

    CASE e_salv_function.
      WHEN 'UPDATE'.
        ASSIGN go_table->* TO <fs_table>.
        CREATE DATA lo_table TYPE STANDARD TABLE OF (gv_table_name).
        ASSIGN lo_table->* TO <fs_table_original>.
        MOVE-CORRESPONDING <fs_table> TO <fs_table_original>.
        MODIFY (gv_table_name) FROM TABLE <fs_table_original>.
        IF sy-subrc = 0.
          MESSAGE sy-dbcnt && text-002 TYPE 'I' DISPLAY LIKE 'S'.
          SET SCREEN 0.
          LEAVE SCREEN.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD show_alv.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table   = DATA(lo_salv)    " Basis Class Simple ALV Tables
          CHANGING
            t_table        = it_table
        ).
        lo_salv->get_functions( )->set_default( ).
        lo_salv->get_columns( )->set_optimize( ).

        lo_salv->set_screen_status(
          EXPORTING
            report        = sy-cprog    " ABAP Program: Current Main Program
            pfstatus      = 'SALV_STANDARD'    " Screens, Current GUI Status
        ).

        DATA(lo_events) = lo_salv->get_event( ).

        SET HANDLER on_added_function FOR lo_events.

        lo_salv->display( ).

      CATCH cx_salv_msg.    "
        MESSAGE text-e07 TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD show_dynamic_selection.
    TYPES:
      tt_rsdsevents TYPE STANDARD TABLE OF rsdsevents WITH DEFAULT KEY.

    DATA:
      lt_exclude TYPE STANDARD TABLE OF rsexfcode.

    DATA(lt_fields_tab) = get_fields( ).

    "Add form to be populated for events
    DATA(lt_events) =
      VALUE tt_rsdsevents(
       ( event = 'O' "AT SELECTION SCREEN OUTPUT
        prog  = sy-cprog
        form  = 'F_EVENTS_OUTPUT' )

       ( event = 'A' "AT SELECTION SCREEN
        prog  = sy-cprog
        form  = 'F_EVENTS' )
    ).

    CALL FUNCTION 'FREE_SELECTIONS_INIT'
      EXPORTING
        kind                     = 'F'
      IMPORTING
        selection_id             = gv_selection_id
      TABLES
        fields_tab               = lt_fields_tab
        events                   = lt_events
      EXCEPTIONS
        fields_incomplete        = 1
        fields_no_join           = 2
        field_not_found          = 3
        no_tables                = 4
        table_not_found          = 5
        expression_not_supported = 6
        incorrect_expression     = 7
        illegal_kind             = 8
        area_not_found           = 9
        inconsistent_area        = 10
        kind_f_no_fields_left    = 11
        kind_f_no_fields         = 12
        too_many_fields          = 13
        dup_field                = 14
        field_no_type            = 15
        field_ill_type           = 16
        dup_event_field          = 17
        node_not_in_ldb          = 18
        area_no_field            = 19
        OTHERS                   = 20.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid
              TYPE sy-msgty
              NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    DATA(ls_pfkey) =
      VALUE rsdspfkey(
        pfkey   = 'STATUS_MAIN'
        program = sy-cprog
    ).

    APPEND VALUE rsexfcode(
          fcode = 'HIDETREE'
      ) TO lt_exclude.

    IF lines( gt_dd03p ) > 75.
      APPEND VALUE rsexfcode(
          fcode = 'SHOWTREE'
      ) TO lt_exclude.

    ENDIF.

    SET PF-STATUS 'STATUS_MAIN' EXCLUDING lt_exclude.

    CALL FUNCTION 'FREE_SELECTIONS_DIALOG'
      EXPORTING
        selection_id    = gv_selection_id
        title           = CONV syst_title( |{ sy-title } - { gs_dd02v_wa-ddtext }({ gv_table_name })| )
        frame_text      = text-001 "Selection criteria
        pfkey           = ls_pfkey
        tree_visible    = abap_false
      TABLES
        fields_tab      = lt_fields_tab
      EXCEPTIONS
        internal_error  = 1
        no_action       = 2
        selid_not_found = 3
        illegal_status  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
*      MESSAGE ID sy-msgid
*              TYPE sy-msgty
*              NUMBER sy-msgno
*              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.


  METHOD show_se16n.

    DATA(lt_selfields) =
      CORRESPONDING se16n_or_seltab_t(
        it_field_ranges
          MAPPING field = fieldname
    ).

    DELETE lt_selfields WHERE sign IS INITIAL.
    DELETE ADJACENT DUPLICATES FROM lt_selfields.

    DATA(lv_edit) = COND #( WHEN gv_standard = abap_false THEN abap_true ).

    CALL FUNCTION 'SE16N_INTERFACE'
      EXPORTING
        i_tab        = gv_table_name
        i_edit       = lv_edit
        i_sapedit    = lv_edit
        i_max_lines  = 200
        i_clnt_dep   = abap_true
      TABLES
        it_selfields = lt_selfields
      EXCEPTIONS
        no_values    = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid
        TYPE sy-msgty
        NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

  ENDMETHOD.


  METHOD upload_file.
*
*    DATA:
*      lt_filetable   TYPE filetable,
*      lv_rc          TYPE i,
*      lv_user_action TYPE i,
*      lo_elemdescr   TYPE REF TO cl_abap_elemdescr.
*
*    FIELD-SYMBOLS:
*      <fs_table>  TYPE STANDARD TABLE,
*      <fs_struct> TYPE any.
*
*    cl_gui_frontend_services=>file_open_dialog(
*      EXPORTING
*        default_extension       = 'xlsx'    " Default Extension
*        file_filter = 'Excel (*.xlsx)|*.xlsx' ##NO_TEXT
*      CHANGING
*        file_table              = lt_filetable    " Table Holding Selected Files
*        rc                      = lv_rc    " Return Code, Number of Files or -1 If Error Occurred
*        user_action             = lv_user_action    " User Action (See Class Constants ACTION_OK, ACTION_CANCEL)
*      EXCEPTIONS
*        file_open_dialog_failed = 1
*        cntl_error              = 2
*        error_no_gui            = 3
*        not_supported_by_gui    = 4
*        OTHERS                  = 5
*    ).
*    IF sy-subrc <> 0.
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
*    ENDIF.
*
*    IF lv_user_action = cl_gui_frontend_services=>action_cancel.
*      MESSAGE text-e02 TYPE 'I' DISPLAY LIKE 'E'.
*    ENDIF.
*
*    TRY .
*        DATA(lv_filename) = CONV string( lt_filetable[ 1 ]-filename ).
*
*        DATA(lo_excel_reader) = NEW zcl_excel_reader_2007( ).
*
*        DATA(lo_excel) =
*          lo_excel_reader->zif_excel_reader~load_file(
*              i_filename             = lv_filename
*          ).
*
*        DATA(lo_worksheet) = lo_excel->get_active_worksheet( ).
*        IF lo_worksheet->get_title( ) <> gv_table_name.
*          MESSAGE text-e03 TYPE 'I' DISPLAY LIKE 'E'.
*        ELSE.
*          DATA(lt_sheet_content) = lo_worksheet->sheet_content.
*
*          ASSIGN go_table->* TO <fs_table>.
*          CLEAR <fs_table>.
*          ASSIGN go_struct->* TO <fs_struct>.
*          CLEAR <fs_struct>.
*
*          DATA(lo_struct) = cl_abap_structdescr=>describe_by_data_ref( go_struct ).
*
*          IF <fs_table> IS ASSIGNED AND <fs_struct> IS ASSIGNED.
*            LOOP AT lt_sheet_content ASSIGNING FIELD-SYMBOL(<fs_content>)
*            GROUP BY <fs_content>-cell_row
*            ASCENDING
*            ASSIGNING FIELD-SYMBOL(<fs_row>).
*
*              "Skip header
*              IF <fs_row> = 1.
*                CONTINUE.
*              ENDIF.
*
*              LOOP AT GROUP <fs_row> ASSIGNING <fs_content>.
*                ASSIGN COMPONENT <fs_content>-cell_column OF STRUCTURE <fs_struct> TO FIELD-SYMBOL(<fs_field>).
*                IF sy-subrc = 0.
*                  IF <fs_content>-cell_style IS NOT INITIAL.
*                    <fs_field> = zcl_excel_common=>excel_string_to_date( <fs_content>-cell_value ).
**                CATCH zcx_excel.    "
*                  ELSE.
*                    TRY .
*                        lo_elemdescr ?= gt_components[ <fs_content>-cell_column ]-type.
*                        DATA(lv_edit_mask) = lo_elemdescr->edit_mask.
*                        IF lv_edit_mask IS NOT INITIAL.
*                          DATA(lv_conv_function) = 'CONVERSION_EXIT_' && replace( val = lv_edit_mask sub = '==' with = space ) && '_INPUT'.
*
*                          CALL FUNCTION lv_conv_function
*                            EXPORTING
*                              input = <fs_content>-cell_value
*                            IMPORTING
*                              output = <fs_field>.
*                        ELSE.
*                          TRY .
*                            <fs_field> = <fs_content>-cell_value.
*                          "If there is any conversion to number error, use common method to convert
*                          CATCH cx_sy_conversion_no_number.
*                           <fs_field> = zcl_excel_common=>excel_string_to_number( <fs_content>-cell_value ).
*                          ENDTRY.
*
*                        ENDIF.
*
*                      CATCH cx_sy_itab_line_not_found.
*
*                    ENDTRY.
*
*                  ENDIF.
*                ENDIF.
*
*              ENDLOOP.
*
*              APPEND <fs_struct> TO <fs_table>.
*              CLEAR <fs_struct>.
*
*            ENDLOOP.
*
*            show_alv(
*              CHANGING
*                it_table = <fs_table> ).
*
*          ENDIF.
*        ENDIF.
*
*
*
*      CATCH zcx_excel
*        cx_sy_itab_line_not_found.
*        MESSAGE text-e05 TYPE 'I' DISPLAY LIKE 'E'.
*
*    ENDTRY.
  ENDMETHOD.
ENDCLASS.
