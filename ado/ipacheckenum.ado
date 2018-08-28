*! version 2.1.2 Isabel Onate & Rosemarie Sandino 15Aug2018

program ipacheckenum
	/* This command constructs the enumerator dashboard, a
	   collection of summary indicators of enumerator performance
	   including: 
	      * Number of interviews
	      * Rates of don't know/refusal
	      * Rates of missing response
		  * Rates of "other" response
	      * Duration of interview */
	version 15
	
	#d ;
	syntax varname using/ ,
	    dkrfvars(varlist) 
	    missvars(varlist) 
		othervars(varlist)
	    subdate(varname)
		[durvars(varlist) duration(varname) exclude(varlist) foteam(varlist) days(integer 7)]
		statvars(varlist) [mean] [sd] [min] [max]
		[replace modify]
		[nolab];
	#d cr
	qui {
	
	// capture enumerator variable
	local enum `varlist'
	
	// capture variable list in memory
	unab allvars : _all
	local loopvars : list allvars - exclude
	local loopvars : list loopvars - durvars
	
	// define temp file
	tempfile summary_sheet missing_sheet dontknow_sheet refusal_sheet other_sheet duration_sheet

	#d ;
	tempvar interviews 
	        missing
	        dontknow
	        refusal
			other
	        recent_interviews
	        recent_missing
	        recent_dontknow
	        recent_refusal
	        recent_duration
			recent_other
	        row_nonmiss 
	        row_miss 
	        row_dk 
	        row_rf
			row_oth 
	        col_sub_nonmiss
	        col_sub_miss
	        col_sub_dk
	        col_sub_rf
			col_sub_oth 
	        col_sub_dur
	        col_sub_dkrate
	        col_sub_rfrate
	        col_sub_missrate
			col_sub_othrate;
	#d cr

	// set count variables
	g `interviews' = 1
	g `row_nonmiss' = 0
	g `row_miss' = 0
	g `row_dk' = 0
	g `row_rf' = 0
	g `row_oth' = 0
	
	// initialize duration variable, create local have_duration to signal existence of duration variable
	if "`duration'" == "" {
		cap confirm variable duration
		if _rc == 0 {
			tempvar duration
			g `duration' = duration
			loc have_duration = 1
		}
		else {
			cap confirm variable endtime starttime
			if _rc == 0 {
				tempvar duration
				g `duration' = (endtime - starttime)/60000
				loc have_duration = 1
			}
			else {
				loc have_duration = 0
			}
		}
	}
	else {
		loc have_duration = 1
	}
	if `have_duration' {
		replace `duration' = . if `duration' < 0
	}

	/* loop through all variables, count number of interviews;
	   nonmissing and missing responses; don't knows; refusals and
	   durations by enumerator */
	foreach var of varlist `loopvars' {

		cap confirm numeric variable `var' 
		// string variables
		if _rc  {
			scalar miss = ""
			scalar dk = "don't know"
			scalar rf = "refusal"
			scalar oth = "other" 
		}
		// numeric variables
		else {
			scalar miss = .
			scalar dk = .d
			scalar rf = .r
			scalar oth = .o 
		}
		count if `var' != miss
		if r(N) > 0 {
		// count the number of nonmissing, don't know, or refusal by obs
		replace `row_nonmiss' = `row_nonmiss' + cond(`var' != miss, 1, 0)
		replace `row_miss' = `row_miss' + cond(`var' == miss, 1, 0)
		replace `row_dk' = `row_dk' + cond(`var' == dk, 1, 0)
		replace `row_rf' = `row_rf' + cond(`var' == rf, 1, 0)
		replace `row_oth' = `row_oth' + cond(`var' == oth, 1, 0)

		// count the number of nonmissing, don't know, or refusal per variable
		quietly count if `var' != miss
		local col_nonmiss = r(N)
		quietly count if `var' == miss
		local col_miss = r(N)
		quietly count if `var' == dk
		local col_dk = r(N)
		quietly count if `var' == rf
		local col_rf = r(N)
		quietly count if `var' == oth 
		local col_oth = r(N) 
		
		// variable subtotals by enumerator
		bysort `enum': egen `col_sub_nonmiss' = total(`var' != miss)
		bysort `enum': egen `col_sub_miss' = total(`var' == miss)
		bysort `enum': egen `col_sub_dk' = total(`var' == dk)
		bysort `enum': egen `col_sub_rf' = total(`var' == rf)
		bysort `enum': egen `col_sub_oth' = total(`var' == oth)

		// don't know and refusal rates by enumerator
		g `col_sub_dkrate' = `col_sub_dk' / `col_sub_nonmiss'
		g `col_sub_rfrate' = `col_sub_rf' / `col_sub_nonmiss'
		g `col_sub_missrate' = `col_sub_miss' / (`col_sub_nonmiss' + `col_sub_miss')
		g `col_sub_othrate' = `col_sub_oth' / `col_sub_nonmiss' 
		
		
		/* if variable is in the list of important don't know 
		   or refusal variables update respective sub sheets */
		local inlist : list var in dkrfvars
		if `inlist' {
			_updatesheet `col_sub_dkrate' using `dontknow_sheet', by(`enum') rename(`var')
			loc dk`var'low = `r(low)' 
			loc dk`var'hi = `r(high)'
			_updatesheet `col_sub_rfrate' using `refusal_sheet', by(`enum') rename(`var')
			loc rf`var'low = `r(low)' 
			loc rf`var'hi = `r(high)'

		}

		/* if variable is in the list of important missing
		   variables update respective sub sheets */
		local inlist : list var in missvars
		if `inlist' {
			_updatesheet `col_sub_missrate' using `missing_sheet', by(`enum') rename(`var')
			local mi`var'low = `r(low)' 
			local mi`var'hi = `r(high)'

		}
		
		/* if variable is in the list of important "other"
		   variables update respective sub sheets */
		local inlist : list var in othervars
		if `inlist' {
			_updatesheet `col_sub_othrate' using `other_sheet', by(`enum') rename(`var')
			loc oth`var'low = `r(low)' 
			loc oth`var'hi = `r(high)'
		}
		
		// drop col vars
	    drop `col_sub_nonmiss'  ///     
	         `col_sub_miss'     ///  
	         `col_sub_dk'       ///
	         `col_sub_rf'       ///
			 `col_sub_oth'       ///
	         `col_sub_dkrate'   ///    
	         `col_sub_rfrate'   ///    
	         `col_sub_missrate' ///
			 `col_sub_othrate'
		}
	}
	
	/* loop through the duration variables, calculate the mean
	   and update the duration sheet */
	if "`durvars'" != "" {
		foreach var of varlist `durvars' {
			replace `var' = 0 if `var' < 0 & !mi(`var')
			bysort `enum': egen `col_sub_dur' = mean(`var')
			_updatesheet `col_sub_dur' using `duration_sheet', by(`enum') rename(`var')
			loc dur`var'low = `r(low)' //Rosemarie
			loc dur`var'hi = `r(high)'
			drop `col_sub_dur'
		}
	}
	
	
	// create summary sheet
	preserve

	// restrict to specified number of days
	local today = date(c(current_date), "DMY")
	ds `subdate', has(format %td*)
	// tests if the date is already in td format
	if "`r(varlist)'" != "" {
		keep if `subdate' > `today' - `days'
	}
	// if not already in td format, uses dofc for date
	else {
		keep if dofc(`subdate') > `today' - `days'
	}
	
	// create collapse command for calculating subtotals by enumerator
	if !`have_duration' {
		loc collapse_command "collapse (sum) `interviews' `row_nonmiss' `row_miss' `row_dk' `row_rf' `row_oth', by(`enum') cw" 
	}
	else {
		loc collapse_command "collapse (sum) `interviews' `row_nonmiss' `row_miss' `row_dk' `row_rf' `row_oth' (mean) `duration', by(`enum') cw" 
	}
	

	// caluculate subtotals by enumerator
	if `=_N' > 0 {
	   `collapse_command'
	   isid `enum'
		
	    // calculate rates
	    g `recent_interviews' = `interviews'
		if `have_duration' {
			g `recent_duration' = `duration'
		}
		else {
			g `recent_duration' = .
		}
	    g `recent_missing' = `row_miss' / (`row_miss' + `row_nonmiss')
	    g `recent_dontknow' = `row_dk' / `row_nonmiss'
	    g `recent_refusal' = `row_rf' / `row_nonmiss'
		g `recent_other' = `row_oth' / `row_nonmiss' 

	    // drop row totals
	   drop `interviews' `row_miss' `row_nonmiss' `row_dk' `row_rf' `row_oth' 
	}
	else {
		keep `enum'

	    // calculate rates
	    g `recent_interviews' = 0
		if `have_duration' {
			g `recent_duration' = 0
		}
		else {
			g `recent_duration' = ""
		}
	    g `recent_missing' = 0
	    g `recent_dontknow' = 0
	    g `recent_refusal' = 0
		g `recent_other' = 0
	}
	
	loc cols 
	
	save `summary_sheet', replace
	restore

	preserve 
	
	// caluculate subtotals by enumerator
	`collapse_command'

	// calculate rates
	g `missing' = `row_miss' / (`row_miss' + `row_nonmiss')
	g `dontknow' = `row_dk' / `row_nonmiss'
	g `refusal' = `row_rf' / `row_nonmiss'
	g `other' = `row_oth' / `row_nonmiss'

	// drop and save
	drop `row_miss' `row_nonmiss' `row_dk' `row_rf' `row_oth'

	// merge with overall totals
	merge 1:1 `enum' using `summary_sheet', nogenerate

	// order and save 
	 order 		`enum'              ///
				`recent_interviews' ///          
				`interviews'        ///   
				`recent_missing'    ///       
				`missing'           ///
				`recent_dontknow'   ///       
				`dontknow'          ///
				`recent_refusal'    ///      
				`refusal'           ///
				`recent_other'	///
				`other'			  ///
				`recent_duration'   ///     
				`duration'     
			  
	loc vars_order		recent_interviews interviews recent_missing missing recent_dontknow'   ///       
						dontknow recent_refusal refusal recent_other other recent_duration duration

    ds, has(type numeric)
	format `r(varlist)' %9.2f
	save `summary_sheet', replace

	// Calculate lower an upper 10 percent
	foreach var of local vars_order {
		cap confirm var `var' 
		if _rc == 0 {
			qui sum ``var'', detail
			loc `var'_low = `r(p10)'
			loc `var'_hi = `r(p90)'
		}
	}
	    
	
	restore
	
	// drop count variables
	drop `interviews' `row_miss' `row_nonmiss' `row_dk' `row_rf' `row_oth'

	preserve

	// set export locals
	local i = 0
	local sheet_names "summary missing dontknow refusal other duration"
	
	/* loop through tempfiles and export them as sheets in the
	   excel workbook; set the filename of the workbook equal
	   to the string in `using' */
	foreach sheet in `summary_sheet' `missing_sheet' `dontknow_sheet' `refusal_sheet' `other_sheet' `duration_sheet' {

		local i = `i' + 1
		local name : word `i' of `sheet_names'
		
		// confirm the tempfile exist before writing
		cap confirm file `sheet'	
		if !_rc {
			use `sheet', clear
			if _N > 0 {
				if "`name'" == "summary" {
					// summary sheet conditions
					export excel using "`using'", sheet("`name'") replace cell(A4) missing("0")
					mata: format_summary("`using'", `=_N') //Rosemarie
				} 
				else {
					// sub sheet conditions
					export excel using "`using'", sheet("`name'") firstrow(var) sheetmodify cell(A1) missing("0")
					ds // Rosemarie
					loc colcount `:word count `r(varlist)''
					mata: format_sheets("`using'", "`name'", `colcount', `=_N')
				}
			}
		}
	}

	restore 
	
	}
end

capture program drop _updatesheet
program _updatesheet
	/* this subroutine updates the sub sheet temp files
	   that capture per variable rates and stats */
	qui {
	syntax varname using/ , by(varname) rename(varname)
	preserve

	tempfile tmp
	
	format `varlist' %9.3f
	collapse (max) `varlist', by(`by')
	ren `varlist' `rename'
	
	save `tmp', replace 

	cap confirm file "`using'"
	if _rc {
		save "`using'", replace
	}
	else {
		use "`using'", clear
		merge 1:1 `by' using `tmp', nogenerate
		save "`using'", replace
	}
	restore
	}
end

///////////// FORMATING ////////////////

***To do: 
* Change color so bottom and top tenth are red -- DONE
* fix percentage so it shows decimals -- DONE
* add min/max duration to summary sheet
* add scale colors to summary sheet

mata:
mata clear

// Format summary sheet
void format_summary(string scalar filename, real scalar N) 
{
	// set up
	class xl scalar b
	real matrix merges
	real scalar i, column_width

	b = xl()
	b.load_book(filename)
	b.set_mode("open")
	b.set_sheet("summary")
	
	// Titles
	b.put_string(1, 2, "Interviews")
	b.put_string(1, 4, "Missing")
	b.put_string(1, 6, "Don't Know")
	b.put_string(1, 8, "Refusals")
	b.put_string(1, 10, "Other")
	b.put_string(1, 12, "Duration")

	b.put_string(2, 2, "count")
	b.put_string(2, 4, "% of all responses")
	b.put_string(2, 6, "% of non-missing")
	b.put_string(2, 8, "% of non-missing")
	b.put_string(2, 10, "% of non-missing")
	b.put_string(2, 12, "mean")

	b.put_string(3, 1, "Enumerator")
	
	merges = (2\4\6\8\10\12)
	for (i=1; i<=6; i++) {
		b.set_horizontal_align(1, (merges[i], merges[i]+1), "merge")
		b.set_horizontal_align(2, (merges[i], merges[i]+1), "merge")
		b.put_string(3, merges[i], "7 days")
		b.put_string(3, merges[i]+1, "Total")
	}
	
	// Format
	b.set_font_bold((1,3), (1,13), "on")
	b.set_font_italic(2, (2, 13), "on")
	
	b.set_horizontal_align(3, (1, 13), "center")
	b.set_horizontal_align((4, N+4), (2, 13), "center")

	b.set_bottom_border(1, (2, 13), "thin")
	b.set_bottom_border(3, (1, 13), "thin")
	b.set_bottom_border(N+3, (1, 13), "thin")
	
	lines = (1\3\5\7\9\11\13)
	for (i=1; i<8; i++) {
		b.set_right_border((4,N+3), lines[i], "thin")
	}
	
	b.set_number_format((4, N+3), (4, 11), "percent_d2")
	
	enums = b.get_string((3,N+4), 1)
	column_width = colmax(strlen(enums))
	b.set_column_width(1, 1, column_width)
	
	
	b.close_book()

}

// Format missing, dontknow, refusal, other, and duration sheets
void format_sheets(string scalar filename, string scalar sheet, real scalar colcount, real scalar N) 
{
	// set up
	class xl scalar b
	string scalar locallow, localhi, str
	real scalar lower, higher, i, j, column_width
	string matrix varnames, enums

	b.load_book(filename)
	b.set_mode("open")
	b.set_sheet(sheet)

	// Titles
	b.put_string(1, 1, "Enumerator") 
	
	// Format
	b.set_font_bold(1, (1, colcount), "on")
	b.set_bottom_border(1, (1, colcount), "thin") 
	b.set_bottom_border(N+1, (1, colcount), "thin")
	b.set_horizontal_align(1, (1, colcount), "center")

	enums = b.get_string((1,N+1), 1)
	column_width = colmax(strlen(enums))
	b.set_column_width(1,1,column_width)

	// color scales
	if (colcount <= 2) {
		varnames = b.get_string(1, 2)
	}
	else varnames = b.get_string(1, (2, colcount))

	if (sheet=="dontknow") str = "dk"
	else if (sheet=="missing") str = "mi"
	else if (sheet=="refusal") str = "rf"
	else if (sheet=="duration") str = "dur"
	else if (sheet=="other") str = "oth"

	for (i=1; i<=length(varnames); i++) {

		column_width = strlen(varnames[i])+2
		b.set_column_width(i+1, i+1, column_width)
		locallow = str + varnames[i] + "low"
		localhi = str + varnames[i] + "hi"
		lower = strtoreal(st_local(locallow))
		higher = strtoreal(st_local(localhi))
		
		values = b.get_number((2,N+1), i + 1)
		
		for (j=1; j<=N; j++) {
			if (sheet!="duration") {
				b.set_number_format(j+1, i+1, "percent_d2")
			}
			if (sheet=="duration") {
				b.set_number_format(j+1, i+1, "number_sep_d2")
			}
			if (values[j]!=0 & (values[j] <= lower | values[j] >= higher)) {
				b.set_fill_pattern(j + 1, i + 1, "solid", "pink")
			}
			b.set_horizontal_align(j+1, i+1, "center")
		}
	}
	
	// Close
	b.close_book()
}
