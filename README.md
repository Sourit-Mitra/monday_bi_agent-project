

# Architecture & Decision Log: Monday.com BI Agent

## 1. System Architecture

This application is designed as a centralized Business Intelligence agent for company founders. It consists of three main components:

* **The Frontend Interface:** Built using R Shiny and `bslib`, providing a real-time chat window and a live "Agent Activity Log" sidebar.
* **The Data Pipeline:** A set of custom R functions (`httr2`, `jsonlite`, `dplyr`, `tidyr`) that query the Monday.com GraphQL API in real-time, retrieving raw nested JSON and flattening it into a structured dataframe.
* **The AI Engine:** Integration with the Gemini 2.5 Flash API to parse the cleaned dataframe and generate natural language answers to user queries.

## 2. Key Technical Decisions

* **R & Shiny:** Chosen for their rapid prototyping capabilities and excellent data manipulation packages (the `tidyverse`). Shiny allows for reactive UI updates, which was essential for fulfilling the "Agent Action Visibility" requirement.
* **Gemini 2.5 Flash:** Selected as the LLM provider due to its fast inference speed, high token limit, and strong capability in reading structured JSON/tabular data to answer analytical questions accurately.
* **Live API Fetching vs. Webhooks:** The app is designed to fetch fresh board data via the Monday.com API *every time* a user submits a query. This ensures the founders are always chatting with the most up-to-date pipeline numbers, prioritizing data accuracy over caching.

## 3. Challenges & Solutions

* **Handling Complex Nested JSON:** Monday.com's GraphQL API returns highly nested item data. I solved this by mapping over the items using `purrr` and pivoting the specific column variables (`pivot_wider`) to create a clean, rectangular dataframe suitable for AI context.
* **LLM Payload Limits:** Sending an entire database to an LLM can cause connection timeouts or exceed token limits. I implemented a truncation safety mechanism (`head(monday_data_df, 15)`) to send only the most relevant top rows, ensuring the API calls remain lightweight and fast.



**Note**: Please ensure you have the following packages installed before running: `shiny`, `bslib`, `httr2`, `jsonlite`, `dotenv`, `dplyr`, `tidyr`, `purrr`.