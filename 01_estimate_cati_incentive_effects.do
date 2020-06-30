********************************************************************************
** 	TITLE: 01_estimate_cati_incentive_effects.do
**
**	PURPOSE: Download and estimate average incentive effects from reviewed
**			literature in IPA's literature review. 
**				
**	NOTES:
**
**	AUTHOR: Michael Rosenbaum
**
**	CREATED: May 15, 2020
**
**	EDITED:		
********************************************************************************
*Table of Contents:
*1. Download and clean raw files
*2. Create dataset
*3. Analysis and coefficient export


clear all
cap log close

version 14.2
set more off
pause on


***************************************
* 1. Download and clean raw file
***************************************
*1. Set directories
*2. Download files
*3. Select data

**1. Set directories and locals
	*Local directory
	loc cdloc = subinstr("`c(pwd)'", "\", "/" ,.) // current location for the do file with Stata formatted slashes

	*Gsheet URL with sheet name
	/*
		This is the response rate tab of IPA's evidence review on 
		remote survey modes. I will also add some response rate information
		that was not included due to lack of precision in reported response rates
	*/
	loc url 	"https://docs.google.com/spreadsheets/d/1lPLW9hsMur0bIqFy7QcoFMKU5CHnhcVDke0EmwYDp7w/export?gid=304366966&format=csv"
	loc location `cdloc'


**2. Download data
	*Check if location exists
	cap mkdir 			"`location'/data/"
	cap mkdir 			"`location'/output/"
	copy "`url'" 		"`location'/data/response_rates.csv", replace


**3. Load data and cleaning
	import delim using 	"`location'/data/response_rates.csv", varn(1) stripq(yes) clear

	/*
		Comma and carriage returns in rows from CSV require some manual renaming

	*/
	drop in 1/7 // drop failed delineation

	*renames
	ren v1 					id
	ren v3 					author
	ren v5 					research_year
	ren v6 					country
	ren v7 					mode
	ren v8 					sample 
	ren v12 				treatment
	ren v13 				wave
	ren dispositioncodes 	attempt
	ren v17 				connected
	ren v18 				complete
	ren v19 				partial
	ren v20 				refusal
	ren v21 				breakoff
	ren v22 				noncontact
	ren v23 				nonconnect

	*Remove any missingness
	missings dropobs, force
	missings dropvars, force


**3. Select data
	*Select only first wave
	keep if wave == "Wave 1" | wave == ""

	*Only select studies with incentives
	tab treatment,m
	sort id
	keep if inlist(treatment, "Control" "\$1 incentive", "\$5 incentive", 		///
		"100 Taka incentive", "10000 UGX incentive", "50 Taka incentive", 		///
		"Transfer incentive","5000 UGX incentive")								// Do not include raffle, due to no way to calculate ex ante incentive size
	drop if inlist(id, "48", "49") // drop non-incentive control obs
	destring *, replace // destring all numeric variables


	*Add studies
	set obs `=_N + 8'

	/* Add Leo & Morello, 2016, which do not report response rates as numbers,
		instead, they report everything as a percentage out of attempts. 

		We can impute Ns, within +/-1 of the actual N due to the level of 
		precision reported in their summary statistics 
	*/
	* Add obervations that don't report outcome Ns
	replace id 				= 27 						in `=_N-7'/`=_N'
	replace author 			= "(Leo & Morello, 2016)" 	in `=_N-7'/`=_N'
	replace mode 			= "CATI" 					in `=_N-7'/`=_N'
	replace sample 			= "MNO" 					in `=_N-7'/`=_N'
	replace attempt 		= 2000/4 					in `=_N-7'/`=_N'
	replace research_year 	= 2014						in `=_N-7'/`=_N'
	replace country 		= "Tanzania" 				in `=_N-7'/`=_N-4'
	replace country 		= "Ghana" 					in `=_N-3'/`=_N'
	
	*Add treatment statuses
	replace treatment 		= "0" 						in `=_N' 
	replace treatment  		= "0.25"                    in `=_N-1' 
	replace treatment 		= "0.50"					in `=_N-2' 
	replace treatment 		= "1.00"					in `=_N-3' 
	replace treatment 		= "0" 						in `=_N-4'
	replace treatment  		= "0.25"                    in `=_N-5'
	replace treatment 		= "0.50"					in `=_N-6'
	replace treatment 		= "1.00"					in `=_N-7'

	*Add outcomes by hand
	replace complete 		= round(500 * .531)			in `=_N'
	replace complete 		= round(500 * .599)			in `=_N-1'
	replace complete 		= round(500 * .617)			in `=_N-2'
	replace complete 		= round(500 * .591)			in `=_N-3'
	replace complete 		= round(500 * .619)			in `=_N-4'
	replace complete 		= round(500 * .718)			in `=_N-6'
	replace complete 		= round(500 * .658)			in `=_N-5'
	replace complete 		= round(500 * .691)			in `=_N-7'


**B. Data cleaning for analysis
	*Format author
	replace author 			= "(Leo et. al., 2015)" 				if id == 11
	replace author 			= "(Gibson et. al., 2019)" 				if id == 26
	replace author 			= "(Ballivan, Azevedo & Durbin, 2015)" 	if id == 61

	*Replace incentives to monetary values
	replace treatment 		= "0"		if treatment == "Control" | treatment == ""
	replace treatment 		= "0.6"		if treatment == "100 Taka incentive"
	replace treatment 		= "1.2"		if treatment == "50 Taka incentive"
	replace treatment 		= "1.35"	if treatment == "5000 UGX incentive"
	replace treatment 		= "2.70" 	if treatment == "10000 UGX incentive"
	replace treatment 		= "1"		if treatment == "\$1 incentive"
	replace treatment 		= "5"		if treatment == "\$5 incentive"
	replace treatment 		= "0.44"	if treatment == "Transfer incentive" & country == "Afghanistan"
	replace treatment 		= "1.23"	if treatment == "Transfer incentive" & country == "Ethiopia"
	replace treatment 		= "0.62"	if treatment == "Transfer incentive" & country == "Mozambique"
	replace treatment 		= "0.60"	if treatment == "Transfer incentive" & country == "Zimbabwe"
	destring treatment, replace

	*Remove non-connected numbers
	replace attempt = connected if !mi(connected)

	*Manually modify to eligible numbers from 26 that doesn't use AAPOR dispositions
	replace attempt = 1732 if treatment == 0 	& country == "Uganda" 		& id == 26
	replace attempt = 1428 if treatment == 1.35 & country == "Uganda" 		& id == 26
	replace attempt = 1453 if treatment == 2.70 & country == "Uganda" 		& id == 26
	replace attempt = 4346 if treatment == 0 	& country == "Bangladesh" 	& id == 26
	replace attempt = 2982 if treatment == 0.6 	& country == "Bangladesh" 	& id == 26
	replace attempt = 3019 if treatment == 1.2 	& country == "Bangladesh" 	& id == 26


**C. Compute Inflation adjustment of USD
	// No PPP adjustment because not in LCUs. Instead inflation adjust per Steve call 6/16
	loc adj_2012	1.12
	loc adj_2013 	1.11
	loc adj_2014	1.09
	loc adj_2015 	1.08
	loc adj_2016 	1.07
	loc adj_2017 	1.05
	loc adj_2018 	1.03
	loc adj_2019    1.01

	forval year = 2012(1)2019 {
		replace treatment = treatment * `adj_`year'' if research_year == `year'
	}


***************************************
* 2. Create dataset
***************************************
*1. Create data from incentive estimates
*2. PPI Adjusted USD


**1. Create data from incentive estimates
	*Create total
	loc study_n 				= `=_N'

	*Save list of information
	gsort +id country -treatment 
	forval i = 1(1)`study_n' {

		*Save values as locals 
		loc auth_`i' 			= author  		in `i'
		loc obs_`i' 			= attempt 		in `i' 							// Attempt
		loc loc_`i' 			= country 		in `i'
		loc com_`i' 			= complete 		in `i' 							// Completion
		loc trt_`i' 			= treatment 	in `i' 							// Incentive amount
		loc mode_`i' 			= mode 			in `i' 							// Remote survey mode
		loc samp_`i' 			= sample 		in `i' 							// Sampling frame 
		loc ryr_`i' 			= research_year in `i' 							// Research year
		loc id_`i' 				= id 			in `i' 							// Study ID
		loc count_`i' 			= `i' 
	}
	// end forval i = 1(1)`study_n'

	*Create subdata sets
	forval i = 1(1)`study_n' {
		
		*Set up values
		drop _all
		set obs `obs_`i''

		*Create data
		gen complete 			= 0 
			replace complete 	= 1 			in 1/`com_`i''
		gen trt 				= `trt_`i''
		gen mode 				= "`mode_`i''"
		gen samp 				= "`samp_`i''"
		gen country 			= "`loc_`i''"
		gen id 					= `id_`i''

		*Save tempfile file
		tempfile study`i'
		save `study`i''

	}
	// end forval i = 1(1)`study_n'

	*Append data
	forval i = 1(1)`study_n' {

		**load 1st study data
		if `i' == 1 use `study`i'', clear
		
		*Otherwise add data
		else {
			append using `study`i''
		}
		// end else

	}
	// end forval i = 1(1)`study_n'



***************************************
* 3. Analysis and export coefficients
***************************************
*1. Calculate coefficient estimates
*2. Calculate pooled effect and estimates
*3. Save in coefficient plot


**1. Calculate coefficient estimates
	*Create matrix of IDs and Standard errors
	distinct id country trt, joint
	loc length = `r(ndistinct)' - 7
	loc matlen = `length' 														// 1 for each study, 1 gap, 3 margins ($0.50, $1.00, $2.00) 
	mat A = J(`matlen', 7, .)													// r = studies, c = beta, SE, n 

	*Prep treatment variable as factor
	gen trt_factor = string(trt)
	replace trt_factor = "0" + trt_factor if regexm(trt_factor, "^\.")
	label define trt ///
	    1   "0" 																///
		2	"0.2725" 															/// 
		3	"0.4796" 															/// 
		4	"0.545" 															/// 
		5	"0.63" 																/// 
		6	"0.6758" 															/// 
		7	"0.654" 															/// 
		8	"1.09" 																/// 
		9	"1.26" 																/// 
		10	"1.3407" 															/// 
		11	"1.4175" 															/// 
		12	"2.835" 															/// 
		13	"5.6" 																//
	sencode trt_factor, label(trt) replace
	tab trt_factor, m

	*Gen factor country
	sencode country, replace
	sencode mode, replace

	*Gen trt sq
	gen trt_sq = trt*trt
	levelsof id, loc(studies) 													// generate list of regressions
	loc i = 1 																	// start row counter
	foreach study of local studies {

		levelsof mode if id == `study', local(modes)
		foreach mode of local modes {

			levelsof country if id == `study', local(countries)
			foreach country of local countries {
		
				* LPM of treatment effect on completion rate
				di "Study = `study'; Country = `country'"
				reg complete i.trt_factor if id == `study' & country == `country' & mode == `mode', vce(r)

				*Collect treatments
				levelsof trt_factor if id == `study' & country == `country' & mode == `mode', loc(treatments) 
				loc j = 1 																// start treatment counter by study
				foreach treatment of local treatments{

					*Skip control
					if `j' == 1 {
						loc ++j
						continue
					}

					*Save treatment in USD
					qui su trt if trt_factor == `treatment' & country == `country' & mode == `mode' & id == `study'
					loc trt_val = `r(mean)'

					if `j' > 1 {
						
						if _b[`treatment'.trt_factor] < 0 {
							di "`e(cmdline)'"
						}

						mat A[`i', 1] = _b[`treatment'.trt_factor]
						mat A[`i', 2] = _se[`treatment'.trt_factor]
						mat A[`i', 3] = `r(N)'
						mat A[`i', 4] = `study'
						mat A[`i', 5] = `mode'
						mat A[`i', 6] = `country'
						mat A[`i', 7] = `trt_val'
						loc ++i 														// advance row counter
						loc ++j 														// advance treatment counter
					}
					// end if `j' > 1
				}
				// end foreach treatment of local treatments

			}
			// end foreach country of local countries

		}
		// end foreach mode of local modes

	}
	// end foreach study of local studies


**2. Calculate pooled effects and estimates
	*LPM of treatments with study and country FEs
	reg complete c.trt##c.trt i.id, vce(cluster id)
	
	*Save results
	loc i = 1
	mat B = J(141, 7, .)
	forval marginal = 0(0.05)7 {

		qui lincom `marginal'*trt + `marginal'*`marginal'*c.trt#c.trt
		mat B[`i', 1] = `r(estimate)' 													// beta
		mat B[`i', 2] = `r(se)'		 													// SE
		mat B[`i', 7] = `marginal'
		loc ++i
	}
	// end for each margin in 0.5 1 2.5	

	*Combine matricies
	mat C = A \ B

**3. Save output using twoway
	*Make mat
	drop _all
	svmat C
	ren (C1 C2 C3 C4 C5 C6 C7) (beta se n study mode country treatment)

	*Create locals for saving twoway output
	loc yscale = `=_N'
	loc xlab 																	// init empty
	loc i = 0 
	forval j = 1(1)`study_n' {

		* Skip control for labels
		if "`trt_`j''" == "0" continue

		loc place = `yscale' - `i'
		loc place = (`place' * 2) - 1 // add spacing for larger text

		*Format treatment price
		loc price = "`: di %9.2f `trt_`j'''"
		loc price = "\$" + subinstr("`price'", "     ", "", .)
		
		* Define  local labels
		loc xlab `"`xlab' `place' `""`auth_`j''"  "`mode_`j'' - `loc_`j'' - `price'""' "' /* " //sublime syntax highlighting fix */
		loc ++i
	}

	* Addded pooled outcomes
	loc place = `place' - 4
	loc xlab `"`xlab' `place' "Pooled effects - $0.50""' 
	loc place = `place' - 2
	loc xlab `"`xlab' `place' "Pooled effects - $1.00""'
	loc place = `place' - 2
	loc xlab `"`xlab' `place' "Pooled effects - $2.50""' 

	*Create IDs
	gen lo_2se = beta - 1.96 * se
	gen hi_2se = beta + 1.96 * se

	*Create pooled labels
	gen double mlabel = beta*100
		tostring mlabel, replace force format(%9.1f)
	replace mlabel = mlabel + "%"

	*Create dynamic transparency
	loc cmd_tw // init empty
	qui sum n
	loc max `r(max)'
	count if !mi(country)
	forval i = 1(1)`r(N)' {

		*Generate transparency scale
		qui sum n in `i'
		loc transparency = round(`r(mean)'/`max'*100,1)
		if `transparency' < 50 	loc outlinetrans 50
		else 					loc outlinetrans `transparency'
		di "`transparency'"

		*Manually modify orientation of label
		loc mlabp // init empty
		if inlist(`i', 1, 10, 11) 	loc mlabp 10 								// top left
		else if inlist(`i', 6, 8) 	loc mlabp 4 								// bottom right
		else 						loc mlabp 2 								// top right

		*Dynamically assign transparency
		loc cmd_tw `cmd_tw' (scatter beta treatment in `i', 					/// Point
			m(D) mcolor("0 110 185%`transparency'") mlc("0 110 185%`outlinetrans'")	///
			mlabel(mlabel) mlabp(`mlabp') mlabs(*.6) mlabc("0 110 185%70")) 
	}
	// end forvai i = 1(1)`r(N)'
	
	*Display effects
	di `"`cmd_tw'"'

	*Plot twoway
	set scheme s1color
	tw 	(line 		beta treatment 			if mi(country), 					///
			lwidth(thick) lcolor("129 181 60%70"))								///
		`cmd_tw',																/// Load dynamically assigned points
		xlab(0 "\$0" 1 "\$1.00" 2 "\$2.00" 3 "\$3.00" 4 "\$4.00" 5 "\$5.00" 6 "\$6.00") ///
		ylab(-.05 "-5%" 0 "0%" .05 "5%" .10 "10%" .15 "15%") 					///
		ytitle("Effect of Incentives on Response Rate") 						/// Ytitle
		xtitle("Incentive Size (2020 USD)") 									///
		legend(off) 															//

	graph export "`location'/output/cati_rr_lmic_meta.png", replace



**EOF**
