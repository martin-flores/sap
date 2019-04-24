*&---------------------------------------------------------------------*
*& Report  Z_MAINTAIN_TABLE
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT z_maintain_table.
DATA:
  o_maintain TYPE REF TO zcl_maintain_table,
  gv_ucomm TYPE syucomm.

SELECTION-SCREEN: BEGIN OF BLOCK b1 WITH FRAME TITLE text-b01.
PARAMETERS:
  p_table TYPE ddobjname.
SELECTION-SCREEN: END OF BLOCK b1.

START-OF-SELECTION.
  o_maintain =
      NEW zcl_maintain_table( p_table ).

  o_maintain->show_dynamic_selection( ).


FORM f_events_output TABLES g_seldyn STRUCTURE rsseldyn  ##CALLED
                     g_fldnum STRUCTURE rsdsfldnum ##NEEDED.
  DATA:
    lt_exclude TYPE STANDARD TABLE OF rsexfcode.

  IF gv_ucomm IS INITIAL.
    APPEND VALUE rsexfcode(
          fcode = 'HIDETREE'
      ) TO lt_exclude.

    IF o_maintain->is_standard( ) = abap_true.
      APPEND VALUE rsexfcode(
          fcode = 'UPLOAD'
      ) TO lt_exclude.

      APPEND VALUE rsexfcode(
          fcode = 'TEMPLATE'
      ) TO lt_exclude.

      APPEND VALUE rsexfcode(
          fcode = 'DROP'
      ) TO lt_exclude.
    ENDIF.

    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = 'STATUS_MAIN'
        p_program = sy-cprog
      TABLES
        p_exclude = lt_exclude.

    CLEAR gv_ucomm.
  ENDIF.

ENDFORM.

FORM f_events TABLES g_seldyn STRUCTURE rsseldyn  ##CALLED
                     g_fldnum STRUCTURE rsdsfldnum ##NEEDED.

  DATA: lt_exclude TYPE STANDARD TABLE OF rsexfcode.

  IF o_maintain->is_standard( ) = abap_true.
    APPEND VALUE rsexfcode(
        fcode = 'UPLOAD'
    ) TO lt_exclude.

    APPEND VALUE rsexfcode(
        fcode = 'TEMPLATE'
    ) TO lt_exclude.

    APPEND VALUE rsexfcode(
        fcode = 'DROP'
    ) TO lt_exclude.
  ENDIF.

  gv_ucomm = sy-ucomm.

  CASE sy-ucomm.
    WHEN 'EXECUTE'.
      "Show SE16N using ranges from selection screen
      o_maintain->show_se16n( it_field_ranges = g_seldyn[] ).
    WHEN 'UPLOAD'.
      "Upload Excel file
      o_maintain->upload_file( ).
    WHEN 'TEMPLATE'.
      "Download Excel template
      o_maintain->download_template( ).
    WHEN 'DROP'.
      "Drop table
      o_maintain->drop_table( ).
    WHEN 'SHOWTREE'.
      APPEND VALUE rsexfcode(
          fcode = 'SHOWTREE'
      ) TO lt_exclude.

      CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
        EXPORTING
          p_status  = 'STATUS_MAIN'
          p_program = sy-cprog
        TABLES
          p_exclude = lt_exclude.

    WHEN 'HIDETREE'.
      APPEND VALUE rsexfcode(
          fcode = 'HIDETREE'
      ) TO lt_exclude.

      CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
        EXPORTING
          p_status  = 'STATUS_MAIN'
          p_program = sy-cprog
        TABLES
          p_exclude = lt_exclude.
  ENDCASE.
ENDFORM.
