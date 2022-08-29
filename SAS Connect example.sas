/*
Client Code/Name: Patient Access
Project Code/Name: 3.294-MMD93 / Commercial ABA Rate Review

Initial Author: Justin Chow

Objective: Pull the MedStat Claims for people with the ICD-9 Codes provided for this disease

Developer Notes: Be sure to update the IndyPAN and ICD9 codes for each update of this program.
				Also get your SAS Connect working before attempting to run this program.
				Libnames need to be assigned on remote machine, not locally.
*/

options sasautos = ("S:\MISC\_IndyMacros\Code\General Routines" sasautos) compress = yes;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/

/*
****** DOCUMENTATION OF INITIAL CHECKING *****
Checking Approach: 

Program Summary above is filled out correctly? _Yes_
All variables clearly defined above; no explicit assumptions embedded in code below? _Yes_
Code is easy to navigate and understand? _Yes_
Detailed narrative precedes each unique section of code indicating purpose of section? _Yes_
Logs saved? _Yes_
Program follows the Method description above? _Yes_
Assumptions & variables reviewed for reasonableness and/or supporting documentation? _Yes_
Results are compared to prior iterations or otherwise tested for reasonableness? _Yes_


*ONLY SIGN IF NO ISSUES REMAIN*
Initial Checker Name: 
Initial Checker Date: 


****** DOCUMENTATION OF SUBSEQUENT CHANGES *****
Change Author & Date: 
Description of Change:
Name of Checker: 
Date of Checking: 
How it was Checked: 
*/



/*
*Replace XXXX with your network password
Then put the sas log output into the symput call below;
proc pwencode in="XXXX";
run;
data _NULL_ / pgm=sasuser.uidpass;
call symput('USERID','justin.chow@milliman.com');
call symput('PASSWORD','{SAS002}E39307252696D3C707A64CDA56CE8923280ACAB0');
run;
*/


*Connect to Chicago server;
data PGM=sasuser.uidpass;
run;

signon;

rsubmit;
*Assign libnames on remote machine;
libname IndyAtsm "\\indy-syn01.milliman.com\health_data\PAN\Autism";
libname ms13com "\\chic-win-fs2\Marketscan\yr2013\Annual\Commercial\Output";

%let ICD9 = '29900';
%let ICD9_Digits = 5;	/*this is the number of characters the ICD9 code is*/
/*%let ICD9_4 = '1830';
%let ICD9_Digits_4 = 4;	/*this is the number of characters the ICD9 code is*/
/*%let ICD9_3 = '252';
%let ICD9_Digits_3 = 3;	/*this is the number of characters the ICD9 code is*/

%let getstates = 'PA','MD','DE','NY','NJ','MI';

%Let Obser = ;
*%Let Obser = obs=100;


*Pull autism claims from processed MarketScan 2012 data;

data IndyAtsm.autistic_claims;
set ms13com.outclaims (keep = ClaimID LineNum MemberID DOB FromDate AdmitDate DRG DRGVersion RevCode HCPCS Modifier Modifier2
							Billed Allowed Paid COB Copay Coinsurance Deductible PatientPay Days Units 
							ICDVersion AdmitDiag ICDDiag1 ICDDiag2 ICDDiag3 ICDDiag4 ICDDiag5 ICDDiag6 ICDDiag7 ICDDiag8
							ICDDiag9 ICDDiag10 ICDDiag11 ICDDiag12 ICDDiag13 ICDDiag14 ICDDiag15 ICDProc1 ICDProc2
							YearMo PaidMo State Gender MemberAgeBand MR_Line MR_Billed MR_Allowed MR_Paid ExclusionCode &Obser.)
;
where state in(&getstates.) and MemberID ne '' and ExclusionCode eq '' and
(
		substr(AdmitDiag,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag1,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag2,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag3,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag4,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag5,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag6,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag7,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag8,1,&ICD9_Digits.) in (&ICD9.) or 
		substr(ICDDiag9,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag10,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag11,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag12,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag13,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag14,1,&ICD9_Digits.) in (&ICD9.) or
		substr(ICDDiag15,1,&ICD9_Digits.) in (&ICD9.)
)
;
run;


*Disconnect from Chicago server;
endrsubmit;
run;

libname IndyAtsm "\\indy-syn01.milliman.com\health_data\PAN\Autism";

data aba_claims;
	set IndyAtsm.autistic_claims;
	where units gt 0 and paid gt 0;

	cost_per_unit = allowed / units;
	HCPCs_Mod = HCPCs||Modifier;
run;

proc summary nway missing data = aba_claims;
	class state HCPCs_Mod;
	var allowed paid units;
	output out = state_HCPCs_Summary (drop = _type_)sum=;
run;

proc univariate data = aba_claims noprint;
	where HCPCS in ('90887', '99080', 'S5108', 'H2019');
	class state HCPCs_Mod;
	var cost_per_unit;
	output out= Cost_Per_Unit_Distn  pctlpts=10 25 50 75 100 pctlpre=P;
run;


%macro Export(dataset);
proc export data = &dataset.
	outfile = "S:\MMD\3.294-MMD93\5-Support_Files\XX-Commercial ABA Rate Review\SAS Results\ABA Marketscan.xls"
	dbms = Excel
	replace;
run;
%mend;

%Export(state_HCPCs_Summary)
%Export(Cost_Per_Unit_Distn)


/***** SAS SPECIFIC FOOTER SECTION *****/
%put System Return Code = &syscc.;

%LogAuditing()
/*There must be a SAS Logs/Error_Check subfolder 
in the same folder as the executing program (which must be saved)
for the LogAuditing macro to save the log and lst files*/
