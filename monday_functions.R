library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)
library(dotenv)

# Load the credentials from the .env file
load_dot_env(".env")

# --- 1. Function to Fetch Raw Data ---
fetch_monday_data <- function(board_id) {
  token <- Sys.getenv("MONDAY_API_TOKEN")
  if(token == "") stop("Token is blank. Check .env file.")
  
  # Fetching 100 rows for our agent to play with
  graphql_query <- sprintf(
    '{ "query": "query { boards(ids: [%s]) { items_page(limit: 100) { items { name column_values { column { title } text } } } } }" }', 
    board_id
  )
  
  req <- request("https://api.monday.com/v2") |>
    req_headers(
      "Authorization" = token,
      "Content-Type" = "application/json",
      "API-Version" = "2024-01"
    ) |>
    req_body_raw(graphql_query)
  
  resp <- req_perform(req)
  result <- resp_body_json(resp)
  
  return(result$data$boards[[1]]$items_page$items)
}

# --- 2. Function to Clean and Flatten Data ---
clean_monday_data <- function(raw_items) {
  # Loop over every item and turn it into a flat row
  clean_df <- map_dfr(raw_items, function(item) {
    
    # 1. Grab the project/deal name
    base_row <- tibble(Project_Name = item$name)
    
    # 2. Extract the columns
    cols <- map_dfr(item$column_values, function(cv) {
      tibble(
        title = cv$column$title,
        text = ifelse(is.null(cv$text) || cv$text == "", NA_character_, cv$text) # Turn blanks into proper NAs
      )
    })
    
    # 3. Pivot wider so titles become column headers
    wide_cols <- cols |> 
      pivot_wider(names_from = title, values_from = text)
    
    # 4. Bind the name and the columns together
    bind_cols(base_row, wide_cols)
  })
  
  return(clean_df)
}

# --- 3. Master Function ---
# This is the single function our AI Agent will call!
get_board_dataframe <- function(board_id) {
  raw_data <- fetch_monday_data(board_id)
  clean_data <- clean_monday_data(raw_data)
  return(clean_data)
}