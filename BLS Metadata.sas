/*
Client Code/Name: Michigan DHHS
Project Code/Name: Minimum Wage Analysis

Initial Author: Justin Chow

Objective:
  Metadata used for all SAS programs in the BLS wage analysis

Developer Notes:
*/

libname MUNC "P:\PHI\MMD\3.291-MMD90\16-Capitation Certification\010_Financial_Reports";
libname MMD90_40 "P:\PHI\MMD\3.291-MMD90\16-Capitation Certification\040_Data_Staging" access=ReadOnly;

%let selected_state = MI;
%let selected_occ = '19-3031','29-1141','29-1171','29-2061','29-2071','31-1011','21-1015','21-1022','21-1093',
					'29-1122','29-1123','31-9099','00-0000','31-0000';
%let dcw_occ = '31-1011','39-9021';
%let DCW_service = "H0043","H2014","H2015","H2016","H2016TF","H2016TG","H2023","T1020","T1020TF","T1020TG","T2036","T2037","T1005","T2015";

%let S_Path = S:\MMD\3.325-MMD26\5-Support_Files\07-Minimum Wage Follow Up;
%let BLS_folder = &S_Path.\Reference;
%let Results_Folder = &S_Path.\SAS Results;

/**** LIBRARIES, LOCATIONS, LITERALS, ETC. GO ABOVE HERE ****/
