library(shiny)
library(httr)
library(jsonlite)
library(ggplot2)
library(dplyr)
library(lubridate)
library(shinydashboard)
library(DT)

# API credentials
client_id <- "YOUR_CLIENT_ID"
client_secret <- "YOUR_CLIENT_SECRET"
user_agent <- "RedditDashboardApp/0.1"

# Function to get access token
get_access_token <- function() {
  response <- POST(
    url = "https://www.reddit.com/api/v1/access_token",
    authenticate(client_id, client_secret),
    body = list(grant_type = "client_credentials"),
    encode = "form",
    add_headers(`User-Agent` = user_agent)
  )
  
  if (http_status(response)$category != "Success") {
    warning("Failed to get access token: ", content(response, "text"))
    return(NULL)
  }
  
  content(response)$access_token
}

# Function to fetch Reddit data
fetch_reddit_data <- function(subreddit, time_filter = "month", limit = 50) {
  # Get access token
  token <- get_access_token()
  if (is.null(token)) {
    return(NULL)
  }
  
  # Construct URL with proper subreddit formatting
  url <- sprintf("https://oauth.reddit.com/r/%s/hot", subreddit)
  cat("\nAttempting to fetch data from:", url, "\n")
  
  # Make API request
  response <- GET(
    url,
    query = list(limit = limit),
    add_headers(
      Authorization = paste("Bearer", token),
      `User-Agent` = user_agent
    )
  )
  
  # Check response status
  if (http_status(response)$category != "Success") {
    cat("Error: Failed to fetch data. Status:", http_status(response)$category, "\n")
    return(NULL)
  }
  
  # Parse JSON response
  data_text <- content(response, "text", encoding = "UTF-8")
  data_json <- fromJSON(data_text, flatten = TRUE)
  
  # Check if we have valid data
  if (!exists("data", data_json) || !exists("children", data_json$data)) {
    cat("Error: Invalid response structure\n")
    return(NULL)
  }
  
  # Extract posts from the flattened data structure
  posts <- data_json$data$children
  
  if (nrow(posts) == 0) {
    cat("Error: No posts found in response\n")
    return(NULL)
  }
  
  # Create a clean data frame with relevant fields
  clean_data <- data.frame(
    title = posts$data.title,
    author = posts$data.author,
    score = posts$data.score,
    num_comments = posts$data.num_comments,
    created_utc = posts$data.created_utc,
    selftext = posts$data.selftext,
    url = posts$data.url,
    permalink = posts$data.permalink
  )
  
  cat("Successfully fetched", nrow(clean_data), "posts\n")
  return(clean_data)
}

# Add this function to convert UTC timestamp to hour
get_hour <- function(timestamp) {
  as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC") %>%
    format("%H")
}

# UI with dashboard layout
ui <- dashboardPage(
  dashboardHeader(title = "Reddit Dashboard"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Data Table", tabName = "data", icon = icon("table")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    ),
    
    textInput("subreddit", "Enter Subreddit:", value = "rstats"),
    selectInput("timeFilter", "Time Filter:",
                choices = c("Day" = "day", 
                            "Week" = "week", 
                            "Month" = "month", 
                            "Year" = "year", 
                            "All Time" = "all"),
                selected = "month"),
    numericInput("postLimit", "Number of Posts:", value = 10, min = 10, max = 100),
    actionButton("fetch", "Fetch Data", icon = icon("sync"), 
                 class = "btn-primary", style = "width: 80%")
  ),
  
  dashboardBody(
    tabItems(
      # Dashboard tab content
      tabItem(tabName = "dashboard",
              fluidRow(
                valueBoxOutput("totalPosts", width = 4),
                valueBoxOutput("avgScore", width = 4),
                valueBoxOutput("avgComments", width = 4)
              ),
              
              fluidRow(
                box(
                  title = "Post Scores", status = "primary", solidHeader = TRUE,
                  collapsible = TRUE, width = 12,
                  plotOutput("scorePlot", height = "300px")
                )
              ),
              
              fluidRow(
                box(
                  title = "Comments vs. Score", status = "info", solidHeader = TRUE,
                  collapsible = TRUE, width = 6,
                  plotOutput("scatterPlot", height = "300px")
                ),
                box(
                  title = "Posts by Hour", status = "success", solidHeader = TRUE,
                  collapsible = TRUE, width = 6,
                  plotOutput("postsByDayPlot", height = "300px")
                )
              ),
              
              fluidRow(
                box(
                  title = "Top Authors", status = "warning", solidHeader = TRUE,
                  collapsible = TRUE, width = 6,
                  plotOutput("authorPlot", height = "300px")
                ),
                box(
                  title = "Upvote Ratio Distribution", status = "danger", solidHeader = TRUE,
                  collapsible = TRUE, width = 6,
                  plotOutput("upvotePlot", height = "300px")
                )
              )
      ),
      
      # Data table tab content
      tabItem(tabName = "data",
              box(
                title = "Reddit Posts Data", status = "primary", solidHeader = TRUE,
                width = 12,
                DTOutput("postsTable"),
                textOutput("debug")
              )
      ),
      
      # About tab content
      tabItem(tabName = "about",
              box(
                title = "About This Dashboard", status = "info", solidHeader = TRUE,
                width = 12,
                p("This dashboard retrieves data from Reddit using the Reddit API and visualizes it."),
                p("Enter a subreddit name, select time filter and number of posts, then click 'Fetch Data'."),
                p("Dashboard created with R Shiny and shinydashboard. API access via Reddit's OAuth API.")
              )
      )
    )
  )
)

# Server logic
server <- function(input, output, session) {
  # Store API token and data
  token <- reactiveVal(NULL)
  reddit_data <- reactiveVal(NULL)
  
  # Initialize token on startup
  observe({
    token(get_access_token())
    if (is.null(token())) {
      showNotification("Failed to authenticate with Reddit API. Check your credentials.", 
                       type = "error", duration = NULL)
    } else {
      showNotification("Successfully authenticated with Reddit API", type = "message")
    }
  })
  
  # Fetch data when button is clicked
  observeEvent(input$fetch, {
    # Check if token is available
    if (is.null(token())) {
      token(get_access_token())
      if (is.null(token())) {
        showNotification("Failed to authenticate with Reddit API", type = "error")
        return()
      }
    }
    
    # Show loading notification
    withProgress(message = "Fetching data...", {
      # Fetch data from Reddit
      subreddit <- trimws(input$subreddit)
      if (subreddit == "") {
        showNotification("Please enter a valid subreddit name", type = "warning")
        return()
      }
      
      # Print debugging information
      print(paste("Fetching data for subreddit:", subreddit))
      print(paste("Time filter:", input$timeFilter))
      print(paste("Post limit:", input$postLimit))
      
      posts <- fetch_reddit_data(
        subreddit = subreddit,
        time_filter = input$timeFilter,
        limit = input$postLimit
      )
      
      # Print debugging information about the response
      print(paste("Number of posts received:", if (!is.null(posts)) nrow(posts) else "NULL"))
      if (!is.null(posts) && "error" %in% names(posts)) {
        print(paste("Error in response:", posts$error))
      }
      
      # Check for errors
      if (is.null(posts) || ("error" %in% names(posts))) {
        error_msg <- if (is.null(posts)) "No data received" else posts$error
        showNotification(paste("Error:", error_msg), type = "error")
        return()
      }
      
      # Store data
      reddit_data(posts)
      
      # Print confirmation
      print(paste("Successfully stored", nrow(posts), "posts"))
      
      showNotification(paste("Successfully fetched", nrow(posts), "posts from r/", subreddit), 
                       type = "message")
    })
  })
  
  # Add debugging output for the data table
  output$debug <- renderText({
    posts <- reddit_data()
    if (is.null(posts)) {
      return("No data available")
    }
    paste("Data available with", nrow(posts), "rows")
  })
  
  # Render value boxes
  output$totalPosts <- renderValueBox({
    posts <- reddit_data()
    count <- if (is.null(posts)) 0 else nrow(posts)
    
    valueBox(
      count,
      "Total Posts",
      icon = icon("list"),
      color = "blue"
    )
  })
  
  output$avgScore <- renderValueBox({
    posts <- reddit_data()
    avg <- if (is.null(posts)) 0 else round(mean(posts$score), 1)
    
    valueBox(
      avg,
      "Average Score",
      icon = icon("thumbs-up"),
      color = "green"
    )
  })
  
  output$avgComments <- renderValueBox({
    posts <- reddit_data()
    avg <- if (is.null(posts)) 0 else round(mean(posts$num_comments), 1)
    
    valueBox(
      avg,
      "Average Comments",
      icon = icon("comments"),
      color = "purple"
    )
  })
  
  # Render plots
  output$scorePlot <- renderPlot({
    req(reddit_data())
    posts <- reddit_data()
    
    posts %>%
      arrange(created_utc) %>%
      mutate(post_number = row_number()) %>%
      ggplot(aes(x = post_number, y = score)) +
      geom_line(color = "#1976D2") +
      geom_point(color = "#1976D2", size = 2) +
      labs(
        title = paste("Post Scores in r/", input$subreddit),
        x = "Post Number (chronological)",
        y = "Score"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(face = "bold", size = 14),
        axis.title = element_text(size = 12)
      )
  })
  
  output$scatterPlot <- renderPlot({
    req(reddit_data())
    posts <- reddit_data()
    
    ggplot(posts, aes(x = score, y = num_comments)) +
      geom_point(aes(color = score), size = 3, alpha = 0.7) +
      scale_color_gradient(low = "orange", high = "blue") +
      labs(
        title = "Comments vs. Score",
        x = "Score",
        y = "Number of Comments",
        color = "Score"
      ) +
      theme_minimal()
  })
  
  # Replace the posts by day chart with posts by hour
  output$postsByDayPlot <- renderPlot({
    posts <- reddit_data()
    
    if (is.null(posts)) {
      return(ggplot() + 
        annotate("text", x = 0.5, y = 0.5, 
                label = "No data available", 
                size = 6) +
        theme_void())
    }
    
    # Convert UTC timestamps to hours
    posts$hour <- sapply(posts$created_utc, get_hour)
    
    # Count posts by hour
    hourly_counts <- posts %>%
      group_by(hour) %>%
      summarise(count = n()) %>%
      mutate(hour = as.numeric(hour))
    
    # Create the plot
    ggplot(hourly_counts, aes(x = hour, y = count)) +
      geom_bar(stat = "identity", fill = "#2196F3", alpha = 0.8) +
      scale_x_continuous(breaks = 0:23, labels = sprintf("%02d:00", 0:23)) +
      labs(
        title = "Posts by Hour (UTC)",
        x = "Hour of Day",
        y = "Number of Posts"
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.minor = element_blank()
      )
  })
  
  output$authorPlot <- renderPlot({
    req(reddit_data())
    posts <- reddit_data()
    
    posts %>%
      group_by(author) %>%
      summarize(post_count = n(), avg_score = mean(score)) %>%
      arrange(desc(post_count)) %>%
      head(10) %>%
      ggplot(aes(x = reorder(author, post_count), y = post_count)) +
      geom_col(aes(fill = avg_score)) +
      scale_fill_gradient(low = "yellow", high = "red") +
      coord_flip() +
      labs(
        title = "Top 10 Authors by Post Count",
        x = NULL,
        y = "Number of Posts",
        fill = "Avg Score"
      ) +
      theme_minimal()
  })
  
  output$upvotePlot <- renderPlot({
    req(reddit_data())
    posts <- reddit_data()
    
    ggplot(posts, aes(x = score)) +
      geom_histogram(bins = 10, fill = "#E91E63", color = "white", alpha = 0.8) +
      labs(
        title = "Distribution of Scores",
        x = "Score",
        y = "Count"
      ) +
      theme_minimal()
  })
  
  # Render data table
  output$postsTable <- renderDT({
    req(reddit_data())
    posts <- reddit_data()
    
    posts %>%
      select(
        title, author, score, num_comments, created_utc, 
        selftext, url, permalink
      ) %>%
      rename(
        "Title" = title,
        "Author" = author,
        "Score" = score,
        "Comments" = num_comments,
        "Created (UTC)" = created_utc,
        "Selftext" = selftext,
        "Link" = permalink
      ) %>%
      datatable(
        options = list(
          pageLength = 10,
          autoWidth = TRUE,
          scrollX = TRUE,
          order = list(list(2, 'desc'))  # Sort by score desc by default
        ),
        escape = FALSE,
        rownames = FALSE
      ) %>%
      formatRound(columns = c("Score"), digits = 2) %>%
      formatStyle(
        'Score',
        background = styleColorBar(c(0, max(posts$score)), 'lightblue'),
        backgroundSize = '100% 90%',
        backgroundRepeat = 'no-repeat',
        backgroundPosition = 'center'
      )
  })
}

# Run the app
shinyApp(ui = ui, server = server)
