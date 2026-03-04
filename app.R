library(shiny)
library(bslib)
library(dotenv)

# Load all our toolsets
load_dot_env(".env")
source("monday_functions.R")
source("gemini_functions.R")

# --- UI: User Interface ---
ui <- page_sidebar(
  title = "Founder BI Agent",
  theme = bs_theme(preset = "flatly"),
  
  # Sidebar for "Agent Action Visibility" requirement
  sidebar = sidebar(
    title = "Agent Activity Log",
    width = 300,
    tags$div(
      id = "action_log",
      style = "font-family: monospace; font-size: 0.85em; color: #333; height: 100%;",
      "🟢 System initialized...", tags$br(),
      "⏳ Waiting for query..."
    )
  ),
  
  # Main Chat Display
  card(
    card_header("Monday.com Business Intelligence"),
    
    # Area for chat messages
    tags$div(
      style = "height: 450px; overflow-y: auto; padding: 15px; background: #fdfdfd; border: 1px solid #ddd; border-radius: 8px; margin-bottom: 15px;",
      uiOutput("chat_display")
    ),
    
    # User Query Input
    layout_columns(
      col_widths = c(10, 2),
      textInput("user_query", label = NULL, placeholder = "Ask about pipeline, sectors, or project status...", width = "100%"),
      actionButton("send_btn", "Ask", class = "btn-primary", width = "100%")
    )
  )
)

# --- SERVER: Logic and API Integration ---
server <- function(input, output, session) {
  
  # Store conversation history
  chat_log <- reactiveVal(list())
  
  observeEvent(input$send_btn, {
    req(input$user_query)
    
    # Print to the RStudio console so we can see what is happening!
    print("--- NEW QUERY INITIATED ---")
    print(paste("Question:", input$user_query))
    
    # Update sidebar log
    insertUI(
      selector = "#action_log",
      where = "beforeEnd",
      ui = tags$div(paste0("🚀 Live API Call: Fetching board ", Sys.getenv("WORK_ORDERS_BOARD_ID")), tags$br())
    )
    
    # Fetch data live with safety wrappers
    withProgress(message = 'Retrieving real-time data...', value = 0.5, {
      
      board_id <- Sys.getenv("WORK_ORDERS_BOARD_ID")
      
      # Try to fetch the data. If it fails, catch the error instead of crashing.
      live_data <- tryCatch({
        print("Fetching Monday.com data...")
        get_board_dataframe(board_id)
      }, error = function(e) {
        print(paste("MONDAY ERROR:", e$message))
        return(NULL)
      })
      
      if (is.null(live_data)) {
        answer <- "Error: Failed to retrieve data from Monday.com. Check your API token."
      } else {
        print(paste("Success! Fetched", nrow(live_data), "rows from Monday.com."))
        
        insertUI(
          selector = "#action_log",
          where = "beforeEnd",
          ui = tags$div("🤖 Analyzing with Gemini...", tags$br())
        )
        
        # Try to contact Gemini. If it fails, catch the error.
        answer <- tryCatch({
          print("Sending data to Gemini API...")
          
          # CRITICAL FIX: We use head(live_data, 10) to only send the top 10 rows.
          # This prevents the payload from getting too large and crashing the connection.
          ask_gemini(input$user_query, head(live_data, 10))
          
        }, error = function(e) {
          print(paste("GEMINI ERROR:", e$message))
          return(paste("AI Connection Error:", e$message))
        })
        
        print("Gemini response received.")
      }
    })
    
    # Update chat history
    current_history <- chat_log()
    current_history <- c(current_history, list(list(user = input$user_query, agent = answer)))
    chat_log(current_history)
    
    # Clear input and update log
    updateTextInput(session, "user_query", value = "")
    insertUI(selector = "#action_log", where = "beforeEnd", ui = tags$div("✅ Done.", tags$br(), tags$hr()))
    
    print("--- QUERY FINISHED ---")
  })
  
  # Display the chat history nicely
  output$chat_display <- renderUI({
    history <- chat_log()
    if (length(history) == 0) return("Ask a question to begin live board analysis.")
    
    lapply(history, function(entry) {
      tagList(
        tags$div(style = "margin-bottom: 8px; color: #0056b3;", tags$b("Founders: "), entry$user),
        tags$div(style = "margin-bottom: 20px; background: #f1f3f5; padding: 12px; border-radius: 6px; border-left: 4px solid #0d6efd;", 
                 tags$b("BI Agent: "), entry$agent)
      )
    })
  })
}

# Run the Agent
shinyApp(ui = ui, server = server)