library(httr2)
library(jsonlite)
library(dotenv)

load_dot_env(".env")

ask_gemini <- function(user_question, monday_data_df) {
  api_key <- Sys.getenv("GEMINI_API_KEY")
  
  # Safety Check: Limit the data sent to the AI to avoid 'Token Limit' crashes
  # We'll send only the first 15 rows and the most important columns
  small_df <- head(monday_data_df, 15)
  data_context <- toJSON(small_df, auto_unbox = TRUE)
  
  system_instruction <- "You are a BI Agent. Answer based ONLY on the provided JSON data. If the data is empty, say 'No data found.' Be concise."
  
  full_prompt <- paste0(system_instruction, "\n\nDATA:\n", data_context, "\n\nQUESTION: ", user_question)
  
  body <- list(contents = list(list(parts = list(list(text = full_prompt)))))
  
  # CRITICAL FIX: Updated the URL to use the active gemini-2.5-flash model instead of the retired 1.5 version
  url <- paste0("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=", api_key)
  
  # Use a try-catch block to prevent the whole app from closing if the API fails
  result_text <- tryCatch({
    req <- request(url) |>
      req_headers("Content-Type" = "application/json") |>
      req_body_json(body) |>
      req_retry(max_tries = 3) # Retry if the connection is blippy
    
    resp <- req_perform(req)
    res_json <- resp_body_json(resp)
    
    # Check if we got a valid response structure back
    if (!is.null(res_json$candidates)) {
      res_json$candidates[[1]]$content$parts[[1]]$text
    } else {
      "Gemini returned an empty result. Check your API key or data size."
    }
    
  }, error = function(e) {
    paste("Error calling Gemini API:", e$message)
  })
  
  return(result_text)
}