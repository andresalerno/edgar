#' Retrieves quarterly master index.
#'
#' \code{getMasterIndex} retrieves the quarterly master index from US SEC site.
#'
#' getMasterIndex function takes filing year as an input parameter from user,  
#' download quarterly master index from https://www.sec.gov/Archives/edgar/full-index/.
#' It strips the headers, converts into dataframe, and merges such quarterly
#' dataframes into yearly dataframes and stored it in Rda format.
#' Function creates new directory 'Master Index' into working directory 
#' to save these Rda Master Index. Please note, for all other functions in this 
#' package needs to locate the same working directory to access these Rda master index files.  
#'  
#' @usage getMasterIndex(year.array)
#'
#' @param year.array year in integer or integer array containing years for which master 
#' index are to be downloaded.
#' 
#' @return Function retrieves quarterly master index files 
#' from \url{https://www.sec.gov/Archives/edgar/full-index/} site and returns download status dataframe.
#'   
#' @examples
#' \dontrun{
#' 
#' report <- getMasterIndex(1995) 
#' ## Downloads quarterly master index files for the year 1995 and stores into yearly  
#' ## 1995master.Rda file. It returns download report in dataframe format.
#' 
#' report <- getMasterIndex(c(1994, 2006, 2014)) 
#' ## Download quarterly master index files for the years 1994, 1995, 2006 and stores into 
#' ## different {year}master.Rda files. It returns download report in dataframe format.
#'}

getMasterIndex <- function(year.array) {
  if (!is.numeric(year.array)) {
    cat("Please provide valid year.")
    return()
  }
  
  # Check the download compatibility based on OS
	if (nzchar(Sys.which("libcurl")))  {
	  dmethod <- "libcurl"
	} else if (nzchar(Sys.which("wget"))) {
	  dmethod <- "wget"
	} else if (nzchar(Sys.which("curl"))) {
	  dmethod <- "curl"
	} else{
	  dmethod <- "auto"
	}
	
  # function to download file and return FALSE if download
  # error
  DownloadFile <- function(link, dfile, dmethod) {
    tryCatch({
      utils::download.file(link, dfile, method = dmethod, quiet = TRUE)
      return(TRUE)
    }, error = function(e) {
      return(FALSE)
    })
  }
  
  options(warn = -1)
  dir.create("Master Index")
  
  status.array <- data.frame()
  
  for (i in 1:length(year.array)) {
    year <- year.array[i]
    year.master <- data.frame()
    quarterloop <- 4
    
    # Find the number of quarter completed in that year
    if (year == format(Sys.Date(), "%Y")) {
      quarterloop <- ceiling(as.integer(format(Sys.Date(), 
        "%m"))/3)
    }
    
    for (quarter in 1:quarterloop) {
      # save downloaded file as specific name
      dfile <- paste0("Master Index/", year, "QTR", quarter, 
        "master.gz")
      file <- paste0("Master Index/", year, "QTR", quarter, 
        "master")
      
      # form a link to download master file
      link <- paste0("https://www.sec.gov/Archives/edgar/full-index/", 
        year, "/QTR", quarter, "/master.gz")
      
      res <- DownloadFile(link, dfile, dmethod)
      if (res) {
        # Unzip gz file
        R.utils::gunzip(dfile, destname = file, temporary = FALSE, 
          skip = FALSE, overwrite = TRUE, remove = TRUE)
        cat("Successfully downloaded Master Index for year:", 
          year, "and quarter:", quarter, "\n")
        
        # Removing ''' so that scan with '|' not fail due to
        # occurrence of ''' in company name
        data <- gsub("'", "", readLines(file))
        
        # Find line number where header description ends
        header.end <- grep("--------------------------------------------------------", data)
        
        # writting back to storage
        writeLines(data, file)
        
        d <- scan(file, what = list("", "", "", "", ""), 
          flush = F, skip = header.end, sep = "|", quiet = T)
        
        # Remove punctuation characters from company names
        COMPANY_NAME <- gsub("[[:punct:]]", " ", d[[2]], 
          perl = T)
        
        data <- data.frame(CIK = d[[1]], COMPANY_NAME = COMPANY_NAME, 
          FORM_TYPE = d[[3]], DATE_FILED = d[[4]], EDGAR_LINK = d[[5]], 
          QUARTER = quarter)
        year.master <- rbind(year.master, data)
        file.remove(file)
        status.array <- rbind(status.array, data.frame(Filename = paste0(year, 
          ": quarter-", quarter), status = "Download success"))
      } else {
        status.array <- rbind(status.array, data.frame(Filename = paste0(year, 
          ": quarter-", quarter), status = "Server Error"))
      }
    }
    
    assign(paste0(year, "master"), year.master)
    save(year.master, file = paste0("Master Index/", year, 
      "master.Rda"))
  }
  return(status.array)
}
