*Indy macros;
%include "S:\IndyHealth_Library\include_sas_macros_redirect.sas" / source2;
options compress = yes mprint noquotelenmax;
option spool = yes;

options sasautos = ("S:\MISC\_IndyMacros\Code\General Routines" sasautos) compress = yes;

/*CopyRoboCopy (IndyMacro) to bring datasets to local workspace*/
%CopyRoboCopy(
    sourcedir       = %sysfunc(pathname(elig))
    ,destinationdir = %sysfunc(pathname(work))
    ,file           = elgblty_2020*
    ,sas_options    = noxwait xsync
    ,options        = /r:20
    ,quote_filearg  = No
);


/*Delete datasets*/
proc datasets noprint library = work;
  delete capitation_&yearmo.;
  delete Exposure_&yearmo.;
  quit;
run;


/*Create format statement with drugs found*/
data NDC_fmt(keep = Start Label FmtName Type HLo);
	set Fund_Drug_NDCs (Rename = (NDCNUM = Start RXName = Label)) end=fini;
	format fmtname $6. Type $1.;
	FmtName = "&Fund.";
	Type = 'J';
	output;

	if Fini then do;
		Start = .;
		Label = 'Missing';
		Hlo = 'O';
		output;
	end;
run;

proc sort nodupkey data=NDC_fmt;
	by Start;
run;

proc format cntlin=NDC_fmt;
run;


*proc rank gets creates a field that shows the rank of data, and you are then able to cut out top X of N;
proc rank
	data=low_summ out=low_summ_rank	ties=low descending;
	by Patient_County Year;
	var Allowed;
	ranks Allowed_Rank;
run;

data low_summ_final;
	set low_summ_rank;
	where Allowed_Rank LE 10;
run;



*proc univariate gets percentiles from claim line data;
proc univariate data = impmktsn.mktscan_13 noprint;
	class State HCPCS;
	var MR_Allowed MR_Paid;
	output out = mktscan_13_pct  pctlpts = 10 25 50 75 90 99 pctlpre = Allowed_ Paid_;
run;



*proc SQL left join example - the left table is the big dataset;
*This creates a duplicate row if the right dataset has one-to-many relationship of PUMA;
proc sql;
	create table SCM_ACS_county as
	select a.*, b.SC_county, b.PUMA_allocation
	from SC_acs_data as a
	left join SCM_county as b
	on a.PUMA = b.PUMA;
quit;

*proc SQL cross join example - this creates a dataset that has all combinations of data from both tables;
proc sql;
	create table cw_all_months as
	select *
	from cw_elig CROSS JOIN months;
quit;


*proc sort can also remove duplicate data by a given field;
proc sort nodupkey data = mod_codes(keep = CLAIM_CONTROL_NUMBER PROC_CODE_MODIFIER); 
	by CLAIM_CONTROL_NUMBER;
run;

*Interval function that can seek out the first/last day of a month;
date = intnx('month','01jan95'd,0,'beginning');

*Interval function that can calculate the # of months distance;
date_distance = intck('month','01jan1995'd,'04apr1995'd);

*Date Comparison - Using "d" after a value tells SAS it is a date;
data mmd.past12mo;
	set tanf_new_data;
	where source_month between "01OCT2012"d and "30SEP2013"d;
	if class = 'TANF' and source_month > '31MAR2013'd;

*Add leading zeroes to a character variable;
	BenID = put(input(BENEFICIARY_ID,best12.),z10.);

*Remove blank spaces in a field;
	full_service_code = compress(HCPCS_Code||Modifier,,'s');

*Apply format statement;
	service_category = input(full_service_code,$munc_svc_cat.);

*Compress function lets us combine numeric and character values in one field - WITHOUT WARNING MESSAGE;
	quarter = compress(fy||calc_qtr);

*Coalesce function allows you to populate a field with more than one field, determined by order of fields - if null, move to next field;
	Service_Category = coalescec(EUM_DRG, EUM_PROC, EUM_REV);
	*Numeric fields use coalesce, while character fields use coalesceC;
	Number_Fill = coalesce(1,2,3);

*Substring the first 3 characters of a field;
	REVENUE_CODE_3 = substr(REVENUE_CODE,1,3);

*Assign fiscal year (FY) based on month in year;
	format fy 12.;
	if month(eligmth) >= 10 and month(eligmth) <= 12 then fy = year(eligmth) + 1;
	else fy = year(eligmth);

*Replace certain text in a field with other text;
	ageband = tranwrd(agegroup,'-',' - ');

*keep and rename variables within the DATA step;
	keep wanted_var1 wanted_var2 wanted_var3;
	drop unwanted_var;
	rename wanted_var2 = renamed_var2
		wanted_var3 = renamed_var3;
run;


*Loop through dates on a monthly basis;
%macro date_loop(start,end);
	/*converts the dates to SAS dates*/
	%let start=%sysfunc(inputn(&start,anydtdte9.));
	%let end=%sysfunc(inputn(&end,anydtdte9.));
	/*determines the number of months between the two dates*/
	%let dif=%sysfunc(intck(month,&start,&end));
	%do i=0 %to &dif;
	/*advances the date i months from the start date and applys the DATE9. format*/
		%let date=%sysfunc(putn(%sysfunc(intnx(month,&start,&i,b)),date9.));
		%put &date;
			startmonth = "&date."d;
			output;
	%end;
%mend;


*Future improvements: Include separate certification for Q1/Q2 and Q3/Q4 DABTANF, include HMP & HSW;
data all_certified_cap;
	set FY&NxNxYr._CertifiedCap;
	format fy 12. startmonth mmddyy10.;
	fy = 20&NxNxYr.;
	
	%date_loop(01OCT20&NxYr.,01SEP20&NxNxYr.)
run;


*When stacking multiple datasets, keep track of the names of each;
data DeltaDental_ExpandArea;
    set ENCData.Enc_Delexpandarea20:
    		ENCData.Delexpandarea20:
    		ENCData.Encexpandarea20:
        indsname=source /* INDSNAME= option keeps track of name of source data set */
    ;
  dsname = scan(source,2,'.'); /* extract the dataset name */
  format entry_date $8.;
  entry_date = substr(dsname,length(dsname)-7,8);
run;
*Variant: Assign Incurred_Month field with date format;
data _elgblty_cy20;
	set elgblty_2020:
  	INDSNAME=Source;

	dataset=scan(source,2,'.');
  format Incurred_Month mmddyy10.;
  Incurred_Month = mdy(substr(dataset,length(dataset)-1,2),1,substr(dataset,length(dataset)-5,4));
run;



*Hash table example - much faster than data merge step;
data hcg_out.outclaims_w_avoid_fixlob;
	set hcg_out.outclaims_w_avoid_fixlob;
	format Gender $1. srcLOB $10. LOB $3. srcProduct $40. Product $3. GroupID $40.;

	if _N_ eq 1 then do;
		call Missing(Gender_dd,srcLOB_dd,LOB_dd,srcProduct_dd,Product_dd,GroupID_dd);
		declare hash waiverc_ht(dataset:"hcg_out.outmembermonths");
		waiverc_ht.definekey("MemberID","YearMo");
		waiverc_ht.definedata("Gender","srcLOB","LOB","srcProduct","Product","GroupID");
		waiverc_ht.definedone();
	end;

	matches = waiverc_ht.find();
	drop matches;
run;


*To apply logic within a macro, use % sign;
%macro Map_MIChild(fy);
data fy&fy._qi_MI_child;
	set fy&fy..fy&fy._qi (rename = (
		%if &fy. = 12 %then %do;
		CMH_Provider = CMH_Provider_ID
		%end;
		MEDICAID_ID = BenID));
	format MI_Child_flag 12.;
run;

%mend;

%Map_MIChild(12);
%Map_MIChild(13);




%macro Assign_Module(module,description);
	/** Note that the %let statement within a macro will place the variable in the most local table, NOT in the global table **/
	/**Use call symput instead**/
	%global &module._Cde;
	%let &module._Cde = %sysget(UserProfile)\repos\indy-github.milliman.com\Specialty-Services-Capitation-Rate-Setting\&description.;
	%global &module._Log;
	%let &module._Log = &S_Path.\SAS Programs\&description.\SAS Logs;
	libname &module._lib "&P_Path.\&description.";
%mend;


*Bootstrap technique - including selection of random sample data;
%macro bootstrap(hcg,trials);
%do i = 1 %to &trials.;
*Create random sample of source data, stratified by MEG_CODE;
proc surveyselect noprint data = boot_chronic_&hcg.
			method = URS /*unrestricted random sampling with replacement*/
			n = strata_size_&hcg.
			/*seed = 6391000*/
			out = boot_sample_&hcg. (keep = HCGINDICATOR MEG_CODE MEG_ROLLUP MEG_TYPE MEG_HSTAGE TOTAL_BILLED TOTAL_ALLOWED)
			outhits; /*option to show observations that have already been picked*/
			strata HCGINDICATOR MEG_CODE MEG_HSTAGE;
run;

*Take the mean of random sample, according to MEG_CODE & MEG_HSTAGE;
proc summary nway missing data = boot_sample_&hcg.;
	class HCGINDICATOR MEG_CODE MEG_HSTAGE;
	var TOTAL_BILLED TOTAL_ALLOWED;
	output out = boot_temp_&hcg. (drop = _type_ rename = (_freq_ = samples)) mean=/autoname;
run;

*Append summaries of future runs to a single output;
proc append base = boot_means_&hcg.
	data = boot_temp_&hcg.;
run;
%end;
%mend bootstrap;

%bootstrap(l,1000);


*Store column names into a variable to use in KEEP statement;
proc sql noprint;
	select name
	into :mara_vars
	separated by ' '
	from dictionary.columns
	where upcase(libname) = "WORK"
	and upcase(memname) = "CONDITIONS_WIDE_TOP"
	and upcase(name) not in ('_NAME_');
quit;
%put &mara_vars.;


*Stack all nodup datasets in WORK space together and save to one dataset;
proc sql noprint;
	select
		catx('.',libname,memname)
		into :nodup_datasets separated by ' '
		from dictionary.tables
	where
		libname eq "WORK"
		and memname like "FY15_MHSA_NODUP%"	/*Must be CAPITALIZED b/c LIKE is case-Senstive*/
	;
quit;

data proj.fy&NxYr._mhsa_nodup;
	set &nodup_datasets.;
run;


*Select all of the fields that have all null values into the &eqd_nulls. macro variable;
ods select none;
ods output nlevels=temp;
proc freq data = eqd_claims nlevels;
    tables _all_;
run;
ods select all;
proc sql noprint;
	select tablevar into : eqd_nulls separated by ' '
		from temp
		where NNonMissLevels=0;
	%put &eqd_nulls;
quit;



*Calculate fields from a dataset using proc sql, then storing it in a macro variable;
proc sql noprint;
	select sum(total_dollars)
	into :pre_cmh_dollars trimmed
	from &mhsa._enc_benids_svc_cat
	;

	select sum(total_dollars)
	into :post_cmh_dollars  trimmed
	from &mhsa._enc_monthly_svc_cat
	;

	select sum(total_dollars)
	into :pre_cmh_dollars_agg trimmed
	from &mhsa._enc_benids_total
	;

	select sum(total_dollars)
	into :post_cmh_dollars_agg  trimmed
	from &mhsa._enc_monthly_agg
	;
quit;
%put pre_cmh_dollars = &pre_cmh_dollars.;
%put post_cmh_dollars = &post_cmh_dollars.;



*Use an array to assign 0 values where null values exist in all columns;
data dabtanf_r_cap;
	set dabtanf_tp;
	array test{*} _numeric_;
	do i = 1 to dim(test);
		if test(i) = . then test(i) = 0;
	end;
run;


*When writing an inline dataset, it is possible to use macro variables inside of the values;
*Example below tells SAS to evaluate the macro variables and save as new fields;
data example (keep = meta_field meta_field_label);
	length meta_field_stage meta_field_label_stage meta_field meta_field_label $40.;
	input meta_field_stage $ meta_field_label_stage $;
	infile datalines dsd delimiter = ',';
	meta_field=dequote(resolve(quote(meta_field_stage)));
	meta_field_label=dequote(resolve(quote(meta_field_label_stage)));
	datalines;
&meta_field_1, &meta_field_label_1
&meta_field_2, &meta_field_label_2
&meta_field_3, &meta_field_label_3
&meta_field_4, &meta_field_label_4
&meta_field_5, &meta_field_label_5
;
run;



*proc import to import a named range from Excel - note labels are specified NONE (remove DBSASLABEL to include labels);
proc import out = work.&range. 
            datafile = "%GetParentFolder(1)Format Statements\&format..xlsx"
            dbms = EXCEL REPLACE;
     RANGE="&range."; 
     GETNAMES=YES;
     MIXED=NO;
     SCANTEXT=YES;
     USEDATE=YES;
	 DBSASLABEL=NONE;
     SCANTIME=YES;
run;

*Import a CSV file, with header rows (DATAROW = 2);
proc import out = WORK.enrollment_cpsc 
            DATAFILE= "S:\Prospect\Magellan\SNP Data\CMS data\CPSC_Enrollment_Info_2014_10.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
run;

*Import an Excel sheet and create all combinations - per tables statement in PROC FREQ;
proc import out = work.EncInitialize 
            datafile = "%GetParentFolder(1)Qlikview\Service References.xlsx"
            dbms = EXCEL REPLACE;
     SHEET="EncInitialize"; 
     GETNAMES=YES;
     MIXED=NO;
     SCANTEXT=YES;
     USEDATE=YES;
	 DBSASLABEL=NONE;
     SCANTIME=YES;
run;

proc freq data = EncInitialize noprint;
    tables planname*rptgrp*cm_ratecell*cos*data_source/sparse out = EncInterim;
run;



*proc export;
proc export data = lscc_deliver
	outfile = "&Results_Folder.\Seton Data Summ.xls"
	DBMS = Excel
	replace;
run;

/*Export results to Access for QVW*/
%macro Export(dataset, outtable);
proc export 
	DATA = &dataset.
	OUTTABLE = "&outtable."
	DBMS = ACCESS
	REPLACE;
	DATABASE = "&P_Path.\QVW_Input_Data.mdb";
run;
%mend;

%Export(elig_all_qtr, Eligibility)
%Export(mhsa_enc_monthly_detail, Encounters)


*Passing macro variables with commas as parameters into a macro function;
%let Class_Vars_Comma = 'Population,Rate_Cell,Health_Plan';
%map_exposures(sc,%bquote(&Class_Vars_Comma));

%macro map_exposures(desc,vars);
data outset;
	set inset;

	format Exposure_Units best12.;
	if _N_ eq 1 then do;
	  call Missing(Exposure_Units);
	  declare hash eqd_ht(dataset:"EQD_Exposure_summary");
		eqd_ht.definekey('Data_Source',%unquote(&vars));	/*unquote function tells SAS to unquote special characters*/
	  eqd_ht.definedata("Exposure_Units");
	  eqd_ht.definedone();
	end;
	matches = eqd_ht.find();
	drop matches;
run;
%mend map_exposures;



%AssertDataSetNotPopulated(unmatched_negatives,ReturnMessage=There are unmatched negative payments);
%AssertNoDuplicates(DataSetName,IDVars,ReturnMessage=Assertion failure in current program,FailAction=);


*Create one record per month based on the given start & end dates (DHIP-specific);
data dhip_months;
	set dhip_eligibility;
	by BenID;

	*assign the global end dates for our time-window eligibility file;
	format global_end MMDDYY10.;
	global_end = '31OCT2014'd;

	*Now make the small windows;
	format dhip_start dhip_end startmonth endmonth MMDDYY10.;
	retain dhip_start dhip_end;

	if first.BenID then do;
	dhip_start = start_date;
	dhip_end = min(end_date,global_end);
	end;

	else do;
	dhip_end = min(dhip_start-1,end_date);
	dhip_start = min(dhip_start,start_date);
	end;

	endmonth = min(intnx('month',dhip_end,0,'end'),global_end);
	startmonth = intnx('month',endmonth,0,'begin');
	output;

	*Create one record per member month;
	do while (startmonth GT dhip_start);
		endmonth = startmonth - 1;
		startmonth = max(intnx('month',endmonth,0,'begin'),dhip_start);
		output;
	end;

	drop global_end;
run;

*Create one record per month based on the given start & end dates (Generalized);
data patient_share_hcbs;
	set _stg_patient_share_hcbs;
	by MemberID;

	*assign the global end dates for our time-window eligibility file;
	format global_end MMDDYY10.;
	global_end = "31DEC2021"d;

	*Now make the small windows;
	format pat_start pat_end startmonth endmonth MMDDYY10.;

	pat_start = from_date;
	pat_end = min(to_date,global_end);

	endmonth = min(intnx('month',pat_end,0,'end'),global_end);
	startmonth = intnx('month',endmonth,0,'begin');
	output;

	*Create one record per member month;
	do while (startmonth GT pat_start);
		endmonth = startmonth - 1;
		startmonth = max(intnx('month',endmonth,0,'begin'),pat_start);
		output;
	end;

	drop global_end;
run;

*Assign Rate_Cell_ID and loop by creating a do loop in the IF statement;
data ibnp_medical;
	set ibnp_03;

	format Rate_Cell_ID $4.;
	if program = "CFC" then do i = 1 to 9;
		Rate_Cell_ID = "RC0"||substr(reverse(i),1,1);
		output;
	end;
run;


/*
Proc Transpose where the BY variable (BenID) is not a unique - just transpose twice
*/
*Transpose BenID/diagnosis columns where dd_diag = 1;
data dd_diag_enc;
	set encounter_wdiag_dd;
	where benid NE "" and dd_diag = 1;
	keep benid diag1 diag2 diag3 diag4 diag5;
run;

proc transpose data= dd_diag_enc out= dd_diag_benids(rename=(_name_ = old_var));
	by BenID; /*down*/
	var diag1 diag2 diag3 diag4 diag5; /*inside*/
run;

proc transpose data=dd_diag_benids out=dd_diag_benids_2(drop=_: rename = (col1=values) where = (not missing(values)));
  by BenID old_var;
  var col:;
run;



/***** SAS SPECIFIC FOOTER SECTION *****/
%put System Return Code = &syscc.;

%LogAuditing();
/*There must be a SAS Logs/Error_Check subfolder 
in the same folder as the executing program (which must be saved)
for the LogAuditing macro to save the log and lst files*/
