/*
Client Code/Name: Michigan DHHS
Project Code/Name: Minimum Wage Analysis

Initial Author: Justin Chow

Objective:
  Extract the wage levels of DCW workers for all states

Developer Notes:
  Other techniques are used to separate DCW wages into other geographic areas.
*/

options sasautos = ("S:\MISC\_IndyMacros\Code\General Routines" sasautos) compress = yes;

%include "%GetParentFolder(0)BLS Metadata.sas";

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/


/*
****** DOCUMENTATION OF INITIAL CHECKING *****
Checking Approach: <Checker should give a brief description of major components of review>

Program Summary above is complete and useful? _Yes_No_
All variables clearly defined above; no explicit assumptions embedded in code below? _Yes_No_
Code is easy to navigate and understand; useful names are used for all things? _Yes_No_
Assumptions & variables reviewed for reasonableness and/or supporting documentation? _Yes_No_
Results are compared to prior iterations or otherwise tested for reasonableness? _Yes_No_

*ONLY SIGN IF NO ISSUES REMAIN*
Initial Checker Name:
Initial Checker Date:

****** DOCUMENTATION OF SUBSEQUENT CHANGES *****
Change Author & Date:
Description of Change:
Name of Checker:
Date of Checking:
How it was Checked:

Change Author & Date:
Description of Change:
Name of Checker:
Date of Checking:
How it was Checked:
*/


*Import BLS wage data;
%macro Import_BLS(year_folder,BLS_file,type);
PROC IMPORT OUT = &year_folder._&type.
            DATAFILE = "&BLS_folder.\&year_folder.\&BLS_file."
            DBMS = EXCEL REPLACE ;
	GETNAMES=YES;
	MIXED=NO;
	SCANTEXT=YES;
	USEDATE=YES;
	SCANTIME=YES;
RUN;
%mend;

%Import_BLS(oesm12ma,BOS_M2012_dl.xls,BOS);
%Import_BLS(oesm12ma,MSA_M2012_dl_2_KS_NY.xls,MSA);
%Import_BLS(oesm13ma,BOS_M2013_dl.xls,BOS);
%Import_BLS(oesm13ma,MSA_M2013_dl_2_KS_NY.xls,MSA);
%Import_BLS(oesm14ma,BOS_M2014_dl.xlsx,BOS);
%Import_BLS(oesm14ma,MSA_M2014_dl.xlsx,MSA);


%macro Limit_BLS(year);
data bls_20&year.;
	format area_name $71.;
	set oesm&year.ma_bos (drop = area)
		oesm&year.ma_msa (drop = area);
	where occ_code in (&dcw_occ.,&selected_occ.);
run;
%mend;

%Limit_BLS(12)
%Limit_BLS(13)
%Limit_BLS(14)

data bls_3year_statewide;
	set bls_2012 (in = a)
		bls_2013 (in = b)
		bls_2014 (in = c);

	format year 12.;
	if a then year = 2012;
	if b then year = 2013;
	if c then year = 2014;
	keep year prim_state area_name occ_code occ_title tot_emp h_mean h_pct10 h_pct25 h_median h_pct75 h_pct90;
run;

proc sort data = bls_3year_statewide;
	by prim_state;
run;


/* We currently export the BLS 3-year data and County eligibility separately.
	It is too complicated to merge in SAS without PROC SQL and special handling. */
%macro Export(dataset);
proc export data = &dataset.
	outfile = "&Results_Folder.\BLS_results.xls"
	dbms = Excel
	replace;
run;
%mend;

%Export(bls_3year_statewide)


/***** SAS SPECIFIC FOOTER SECTION *****/
%put System Return Code = &syscc.;

%LogAuditing()
/*There must be a SAS Logs/Error_Check subfolder 
in the same folder as the executing program (which must be saved)
for the LogAuditing macro to save the log and lst files*/
