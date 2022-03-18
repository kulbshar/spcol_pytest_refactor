/**
Program : create_spcol.sas

Creation Date: Dec2018

Primary client: Lab Programmers/DCs/DMs

Purpose: Create the specimen collection datasets used by specimen
         monitoring and various other LDO processes.

Location: /trials/LabDataOps/managed_code/
              specimen_collection_dataset_creation/src

Author: Haoping Jiang
        additional updates by Radhika Etikala

Project: Across Networks
         SCHARP
         Fred Hutchinson Cancer Research Center

Inputs: /trials/LabDataOps/common/data/
            specimen_collection_dataset_creation/
                specimen_<network>_<protocol>.csv

Outputs: /trials/lab/data/spec/spec_<network>_<protocol>.sas7bdat

NOTES:
    The specimen collection datasets were originally created by the Clinical
    programmers, but was passed to the Lab Programmers after a CAPA. Since
    these datasets depend heavily on CRF data, it is critical that the Lab
    Programmers be kept in the loop if any of this CRF data changes.
**/

%macro get_specimen_data(
    spec_ds_name=,
    crf_form=,
    crf_form_path=,
    pat_var=,
    visit_var=,
    spcol_var=,
    date_var=,
    time_var=,
    comments_var=,
    log_spname_var=,
    crf_style=,
    more_keep_vars=);
/* get/normalize source CRF data for each row in the config CSV */
/*      spec_ds_name: name of specimen dataset to create */
/*      crf_form: name of CRF form dataset */
/*      crf_form_path: path where CRF form dataset exists (qdata) */
/*      pat_var: name of var specifying specimen collection (yes/no) */
/*      visit_var: name of var specifying specimen collection (yes/no) */
/*      spcol_var: name of var specifying specimen collection (yes/no) */
/*      date_var: specimen collection date var in CRF form dataset */
/*      time_var: specimen collection time var in CRF form dataset */
/*      comments_var: specimen collection comment var in CRF form dataset */
/*      log_spname_var: specimen name var in log fomat CRF form dataset */
/*                      only valid for log format CRF files */
/*      crf_style: style of CRF form. Valid values `log` or anything else */
/*                  values other than log treated the same (normal style) */
/*      more_keep_vars: list of additional vars to keep for processing */
/*                      later in the code stub modify_spcol_* */

    %local path_lib_crf;

    %let path_lib_crf = %sysfunc(pathname(lib_crf));

    /* update libname to crf_form_path only if not set */
    /* or different from previous specimen (in the same protocol) */
    %if %sysfunc(libref(lib_crf)) = 0 %then %do;
        %if "&crf_form_path." ~= "&path_lib_crf." %then %do;
            libname lib_crf "&crf_form_path.";
        %end;
    %end;
    %else %do;
        libname lib_crf "&crf_form_path.";
    %end;

    /* populate and clean crf_style for use in data step */
    %if %length(%trim(%left(&crf_style.))) ne 0 %then %do;
        %if %lowcase(%trim(&crf_style.)) eq %str(log) %then %do;
            %let crf_style=log;
        %end;
        %else %do;
            %let crf_style=other;
        %end;
    %end;
    %else %do;
        %let crf_style=none;
    %end;


    data &spec_ds_name.;
        attrib
            spcol_var length = $50
            log_spname_var length = $50
            form length = $50
            crf_style length = $50
            spcol length = 8. label = "LDP normalized specimen collection value"
            spcol_crf length = 8. label = "Original CRF specimen collection value (Numeric)"
            date_var length = $50
            time_var length = $50
            visit length=8 label='Visit Code'
            spcdt length=8 label='Specimen Collection Date' format=date9.
            ;
        set lib_crf.&crf_form.(keep=&pat_var. &visit_var.
                                    &date_var. &time_var.
                                    &spcol_var. &comments_var.
                                    &log_spname_var. &more_keep_vars.);
        /* CODE STUB: run protocol specific modify_qdata code. */
        %if %sysfunc(fileexist(&path_protocol_macros./modify_qdata_&network._&protocol..sas)) %then %do;
            %include "&path_protocol_macros./modify_qdata_&network._&protocol..sas";
        %end;
        %else %do;
            /* round to eliminate mathematical precision problem */
            /* that would affect merges/joins */
            /* convert visit number to numeric type */
            if vtype(&visit_var.)='C' then visit=round(input(&visit_var., 8.) * 100) + 1;
            else if vtype(&visit_var.)='N' then visit=round(&visit_var. * 100) + 1;
            spcdt=&date_var.;
        %end;
        /* convert patient id to numeric type */
        if vtype(&pat_var.)='C' then ptid=input(&pat_var., 9.);
        else if vtype(&pat_var.)='N' then ptid=&pat_var.;

        /* get specimen collection time macrovariable if available */
        %if %length(%trim(%left(&time_var.))) ne 0 %then %do;
            spctm=input(%trim(%left(&time_var.)), time5.);
        %end;
        %else %do;
            spctm=.;
        %end;

        /* get log_spname_var if macro variable is available */
        %if &crf_style.=log
            and %length(%trim(%left(&log_spname_var.))) ne 0 %then %do;
                log_spname_var=&log_spname_var.;
        %end;
        %else %do;
            log_spname_var='';
        %end;

        /* replace any commas or semicolons in more_keep_vars with space */
        %if %length(%trim(%left(&more_keep_vars.))) ne 0 %then %do;
            %let more_keep_vars = %sysfunc(tranwrd(%quote(&more_keep_vars.),';', ' '));
            %let more_keep_vars = %sysfunc(tranwrd(%quote(&more_keep_vars.),',', ' '));
        %end;


        /* store the CRF style in the data set for use in later join */
        crf_style=symget('crf_style');
        spcol_var="&spcol_var.";
        form="&crf_form.";
        form_path="&crf_form_path.";
        date_var="&date_var.";
        time_var="&time_var.";

        /* set spcol per spcol_var note different logic for bsstore */
        %if &spcol_var. = %str(BSSTORE) %then %do;
            if strip(bsstore)='1' then spcol=1;
            else spcol=0;
        %end;
        %else %do;
            /* map various EDC codes to 0=no 1=yes 2=other */
            VAR_TYPE=vtype(&spcol_var.);
            if VAR_TYPE='N' then do;
                spcol_crf = &spcol_var.;
                if &spcol_var.=1 then spcol=1;
                /* not collected */
                else if &spcol_var.=2 then spcol=0;
                /* anything else */
                else spcol=2;
            end;
            else if VAR_TYPE='C' then do;
                spcol_crf = .;
                if &spcol_var. in ('Yes', 'Y', '1') then spcol=1;
                /* not collected */
                else if &spcol_var. in ('No', 'N', '2') then spcol=0;
                /* anything else */
                else spcol=2;
            end;
        %end;

        keep
            ptid visit spcdt spctm spcol spcol_crf
            log_spname_var spcol_var date_var time_var
            form form_path &comments_var. crf_style &more_keep_vars.
            ;
    run;

    proc sort data = &spec_ds_name.;
        by ptid visit spcdt spctm spcol;
    run;

%mend get_specimen_data;

%macro create_spcol;
/* Create specimen collection dataset by normalizing data from crf form */
/* datasets. For each row in the config CSV file, create individual datasets */
/* and then combine. Append enrollment data and flag enrollment visit using the */
/* screen variable. If projected-visits data exists, join to update the */
/* visittxt variable. Join this updated specimen data back to config CSV file */
/* to complete output data. Optionally run protocol-specific code stub to */
/* modify specimen collection data. Output data to SAS dataset and optionally */
/* to CSV file if specified. */

    %if %symexist(enr_ret) %then %do;
        libname enr_ret "&enr_ret.";
    %end;
    %else %do;
        libname enr_ret '/trials/hivnet/data';
    %end;


    /* DATA SET A - read specimen definitions from CSV file */
    data ldo_csv;
        attrib
            spcode length=8
            spalq length=8
            sppurp length=8
            spname length=$100
            log_spname_var length=$50
            crf_form length=$50
            crf_form_path length=$200
            pat_var length=$50
            visit_var length=$50
            spcol_var length=$50
            date_var length=$50
            time_var length=$50
            pk_tp length=8
            pkucode length=8
            comments_var length=$50
            spcol_count_var length=$50
            crf_page length=$50
            crf_style length=$50
            spname_output length=$50
            more_keep_vars length = $500
            
        ;

        infile "&specimen_csv" delimiter=',' dsd truncover firstobs=2;

        input
            spcode
            spalq
            sppurp
            spname
            log_spname_var
            crf_form
            crf_form_path
            pat_var
            visit_var
            spcol_var
            date_var
            time_var
            pk_tp
            pkucode
            comments_var
            spcol_count_var
            crf_page
            crf_style
            spname_output
            more_keep_vars
        ;
    run;


    /* DATA SET A1 distinct combinations of */
    /* dateset/specimen/date/time/comments */
    proc sql noprint;
        create table temp as
            select distinct
                crf_form,
                crf_form_path,
                pat_var,
                visit_var,
                spcol_var,
                date_var,
                time_var,
                comments_var,
                log_spname_var,
                crf_style,
                more_keep_vars
            from
                ldo_csv
            ;
    quit;


    /* populate macrovariable ds_list_count with number of distinct */
    /* combinations of dataset/specimen/date/time/comments (iterations) */
    proc sql noprint;
        select
            count(*) into :ds_list_count
        from
            temp
        ;
    quit;


    /* create macro variable lists for looping */
    proc sql noprint;
        select
            crf_form,
            crf_form_path,
            pat_var,
            visit_var,
            spcol_var,
            date_var,
            time_var,
            comments_var,
            log_spname_var,
            crf_style,
            more_keep_vars
        into
            :crf_form_list separated by '|',
            :crf_form_path_list separated by '|',
            :pat_var_list separated by '|',
            :visit_var_list separated by '|',
            :spcol_var_list separated by '|',
            :date_var_list separated by '|',
            :time_var_list separated by '|',
            :comments_var_list separated by '|',
            :log_spname_var_list separated by '|',
            :crf_style_list separated by '|',
            :more_keep_vars_list separated by '|'
        from
            temp
        ;
    quit;

    /* CODE STUB: run protocol specific format code. */
    %if %sysfunc(fileexist(&path_protocol_macros./custom_format_&network._&protocol..sas)) %then %do;
        %include "&path_protocol_macros./custom_format_&network._&protocol..sas";
    %end;

    /* create individual specimen datasets for each row in the CSV file */
    %do i=1 %to &ds_list_count.;
        %get_specimen_data(
            spec_ds_name=specimen_%scan(&crf_form_list., &i., '|', m)_&i.,
            crf_form=%scan(&crf_form_list., &i., '|', m),
            crf_form_path=%scan(&crf_form_path_list., &i., '|', m),
            pat_var=%scan(&pat_var_list., &i., '|', m),
            visit_var=%scan(&visit_var_list., &i., '|', m),
            spcol_var=%scan(&spcol_var_list., &i., '|', m),
            date_var=%scan(&date_var_list., &i., '|', m),
            time_var=%scan(&time_var_list., &i., '|', m),
            comments_var=%scan(&comments_var_list., &i., '|', m),
            log_spname_var=%scan(&log_spname_var_list., &i., '|', m),
            crf_style=%scan(&crf_style_list., &i., '|', m),
            more_keep_vars=%scan(&more_keep_vars_list., &i., '|', m));
    %end;


    /* DATA SET B - all specimens */
    /* colon operator combines all specimen_ prefixed data sets */
    data all_specimen;
        set specimen_:;
    run;

    proc sort data = all_specimen;
        by ptid visit;
    run;


    /* DATA SET C - enrollment */
    proc sql;
        create table enr as
        select
            network,
            protocol,
            ptid,
            inactdt as termdt,
            site,
            sitedfno,
            currsite,
            currdfno,
            enrollvs
        from
            enr_ret.&enrds.
        order by
            ptid
        ;
    quit;


    /* DATA SET E - merge all_specimen (B) with enrollment data set (C) */
    /* only include if record is in both specimen and enrollment datasets */
    /* calculate whether or not the visit is a screening visit */
    data all_specimen;
        merge
            enr (in=inenr)
            all_specimen (in=inspec);
        by ptid;
        if inenr=1 and inspec=1;

        attrib screen length=8 label='Screening Specimen' format=noyesna. ;

        /* Determine whether the specimens were drawn at a screening visit. */
        if visit < enrollvs then
            screen=1;
        else
            screen=0;
    run;


    %if %symexist(retds) %then %do;
        %if %sysfunc(exist(enr_ret.&retds.)) %then %do;
            /* DATA SET D - retention */
            proc sql;
                create table ret as
                select
                    ptid,
                    visit,
                    vislabel as visittxt
                from
                    enr_ret.&retds.
                order by
                    ptid,
                    visit
                ;
            quit;

            /* DATA SET F - merge all_specimen (E) with retention data set (D) */
            /* calculate visit labels */
            proc sort data=all_specimen;
                by ptid visit;
            run;

            data all_specimen (drop=enrollvs);
                merge
                    all_specimen (in=a)
                    ret (in=r);
                by ptid visit;
                if a;

                /* retention dataset only contains records for visits after */
                /* enrollment, therefore calculate visitxt for enrollment */
                /* and screening visits if the visit label is missing and */
                /* it is an enrollment/screening visit */
                if missing(visittxt) then do;
                    if visit < enrollvs then
                        visittxt='Screening';
                    else if visit=enrollvs then
                        visittxt='Enrollment';
                    else
                        visittxt='Visit ' || put(visit, 6.);
                end;
            run;
        %end;
    %end;

    /* DATA SET G - merge LDO CSV file (A) with specimen collection data (F) */
    /* join per crf_style and append results (union) */
    /* using select star, because of protocol-specific columns like ptidmi */
    proc sql;
        create table spcol_raw as
        select
            all_specimen.*,
            ldo_csv.spcode,
            ldo_csv.spalq,
            ldo_csv.sppurp,
            ldo_csv.pk_tp,
            ldo_csv.pkucode,
            ldo_csv.spname_output,
            case
                when ldo_csv.spname_output is not null
                    then ldo_csv.spname_output
                else ldo_csv.spname
                end as spname
        from
            all_specimen
            left join ldo_csv
                on upcase(all_specimen.form) = upcase(ldo_csv.crf_form)
                and upcase(all_specimen.form_path) = upcase(ldo_csv.crf_form_path)
                and upcase(all_specimen.log_spname_var) = upcase(ldo_csv.spname)
                and upcase(all_specimen.date_var) = upcase(ldo_csv.date_var)
                and upcase(all_specimen.time_var) = upcase(ldo_csv.time_var)
                
        where
            lowcase(all_specimen.crf_style) eq 'log'

        union all
        select

            all_specimen.*,
            ldo_csv.spcode,
            ldo_csv.spalq,
            ldo_csv.sppurp,
            ldo_csv.pk_tp,
            ldo_csv.pkucode,
            ldo_csv.spname_output,
            case
                when ldo_csv.spname_output is not null
                    then ldo_csv.spname_output
                else ldo_csv.spname
                end as spname
        from
            all_specimen
            left join ldo_csv
                on upcase(all_specimen.form) = upcase(ldo_csv.crf_form)
                and upcase(all_specimen.form_path) = upcase(ldo_csv.crf_form_path)
                and upcase(all_specimen.spcol_var) = upcase(ldo_csv.spcol_var)
                and upcase(all_specimen.date_var) = upcase(ldo_csv.date_var)
                and upcase(all_specimen.time_var) = upcase(ldo_csv.time_var)
        where
            all_specimen.crf_style is null
            or lowcase(all_specimen.crf_style) ne 'log'

        order by
            ptid,
            visit
        ;
    quit;


    /* CODE STUB: run protocol specific code at path_protocol_macros */
    %if %sysfunc(fileexist(&path_protocol_macros./modify_spcol_&network._&protocol..sas)) %then %do;
        %include "&path_protocol_macros./modify_spcol_&network._&protocol..sas";
    %end;


    /* DATA SET H - set lengths and labels and output the dataset */
    data spcol_raw;
        attrib
            network length=$10 label='Network'
            protocol length=8 label='Protocol Number'
            ptid length=8 label='Participant ID'
            termdt length=8 label='Date of Termination' format=date9.
            form length=$50 label='Form'
            site length=$35 label='Site'
            sitedfno length=8 label='Site Number'
            currsite length=$30 label='Current Site'
            currdfno length=8 label='Current Site Number'
            visit length=8 label='Visit Code'
            visittxt length=$40 label='Visit'
            spcdt length=8 label='Specimen Collection Date' format=date9.
            spctm length=8 label='Specimen Collection Time' format=time5.
            spname length=$100 label='Name of Specimen'
            spcode length=8 label='Specimen Code' format=spectyp.
            spalq length=8 label='Specimen Aliquot Code' format=alqtyp.
            sppurp length=8 label='Specimen Purpose Code' format=specpurp.
            spcol length=8 label='Specimen Is Collected' format=noyesna.
            pk_tp length=8 label='PK Timepoint'
            pkucode length=8 label='PK Time Units' format=pkunits.
            screen length=8 label='Screening Specimen' format=noyesna.
            log_spname_var length=$50 label='Specimen Name Variable in Log Format CRFs'
            spcol_var length=$50 label='Name of CRF Specimen Collection Variable'
            ;

        set spcol_raw (drop=crf_style spname_output spcol_crf form_path);
    run;


    data outdata.spec_&network._&protocol.;
        set spcol_raw;
    run;


    %if %symexist(export_csv_dataset) %then %do;
        %if %length(%trim(%left(&export_csv_dataset.))) ne 0 %then %do;
            %if %lowcase(%trim(&export_csv_dataset.)) eq %str(yes) %then %do;

                %let path_outdata=%sysfunc(pathname(outdata));

                proc export data=spcol_raw
                    outfile="&path_outdata./spec_&network._&protocol..csv"
                    dbms=csv
                    replace;
                run;
            %end;
        %end;
    %end;

%mend create_spcol;


/* main program */
options mprint mlogic symbolgen source2;

/* parse command line parameters into global macro variables */
/* variables passed from create_spcol.py, specified in spcol_config.json */
%symparse;

libname outdata "&path_outdata.";
libname fmtlib "&path_fmtlib.";
%let path_protocol_macros = &path_protocol_macros.;
%let specimen_csv=&path_protocol_config./specimen_&network._&protocol..csv;

/* Make the general formats available */
options append=(fmtsearch=(fmtlib));

%create_spcol;
