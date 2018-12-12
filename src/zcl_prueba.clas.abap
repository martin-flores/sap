class ZCL_PRUEBA definition
  public
  final
  create public .

public section.

  constants GC_KAPPL type KAPPL value 'V' ##NO_TEXT.
  constants GC_KVEWE type KVEWE value 'A' ##NO_TEXT.

  methods CONSTRUCTOR
    importing
      !IV_KSCHL type KSCHL .
  methods GET_TABLE
    importing
      !IV_KOLNR type KOLNR
    exporting
      !ES_STRUCT type ref to DATA
      !ET_TABLE type ref to DATA .
  methods GET_SEQUENCES .
protected section.
private section.

  types:
    BEGIN OF ty_t685,
      kschl TYPE kschl,
      kozgf TYPE kozgf,
    END OF ty_t685 .
  types:
    tt_t685 TYPE SORTED TABLE OF ty_t685 WITH UNIQUE KEY kozgf .
  types:
    BEGIN OF ty_t682i,
      kozgf   TYPE kozgf,
      kolnr   TYPE kolnr,
      kotabnr TYPE kotabnr,
    END OF ty_t682i .
  types:
    tt_t682i TYPE SORTED TABLE OF ty_t682i WITH UNIQUE KEY kozgf kolnr .
  types:
    BEGIN OF ty_t682z,
      kozgf	TYPE kozgf,
      kolnr	TYPE kolnr,
      zaehk	TYPE dzaehk,
      zifna	TYPE dzifna,
      fstst	TYPE fstst,
    END OF ty_t682z .
  types:
    tt_t682z TYPE SORTED TABLE OF ty_t682z WITH UNIQUE KEY kozgf kolnr zaehk .
  types:
    BEGIN OF MESH ty_mesh,
      it_t685  TYPE tt_t685
        ASSOCIATION sequences TO it_t682i
          ON kozgf = kozgf,
      it_t682i TYPE tt_t682i
        ASSOCIATION fields TO it_t682z
          ON kozgf = kozgf AND kolnr = kolnr,
      it_t682z TYPE tt_t682z,
    END OF MESH ty_mesh .

  data GV_CONDITION type TY_MESH .
  data GC_FIXED_FIELDS type ABAP_COMPONENT_TAB .
ENDCLASS.



CLASS ZCL_PRUEBA IMPLEMENTATION.


  METHOD constructor.
    DATA:
      lt_t685  TYPE tt_t685,
      lt_t682i TYPE tt_t682i,
      lt_t682z TYPE tt_t682z.

    gc_fixed_fields =
      VALUE abap_component_tab(
        ( name = 'DATAB'
          type =
            CAST cl_abap_datadescr(
              cl_abap_elemdescr=>describe_by_name( 'KODATAB' )
            )
        )

        ( name = 'DATBI'
          type =
            CAST cl_abap_datadescr(
              cl_abap_elemdescr=>describe_by_name( 'KODATBI' )
            )
        )

        ( name = 'KBETR'
          type =
            CAST cl_abap_datadescr(
              cl_abap_elemdescr=>describe_by_name( 'KBETR_KOND' )
            )
        )

        ( name = 'KONWA'
          type =
            CAST cl_abap_datadescr(
              cl_abap_elemdescr=>describe_by_name( 'KONWA' )
            )
        )
      ).

    "Get Access sequence
    SELECT kschl, kozgf
      FROM t685
      INTO TABLE @lt_t685
      WHERE kvewe = 'A' AND
            kappl = 'V' AND
            kschl = @iv_kschl.

    IF sy-subrc = 0.
      gv_condition-it_t685 = lt_t685.

      "Get Sequences and tables
      SELECT kozgf, kolnr, kotabnr
        FROM t682i
        INTO TABLE @lt_t682i
        FOR ALL ENTRIES IN @lt_t685
        WHERE kvewe = 'A' AND
              kappl = 'V' AND
              kozgf = @lt_t685-kozgf.

      IF sy-subrc = 0.
        gv_condition-it_t682i = lt_t682i.

        SELECT kozgf, kolnr, zaehk, zifna, fstst
          FROM t682z
          INTO TABLE @lt_t682z
          FOR ALL ENTRIES IN @lt_t682i
          WHERE kvewe = 'A' AND
                kappl = 'V' AND
                kozgf = @lt_t682i-kozgf AND
                kolnr = @lt_t682i-kolnr.

        gv_condition-it_t682z = lt_t682z.

      ENDIF.
    ENDIF.
  ENDMETHOD.


  method GET_SEQUENCES.
  endmethod.


  method GET_TABLE.
    ASSIGN gv_condition-it_t682i[ kolnr = iv_kolnr ] TO FIELD-SYMBOL(<fs_sequence>).

    "Get table structure
    DATA(lo_tablestruct) =
      CAST cl_abap_structdescr(
        cl_abap_tabledescr=>describe_by_name( gc_kvewe && <fs_sequence>-kotabnr )
      ).

    "Get table components
    DATA(lt_components) = lo_tablestruct->get_components( ).

    "Only take key fields
    DATA(lt_comp_key) =
      VALUE abap_component_tab(
        FOR <fs_fields> IN gv_condition-it_t682i\fields[ <fs_sequence> WHERE fstst <> 'C' ]
        ( lt_components[ name = <fs_fields>-zifna ] )
      ).

    "Add fixed fields at the end
    APPEND LINES OF gc_fixed_fields TO lt_comp_key.

    "Create new structure
    DATA(lo_struct) =
      cl_abap_structdescr=>create(
          p_components = lt_comp_key
      ).
*        CATCH cx_sy_struct_creation.  "

    "Create table with new structure

    DATA(lo_table) =
      cl_abap_tabledescr=>create(
          p_line_type = lo_struct
      ).
*        CATCH cx_sy_table_creation.  "

    CREATE DATA es_struct TYPE HANDLE lo_struct.

    CREATE DATA et_table TYPE HANDLE lo_table.
  endmethod.
ENDCLASS.
