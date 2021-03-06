*******************************************************************************;
* Program           : prepare-cfs-for-nsrr.sas
* Project           : National Sleep Research Resource (sleepdata.org)
* Author            : Michael Cailler
* Date Created      : 20140715
* Purpose           : Prepare Sleep Heart Health Study data for deposition on
*                       sleepdata.org.
*******************************************************************************;

*******************************************************************************;
* Establish CFS options and libraries
*******************************************************************************;
  %include "\\rfawin\bwh-sleepepi-cfs\SAS\Family options and libnames.sas";
  %include "&newfamilypath\nsrr-prep\sleepepi-sas-macros.sas";
  libname nsrrdata "&newfamilypath\nsrr-prep\_datasets";
  libname obf "&newfamilypath\nsrr-prep\_ids";
  %let release = 0.5.0;

********************************************************;
* Import CFS data
********************************************************;
*previously combined data;
data combined_rectypes /*nsrrdata.combined_rectypes_original*/;
  set family.cfs_combined_rectypes_07102014;
run;

data original_rectype5;
  set family.lab;
run;

********************************************************;
* Use PROC CONTENTS to identify RecType5 variables
********************************************************;

proc contents data = combined_rectypes out = combined_rectypes_contents noprint;
run;

proc contents data = original_rectype5 out = original_rectype5_contents  noprint;
run;

proc sort data = combined_rectypes_contents;
by name;
run;

proc sort data = original_rectype5_contents;
by name;
run;

data rectype5vars;
  merge original_rectype5_contents (in = a) combined_rectypes_contents (in = b);
  by name;
  if a and b;
run;

/*
proc sort data = rectype5vars;
  by varnum;
run;

proc sql;
  select varnum, name, label
  from rectype5vars;
quit;
*/

********************************************************;
* NULL Variables where it's obvious and known that zeros
*       were sometimes mistakenly used in lieu of NULL
********************************************************;

proc sql noprint;
  select name into :known_rec5vars_inneedof_NULLing separated by ' '
  from rectype5vars
  where (600 le varnum le 607) or (640 le varnum le 642) or (varnum in(363,1014,1015,1018,1019,1020,1023,1024)) or (1130 le varnum le 1137)
          or (varnum in(1139,1141,1142,1143,1858,1859)) or (1928 le varnum le 1956) or (1989 le varnum le 2020) or (varnum in(1983,1984)) or (2330 le varnum le 2335)
          or (2350 le varnum le 2358) or (2070 le varnum le 2078) or (2080 le varnum le 2082) or (2087 le varnum le 2093) or (2095 le varnum le 2097) or (2099 le varnum le 2101)
          or (2107 le varnum le 2109) or (2113 le varnum le 2135 and varnum not in(2122,2126)) or (2140 le varnum le 2145) or (2147 le varnum le 2155) or (2157 le varnum le 2159)
          or (2162 le varnum le 2164) or (2166 le varnum le 2168) or (2170 le varnum le 2172) or (2175 le varnum le 2186) or (2189 le varnum le 2191) or (2193 le varnum le 2195)
          or (2197 le varnum le 2199) or (2232 le varnum le 2240) or (2242 le varnum le 2249 and varnum not in(2243,2245))
  ;
quit;

%put &known_rec5vars_inneedof_NULLing;

*add variables to NULL that were not captured in above step;
%let additional_variables_to_NULL = brolive acetaday oindex prelmrdi momdied daddied diffwgt IBUPRDAY
;

*sort by personi and rectype;
proc sort data=combined_rectypes;
  by PERSONI RECTYPE;
run;

data combined_rectypes_NULL_err0;
  set combined_rectypes;

  array set0negs_tonull[*] &known_rec5vars_inneedof_NULLing &additional_variables_to_NULL;

  do i = 1 to dim(set0negs_tonull);
    if set0negs_tonull[i] le 0 then set0negs_tonull[i] = .;
  end;
  drop i;

run;

/*
data nsrrdata.combined_rectypes_pass1_20140716;
  set combined_rectypes_NULL_err0;

  attrib _all_ label = "";
  format _all_;
run;
*/

********************************************************;
* Restrict dataset to RecType5 Visits /
*   Drop variables that were not collected in RecType5
********************************************************;

data rectype5_NULL_err0;
  set combined_rectypes_NULL_err0;
  if rectype = 5;
run;

*drop RecType5 Variables with no Observed Values;
data _null_;
  set Rectype5_null_err0 (obs=1);
  array num_vars[*] _NUMERIC_;
  array char_vars[*] _CHARACTER_;
  call symputx('num_qty', dim(num_vars));
  call symputx('char_qty', dim(char_vars));
run;

data _null_;
  set Rectype5_null_err0 end=finished;

  /* Use the reserved word _NUMERIC_ to load all numeric variables  */
  /* into the NUM_VARS array.  Use the reserved word _CHARACTER_ to */
  /* to load all character variables into the CHAR_VARS array.      */
  array num_vars[*] _NUMERIC_;
  array char_vars[*] _CHARACTER_;

  /* Create 'flag' arrays for the variables in NUM_VARS and CHAR_VARS. */
  /* Initialize their values to 'missing'.  Values initialized on an   */
  /* array statement are retained.                                     */
  array num_miss [&num_qty] $ (&num_qty * 'missing');
  array char_miss [&char_qty] $ (&char_qty * 'missing');

  /* LIST will contain the list of variables to be dropped.  Ensure  */
  /* it's length is sufficient.                                      */
  length list $ 5000;

  /* Check for non-missing values.  Reassign the corresponding 'flag' */
  /* value accordingly.                                               */
  do i=1 to dim(num_vars);
    if num_vars(i) ne . then num_miss(i)='non-miss';
  end;
  do i=1 to dim(char_vars);
    if char_vars(i) ne '' then char_miss(i)='non-miss';
  end;

  /* On the last observation of the data set, if a 'flag' value is still */
  /* 'missing', the variable needs to be dropped.  Concatenate the       */
  /* variable's name onto LIST to build the values of a DROP statement   */
  /* to be executed in another step.                                     */
  if finished then do;
  do i= 1 to dim(num_vars);
    if num_miss(i) = 'missing' then list=trim(list)||' '||trim(vname(num_vars(i)));
  end;
  do i= 1 to dim(char_vars);
    if char_miss(i) = 'missing' then list=trim(list)||' '||trim(vname(char_vars(i)));
  end;
  call symput('mlist',list);
  end;
run;

%put &mlist;

data rectype5_narrowedvars;
  set rectype5_NULL_err0;

  drop &mlist;
run;

%let pass1_droplist = inall incatecholamine incrp incrpsnp incystatinc incytokine inddimer inddimerstar infibrinogen inflmed inghrelin inicam inil6 inil6snp inleptin inmaster
                      inmicroalb inoxldl inpai1 inpanela insolil6 intnfa invermontdna invisfatin lab_datercvd microalb_date ddimerstaram_rundate ddimer_transmit ddimer_datercvd
                      cystatinc_date zipcode state city cellphon midinit cdlabel f2r barcode whenwhe medicno diffaddr scorerid techid scoredt visityr oldindexf oldrelative monhbid
                      monpibid keyfield pptid personi;


data rectype5_pass1;
  length nsrrid 8.;
  merge obf.obfid rectype5_narrowedvars(drop=motherid fatherid in=a);
  by personi;

  attrib _all_ label = "";
  format _all_;

  if a;
  if rcurve1 = -1 then rcurve1 = .;
  if rcurve2 = -1 then rcurve2 = .;
  if rcurve3 = -1 then rcurve3 = .;
  if rcurve4 = -1 then rcurve4 = .;

  drop &pass1_droplist;

run;

data alldata_withobfids;
  set rectype5_pass1;
run;

data indexdates_byid;
  set obf.indexdates_byid;
  keep nsrrid index_date;
run;

proc sort data = alldata_withobfids;
  by nsrrid;
run;

data alldata_withindexdates;
  retain nsrrid familyi motherid fatherid rectype index_date;
  merge alldata_withobfids (in = a) indexdates_byid;
  by nsrrid;
  if a;
run;

/*
proc sql;
  select *
  from alldata_withindexdates
  where index_date = .;
quit;
*/

%let date_variable_list = visitdat date visitaa visitecg visitbr visitld visitnfs stdatep q10q3 q11q2 q11q8;
%let year_variable_list = yrdiagn ADDDIAYR APNDIAYR DIANARYR DIASNOYR DIAEXSYR DIALEGYR DIACHLYR DIASIDYR DIANMYR DIABPYR DIAHRTYR DIADIAYR DIAIRRYR ANGDIAYR BYPDIAYR ANGIOYR
                            HTFDIAYR PACDIAYR HEAAGEYR STRODIYR ENDARTYR TIADIAYR PARTDIYR OSTDIAYR GULDIAYR PARDIAYR CRODIAYR  KIDNDIYR LIVDIAYR KFDIAGYR MDYSDIYR
                            TOUDIAYR SICDIAYR ANEDIAYR CIRDIAYR HEPDIAYR ASTDIAYR BRODIAYR EMPDIAYR PNEDIAYR SINDIAYR HAYDIAYR DEVDIAYR ADEDIAYR TONDIAYR INSDIAYR
                            ANXDIAYR ADDDIAYR BEHDIAYR GOUDIAYR MSCDIAYR RHEDIAYR THYDIAYR DEPDIAYR ECZDIAYR PSYDIAYR CANDIAYR SURDIAYR OSMDIAYR;

data alldata_withindexdates_obf;
  set alldata_withindexdates;

  array date_variables[*] &date_variable_list;
  array year_variables[*] &year_variable_list;

  do i = 1 to dim(date_variables);
    if date_variables[i] le 0 then date_variables[i] = .;
    date_variables[i] = date_variables[i] - index_date;
  end;

  do i = 1 to dim(year_variables);
    if year_variables[i] le 0 then year_variables[i] = .;
    year_variables[i] = year_variables[i] - year(index_date);
  end;

  drop i;

  format &date_variable_list &year_variable_list best12.;
run;

*need to check that this next step works anytime input dataset is changed;
data alldata_withindexdates_obf2 (drop = store_year_whenpsg);
  set alldata_withindexdates_obf;
  if whenpsg in ('-1', '-2', '-9') then whenpsg = '';

  if find(whenpsg,'-') = 0 and find(whenpsg,'/') = 0 then store_year_whenpsg = input(compress(whenpsg,,"kd"),12.);
  if store_year_whenpsg > 2010 or store_year_whenpsg < 1900 then store_year_whenpsg = .;

  if store_year_whenpsg ne . then whenpsg_yearsfromindex = store_year_whenpsg - year(index_date);
  else if find(lowcase(compress(whenpsg,' ')), 'yearago') > 0 or find(lowcase(compress(whenpsg,' ')), 'yearsago') > 0 then do;
    if find(whenpsg,'-') = 0 then do;
      whenpsg_yearsfromindex = 0 - input(compress(whenpsg,,"kd"),12.);
    end;
  end;

run;

data alldata_withindexdates_obf2;
  set alldata_withindexdates_obf2 (drop = whenpsg);
  rename whenpsg_yearsfromindex = whenpsg;
run;

*Check that there are no dates remaining in the dataset;
%let nodates_dataset = alldata_withindexdates_obf2;

proc contents data = &nodates_dataset out = nodates_dataset_contents noprint;
run;

proc sql noprint;
  select quote(strip(NAME)) into :current_contents_list separated by ', '
  from nodates_dataset_contents;

  select NAME into :check_for_phi_dates separated by ' '
  from Combined_rectypes_contents
  where NAME in (&current_contents_list)
        and (find(NAME, 'date', "i") > 0 or find(LABEL, 'date', "i") > 0);

  select NAME into :check_for_phi_years separated by ' '
  from combined_rectypes_contents
  where NAME in (&current_contents_list)
        and (find(NAME,'year',"i") > 0 or find (LABEL, 'year', "i") > 0);

quit;

*Check instances where year value > 1900
*Check instances where date value > 7300 [which would represent 20 years after index_date if variable was really "days from index" and not a date value];
proc univariate data = &nodates_dataset noprint outtable = dates_univ;
  var &check_for_phi_dates &check_for_phi_years;
run;

%let phivars_droplist = NAMDOC TXOTHER MOMSPECC DADSPECC BROCAUS1 BROCAUS2 BROCAUS3 SISCAUS1 SISCAUS2 SISCAUS3 SIBCANSP SONCAUS1 SONCAUS2 SONCAUS3
                          DAUCAUS1 DAUCAUS2 DAUCAUS3 KIDCANSP DOCSAY MAJSURSP OSMCSP
                        dna_bestsampleid
;

%let whyinclude_droplist = ANKARMTK BRTECH OPERATOR rpt;

data alldata_obf_penult;
  set alldata_withindexdates_obf2;
  drop &phivars_droplist &whyinclude_droplist;
run;

proc contents data = alldata_obf_penult out = alldata_obf_penult_cont noprint;
run;

proc sql noprint;
  select %unquote(NAME) into :char_variable_list separated by ', '
  from alldata_obf_penult_cont
  where type = 2;

  create table check_char_vars as
  select &char_variable_list
  from alldata_obf_penult;
quit;

%put &char_variable_list;

/*
proc contents data = check_char_vars;
run;

proc freq data = check_char_vars;
run;
*/

%let additional_droplist = CAUSDIE1 CAUSDIE2 CAUSDIE3 HOSREAS RECOCC WHATILL;

data alldata_obf_all /*nsrrdata.rectype5_pass1_obfphi*/;
  set alldata_obf_penult;
  drop &additional_droplist;
run;

proc import datafile = "\\rfawin\bwh-sleepepi-cfs\nsrr-prep\cfs_systematic_cleaning_variables.csv" dbms = csv out = systematic_cleaning replace;
guessingrows = 500;
run;

proc sql noprint;
  select variable_name into :null_negative_list separated by " "
  from systematic_cleaning
  where lowcase(cleaning_step) = "null negatives";

  select variable_name into :null_negative_chars separated by " "
  from systematic_cleaning
  where lowcase(cleaning_step) = "null negatives (char)";

  select variable_name into :outlier_implausible_list separated by " "
  from systematic_cleaning
  where lowcase(cleaning_step) = "outliers or implausible" and fixed_or_checked ne 1;
quit;

%put &null_negative_list;
%put &null_negative_chars;

*for "choices" variables, "-2" sometimes = "Don't Know", but -1 is missing so set to NULL;
%let negative1_null_list = nodrinks actplay dochest farouse fdesire feelnap forgasm minslpco monsnor offroad read reasrem samesnor slpcrash slptco soonches stilches timesnor totawco typetx uphchest wakmanco wellslp wkschool
      alcpres allbeec antihist_sd apacold apnctr apnobst armexer astpl3dy astsp3dy bedalcl bicexer bpmed3dy bronchio calit600 centralv centsent centsilv centvits cenvitpl
      chrphle coldair combipat cpap curpreg cvsdaily cvsmegml cvsminer cvsprovi daynite dendev difbak distsnor docpain drvrslp dustfume estrace estrate femhrt fornu100 h2opl3dy
      hdforwpl healtpac hormones hosphrt hrtpl3dy jogexer kidadd kidasthm kidbp kidbypas kidcancr kidchf kiddepre kiddiabe kidemphy kidlegs kidmd kidmi kidnarc kidnms kidosa kidsickl
      kidsids kidsigmd kidslp kidsnor kidstrok kidtoure labothmd lanti lanymed lazertx lbron ldecon legexer levchest lowexer lseds lsplpil lstim mensnow microniz moncigs mondist monpipe monsmoke
      n1ovrem n2ovrem nasaldil nasdc3dy natsurno natural noobser nosesur nuskinpk obslp ocuvite ocuvitpl ogen oneadaye oneadaym oneadayw onedayap onlynite othermed othestro othexer othhpill
      othprog pastmon patchest perstart perstop phl3 pollens posttx premarin premphas premprob premprop procycmp prog3dy protegra radchemo regbas rotnite runexer samhse sedative shaklee sharbed
      shbrmon sibadd sibasthm sibbp sibbypas sibcancr sibchf sibdepre sibdiabe sibemphy siblegs sibmd sibmi sibnarc sibnms sibosa sibsickl sibsids sibsigmd sibslp sibsnor sibstrok
      sibtoure simple skintst slppl3dy solotron somnoply stdynite stim3dy stimulan stresstb surbext surgery swimexer tenexer theragmm theragrm thyrm3dy tondiag tonpres tranq3dy unicap unicapm unicapsr
      uppp utergone vagestro vaginal vimin75 whecold wheexer wompowpk workslp youvitir vigexer zbec foldosdy longicu longo2 ovaries tkphnno workacc nonaps
      alcohol caffeine lastmens CAR LONGNAPS LSTMENS AGESMOK YRSDVR NOMULVIT AM7CIG AM930CIG
;

data alldata_obf_all_systclean;
  set alldata_obf_all;

  array null_negatives[*] &null_negative_list;
  do i = 1 to dim(null_negatives);
    if null_negatives[i] < 0 then null_negatives[i] = .;
  end;
  drop i;

  array null_negatives_charray[*] &null_negative_chars;
  do i = 1 to dim(null_negatives_charray);
    if null_negatives_charray[i] in ("-1", "-2", "-8", "-9","-333", "-999","-1010") then null_negatives_charray[i] = "";
  end;
  drop i;

  array null_negative1_array[*] &negative1_null_list;
  do i = 1 to dim(null_negative1_array);
    if null_negative1_array[i] = -1 then null_negative1_array[i] = .;
  end;
  drop i;
run;
/*
data alldata_obf_all_systclean2;
  retain nsrrid &outlier_implausible_list;
  set alldata_obf_all_systclean;
run;

proc sort data = alldata_obf_all_systclean2 out=aa_alldata_obf_all_systclean2;
by lowsaoslp;
run;

proc sql;
select nsrrid,
      hypbpsys,
      sbp
from aa_alldata_obf_all_systclean2
where 0 le hypbpsys < 80 or hypbpsys > 200;
quit;
*/

%let saturation_variable_list = mxdnba mxdnba2 mxdnba2 mxdnba3 mxdnba4 mxdnba5 mxdnbp mxdnoa mxdnoa2 mxdnoa3 mxdnoa4 mxdnoa5 mxdnop mxdrba mxdrba2 mxdrba3 mxdrba4 mxdrba5 mxdrbp mxdroa mxdroa2 mxdroa3 mxdroa4 mxdroa5
                                mndnoa5 mndnoa4 mndnoa3 mndnoa2 mndnoa mxdrop avdnop avdnoa5 avdnoa4 avdnoa3 avdnoa2 avdnoa avgsaominnr
;

data alldata_obf_all_moreclean;
  set alldata_obf_all_systclean;

  *Recode variables that were missed in original data entry;
  if q10q5a = 0 then q10q5a = 2;
  if q11q3a = 3 then q11q3a = 1;
  if q11q3d = 4 then q11q3d = 1;
  if mosq4d > 6 then mosq4d = .;
  if mosq9b > 6 then mosq9b = .;
  if mosq9c > 6 then mosq9c = .;
  if mosq9f > 6 then mosq9f = .;
  if dochest = 0 then dochest = 2;
  if devsept = 2 then devsept = 0;
  if hsincome = -9 then hsincome = .;
  if livearra = -9 then livearra = .;
  if nutonsil = -9 then nutonsil = .;
  if slphear = -9 then slphear = .;
  if slpqst = -9 then slpqst = .;
  if soonches = 0 then soonches = 2;
  if wakmanco = -9 then wakmanco = .;
  if whereqst = -9 then whereqst = .;
  if uphchest = 2 then uphchest = 0;
  if position = -2 then position = 5;
  /* 4 Instances of '0' nulled out until meaning can be determined*/
  if marstat = 0 then marstat = .;

  *Hard-code spirometry values that were found to be entered incorrectly;
  if nsrrid = 801780 then pef = 6.52;
  if nsrrid = 801780 then pefppk = 106.5;
  if nsrrid = 801732 then babyaday = .;
  if nsrrid = 802201 then babyaday = .;
  if nsrrid = 801222 then babyaday = .;

  *NULL cases where "maximum inflation" is less than observed value;
  if ankarmil < ankardsp then ankarmil = .;

  *NULL implausible bp values;
  if hypbpsys < 20 then hypbpsys = .;
  if mxhrahslp > 500 then mxhrahslp = .;

  *NULL implausible lowo2 values;
  *if lowsaoslp = 0 then lowsaoslp = .;
  *if lowsaonr < 10 then lowsaonr = .;
  *consider nulling cases where lowsaonr < lowsaoslp;

  *NULL desaturation values > 100;
  array desat_vars[*] &saturation_variable_list;
  do i = 1 to dim(desat_vars);
    if desat_vars[i] > 100 then desat_vars[i] = .;
  end;
  drop i;

  *NULL implausible age values;
  if dadage > 200 then dadage = .;

  *recalculate end_dur_hr and end_dur_mn (must have been some flaw in original formula);
  endslp_timevalue = hms(floor(endslp/100),mod(endslp,100),0);
  endwake_timevalue = hms(floor(endwake/100),mod(endwake,100),0);

  if endwake_timevalue = 0 and endslp_timevalue ge (11*60*60) then end_dur_mn = ((endwake_timevalue+(24*60*60)) - endslp_timevalue)/60;
  else if endslp_timevalue ge (12*60*60) and endwake_timevalue le (12*60*60) then end_dur_mn = ((endwake_timevalue+(24*60*60)) - endslp_timevalue)/60;
  else end_dur_mn = (endwake_timevalue - endslp_timevalue)/60;

  if end_dur_mn < 0 then end_dur_mn = .;
  end_dur_hr = end_dur_mn/60;
  drop endslp_timevalue endwake_timevalue;

run;

%let manual_json_droplist = aadone aatech adddiayr adediayr am10tech am7tech anediayr angdiayr angioyr anxdiayr apndiayr astdiayr behdiayr biadone biatech bracdone bractech brodiayr
                            bypdiayr candiayr cdssdone chqdone cirdiayr consdone cptdone cpttech crodiayr depdiayr devdiayr diabpyr diachlyr diadiayr diaexsyr diahrtyr diairryr
                            dialegyr dianaryr dianmyr diasidyr diasnoyr disbdone disclose drmrdone ecgdone eczdiayr empdiayr endartyr essdone fosqdone freezdna fsdone futurdna
                            goudiayr guldiayr h2opilyr haydiayr heaageyr hepdiayr hippa htfdiayr inno insdiayr kfdiagyr kidndiyr livdiayr mdysdiyr mosdone mrmrdone mscdiayr naadone
                            nodone notech nsrhind nsrhtech ogttdone osmdiayr ostdiayr pacdiayr pardiayr partdiyr phardone phartech pheldone physdone pm10tech pndone pnediayr postdone
                            preddone psydiayr rhediayr rhindone rhintech shqdone sicdiayr sindiayr skindone skintech snakdone spirdone spirtech ssedone strodiyr surdiayr svdone
                            thydiayr tiadiayr tondiayr toudiayr vigldone vigltech visitnfs yrdiagn index_date q10q4 psgid headtech ln_crppm ln_crpam agedianm
                            /* Variable dropped until more information can be found based on domain options */indexf monitor
                            ;

*** NOTE: In future iterations of CFS, where additional visits are included besides RECTYPE5, the following variables should be rechecked for meaningful data ***;
%let other_reason_droplist = /*Always equal to -1*/ lcafbv3q lcafbv3t lcafbv2q lcafbv2t pacemage
                            /*Always equal to 0*/ avgdbslp maxdbslp nobrslp nodb4slp nodb5slp nordb2 nordb3 nordb4 nordb5 nordball notca notcc notch notco pdb5slp plmardelta plmarrem
                              plmarstg1 plmcardelta prdb5slp nobrap nobrc
                            /*No observed values - likely all were negative and scrubbed in a previous step*/ agediasi
                            /* Unsure what numeric codes translate too - variables useless without translation*/ house houshold
                            /* duplicated by `wtkg` */ whtkg
                            ;

*** Because of excessive missingness and multiple problematic variables, Family Medical History variables are being dropped (release candidate 2) for further exploration;
%let family_medical_history_vars = addsbage adsibage baddno basthmno bbpno bbypasno bcancrno bchfno bdepreno bdiabeno bemphyno blegsno bmdno bmino bnarcno bnmsno bosano bothmdno breacanc
                                    broage broaged1 broaged2 broaged3 brolive brosis bsicklno bsidsno bslpno bsnorno bstrokno btoureno colocanc dadadd dadage dadasthm dadbipas dadbp dadcancr
                                    dadcaus dadchf daddepre daddiabe daddied dadlegs dadlive dadmd dadmi dadnarc dadosa dadothsi dadsickl dadslp dadsnor dadstrok dadtoure dageadd dageasth
                                    dagebp dagebypa dagecanc dagechf dagedepr dagediab dageleg dagemd dagemi dagenarc dageosa dageoths dagesick dageslp dagesnor dagestro dagetour dauadd
                                    dauage dauaged1 dauaged2 dauaged3 dauasthm daubp daubypas daucancr dauchf daudepre daudiabe dauemphy daulegs daulive daumd daumi daunarc daunms dauosa
                                    dauothmd dausickl dausids dauslp dausnor daustrok dautoure dbreaage kidadd kidasthm kidbp kidbypas kidcancr kidchf kiddepre kiddiabe kidemphy kidlegs kidmd
                                    kidmi kidnarc kidnms kidosa kids kidsickl kidsids kidsigmd kidslp kidsnor kidstrok kidtoure mageadd mageasth magebp magebypa magecanc magechf magedepr
                                    magediab mageleg magemd magemi magenarc mageosa mageoths magesick mageslp magesnor magestro magetour mbreaage momadd momage momasthm mombp mombypas
                                    momcancr momcaus momchf momdepre momdiabe momdied momlegs momlive mommd mommi momnarc momosa momothsi momsickl momslp momsmoke momsnor momstrok momtoure
                                    movarage nobro nodaugh nosis nosons omeloage ovarcanc panccanr pcoloage pglauage pmeloage ppancage saddno sasthmno sbpno sbreaage sbypasno scancrno schfno
                                    sdepreno sdiabeno semphyno sglauage sibadd sibasthm sibbp sibbypas sibcancr sibchf sibcolag sibdepre sibdiabe sibemphy siblegs sibmd sibmi sibnarc sibnms
                                    sibosa sibsickl sibsids sibsigmd sibslp sibsnor sibstrok sibtoure sisage sisaged1 sisaged2 sisaged3 sislive slegsno smdno smeloage smino snarcno snmsno
                                    sonadd sonage sonaged1 sonaged2 sonaged3 sonasthm sonbp sonbypas soncancr sonchf sondepre sondiabe sonemphy sonlegs sonlive sonmd sonmi sonnarc sonnms sonosa
                                    sonothmd sonsickl sonsids sonslp sonsnor sonstrok sontoure sosano sothmdno soverage spancage ssicklno ssidsno sslpno ssnorno sstrokno stoureno;

* macro to create time variables from 24-hour times collected as integers;
%macro fixtimes(varin,varout);
        if &varin >=0 then do;
                 &varin.c = trim(left(put(&varin, 8. )));
                 &varout = input(substr(trim(left(reverse(substr(trim(left(reverse(&varin.c)!! '0000' )), 1 , 4 )))), 1 , 2 )
                                   !! ':' !! substr(trim(left(reverse(substr(trim(left(reverse(&varin.c)!! '0000' )), 1 , 4 )))), 3 , 2 ), time5. );
        end;
        format &varout time5. ;
        drop &varin.c;
%mend ;

*drop variables that were excluded from the json data dictionary because of redundancy or a lack of relevance/importance;
data alldata_obfclean_all_final;
  set alldata_obf_all_moreclean;

  *create age category variables;
  if age < 1 then age_category = 0;
  else if 1 =< age =< 4 then age_category = 1;
  else if 5 =< age =< 14 then age_category = 2;
  else if 15 =< age =< 24 then age_category = 3;
  else if 25 =< age =< 34 then age_category = 4;
  else if 35 =< age =< 44 then age_category = 5;
  else if 45 =< age =< 54 then age_category = 6;
  else if 55 =< age =< 64 then age_category = 7;
  else if 65 =< age =< 74 then age_category = 8;
  else if 75 =< age =< 84 then age_category = 9;
  else if 85 =< age then age_category = 10;

  if race > 2 then race = 3;

  *create new AHI variables for ICSD3;
  ahi_a0h3 = 60 * (hrembp3 + hrop3 + hnrbp3 + hnrop3 + carbp + carop + canbp + canop + oarbp + oarop + oanbp + oanop ) / slpprdp;
  ahi_a0h4 = 60 * (hrembp4 + hrop4 + hnrbp4 + hnrop4 + carbp + carop + canbp + canop + oarbp + oarop + oanbp + oanop ) / slpprdp;
  ahi_a0h3a = 60 * (hremba3 + hroa3 + hnrba3 + hnroa3 + carba + caroa + canba + canoa + oarba + oaroa + oanba + oanoa ) / slpprdp;
  ahi_a0h4a = 60 * (hremba4 + hroa4 + hnrba4 + hnroa4 + carba + caroa + canba + canoa + oarba + oaroa + oanba + oanoa ) / slpprdp;

  ahi_o0h3 = 60 * (hrembp3 + hrop3 + hnrbp3 + hnrop3 + oarbp + oarop + oanbp + oanop ) / slpprdp;
  ahi_o0h4 = 60 * (hrembp4 + hrop4 + hnrbp4 + hnrop4 + oarbp + oarop + oanbp + oanop ) / slpprdp;
  ahi_o0h3a = 60 * (hremba3 + hroa3 + hnrba3 + hnroa3 + oarba + oaroa + oanba + oanoa ) / slpprdp;
  ahi_o0h4a = 60 * (hremba4 + hroa4 + hnrba4 + hnroa4 + oarba + oaroa + oanba + oanoa ) / slpprdp;

  ahi_c0h3 = 60 * (hrembp3 + hrop3 + hnrbp3 + hnrop3 + carbp + carop + canbp + canop ) / slpprdp;
  ahi_c0h4 = 60 * (hrembp4 + hrop4 + hnrbp4 + hnrop4 + carbp + carop + canbp + canop ) / slpprdp;
  ahi_c0h3a = 60 * (hremba3 + hroa3 + hnrba3 + hnroa3 + carba + caroa + canba + canoa ) / slpprdp;
  ahi_c0h4a = 60 * (hremba4 + hroa4 + hnrba4 + hnroa4 + carba + caroa + canba + canoa ) / slpprdp;

  cent_obs_ratio = (carbp + carop + canbp + canop) / (oarbp + oarop + oanbp + oanop);
  cent_obs_ratioa = (carba + caroa + canba + canoa) / (oarba + oaroa + oanba + oanoa);

  *recode self-reported sleep duration variables across weekdays and weekends;
  * FIX SELF-REPORTED BED AND WAKE TIMES (WEEKDAYS);
  %fixtimes(DAYSLP ,DAYSLP_time);
  %fixtimes(DAYWAKE ,DAYWAKE_time);

  * if slptime before midnight and waketime after midnight set date as previous day;
  if hour(DAYSLP_time) > 12 and hour(DAYWAKE_time) <=12 then DAYSLP_time2 = dhms(date()- 1 ,hour(DAYSLP_time),minute(DAYSLP_time), 0 );
  * if both slptime  and waketime before midnight then use current day;
  else if hour(DAYSLP_time) > 12 and hour(DAYWAKE_time) >12 then DAYSLP_time2 = dhms(date() ,hour(DAYSLP_time),minute(DAYSLP_time), 0 );
  * otherwise use current day;
  else DAYSLP_time2 = dhms(date(),hour(DAYSLP_time),minute(DAYSLP_time), 0 );

  * if   waketime at midnight then waketime use next day;
  if  hour(DAYWAKE_time) =0 then DAYSLP_time2 = dhms(date()+1 ,hour(DAYSLP_time),minute(DAYSLP_time), 0 );
  * otherwise use current day for waketime;
  else DAYWAKE_time2 = dhms(date(),hour(DAYWAKE_time),minute(DAYWAKE_time), 0 );

  * calculate midpoint of bed and wake times;
  DAYMID_time2 = DAYSLP_time2 + (DAYWAKE_time2 - DAYSLP_time2)/2;
  DAYMID_time = timepart(DAYMID_time2);

  format daymid_time time5. DAYSLP_time2 DAYWAKE_time2 DAYMID_time2 datetime16.;

  * calculate time in bed as difference between wake and bed time (accounting for change in midnight);
  DAYSLP_dur_mn  = (DAYWAKE_time2 - DAYSLP_time2)/ 60;
  DAYSLP_dur_hr  = (DAYWAKE_time2 - DAYSLP_time2)/ 3600;
  label    DAYSLP_dur_mn  ='calculated sleep duration (minutes) during weekday-by DAYWAKE -DAYSLP '
          DAYSLP_dur_hr  ='calculated sleep duration (hours) during weekday -by DAYWAKE -DAYSLP ';

  drop daywake_time2 dayslp_time2 daymid_time2;

  * FIX SELF-REPORTED BED AND WAKE TIMES (WEEKENDS);
  %fixtimes(ENDSLP ,ENDSLP_time);
  %fixtimes(ENDWAKE ,ENDWAKE_time);

  * if slptime before midnight and waketime after midnight, set date as previous day;
  if hour(ENDSLP_time) > 12 and hour(ENDWAKE_time) <=12 then ENDSLP_time2 = dhms(date()- 1 ,hour(ENDSLP_time),minute(ENDSLP_time), 0 );
  * if both slptime  and waketime before midnight then use current day;
  else if hour(ENDSLP_time) > 12 and hour(ENDWAKE_time) >12 then ENDSLP_time2 = dhms(date() ,hour(ENDSLP_time),minute(ENDSLP_time), 0 );
  * otherwise use current day;
  else ENDSLP_time2 = dhms(date(),hour(ENDSLP_time),minute(ENDSLP_time), 0 );

  * if waketime at midnight then waketime use next day;
  if  hour(ENDWAKE_time) =0 then ENDWAKE_time2 = dhms(date()+1,hour(ENDWAKE_time),minute(ENDWAKE_time), 0 );
  * otherwise use current day for  wake time;
  else ENDWAKE_time2 = dhms(date(),hour(ENDWAKE_time),minute(ENDWAKE_time), 0 );

  * calculate midpoint of bed and wake times;
  ENDMID_time2 = ENDSLP_time2 + (ENDWAKE_time2 - ENDSLP_time2)/2;
  ENDMID_time = timepart(ENDMID_time2);

  format ENDmid_time time5. ENDSLP_time2 ENDWAKE_time2 ENDMID_time2 datetime16.;

  * calculate time in bed as difference between wake and bed time (accounting for change in midnight);
  ENDSLP_dur_mn  = (ENDWAKE_time2 - ENDSLP_time2)/ 60;
  ENDSLP_dur_hr  = (ENDWAKE_time2 - ENDSLP_time2)/ 3600;
  label    ENDSLP_dur_mn  ='calculated sleep duration (minutes) during weekend -by ENDWAKE  - ENDSLP '
          ENDSLP_dur_hr  ='calculated sleep duration (hours) during weekend-by ENDWAKE  - ENDSLP ';

  drop endwake_time2 endslp_time2 endmid_time2 END_dur_mn END_dur_hr;

  *make manual adjustments to any self-reported sleep duration values that turn out implausible;

  *DAYSLP = DAYWAKE, use DAYBED in calculation instead;
  if nsrrid = 800557 then do;
    DAYSLP_dur_hr = 2;
    DAYSLP_dur_mn = 120;
  end;

  *DAYSLP = DAYWAKE, use DAYBED in calculation instead;
  if nsrrid = 801080 then do;
    DAYSLP_dur_hr = 2;
    DAYSLP_dur_mn = 120;
  end;

  *ENDSLP = ENDWAKE, use ENDBED in calculation instead;
  if nsrrid = 800557 then do;
    ENDSLP_dur_hr = 4;
    ENDSLP_dur_mn = 240;
  end;

  *if missing DAYSLP, set duration variables to missing;
  if dayslp = . then do;
    dayslp_dur_hr = .;
    dayslp_dur_mn = .;
  end;

  *if missing ENDSLP, set ENDSLP duration variables to missing;
  if endslp = . then do;
    ENDSLP_dur_hr = .;
    ENDSLP_dur_mn = .;
  end;

  *remove impossible value on SF36 item;
  if mosq4a = 3 then mosq4a = .;

  drop &manual_json_droplist &other_reason_droplist &family_medical_history_vars obf_pptid;
run;

*export final dataset;
proc export data=alldata_obfclean_all_final
  outfile="\\rfawin\bwh-sleepepi-cfs\nsrr-prep\_releases\&release\cfs-visit5-dataset-&release..csv"
  dbms=csv
  replace;
run;
