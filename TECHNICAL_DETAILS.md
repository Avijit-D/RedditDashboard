# Reddit Analytics Dashboard

![R](https://img.shields.io/badge/R-276DC3?style=flat&logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-blue?style=flat)
![OAuth](https://img.shields.io/badge/OAuth-2.0-green)

**R | Shiny | OAuth 2.0 | REST API | Reactive Systems**

---

## Overview

This project is a live Reddit analytics dashboard built using **R Shiny**. It integrates with Reddit's OAuth-secured API to fetch real-time subreddit data and transform it into structured engagement insights.

The application demonstrates:

- OAuth 2.0 authentication (client credentials flow)
- API integration using `httr`
- Nested JSON parsing and flattening
- Reactive state management in Shiny
- Data transformation with `dplyr`
- Interactive visualization with `ggplot2`
- Dashboard UI using `shinydashboard`
- Interactive tables using `DT`

---

## Repository Structure

```
reddit-analytics-dashboard/
├── app.R                 # Main Shiny application
├── README.md            # This file
└── SETUP.md             # Installation and configuration guide
```

**Future modularization:**
```
R/
├── authentication.R
├── api_fetch.R
├── processing.R
└── visualization.R
```

---

## Tech Stack

- **R** - Core language
- **Shiny** - Web application framework
- **shinydashboard** - Dashboard UI components
- **httr** - HTTP client for API requests
- **jsonlite** - JSON parsing
- **dplyr** - Data manipulation
- **ggplot2** - Visualizations
- **lubridate** - Timestamp handling
- **DT** - Interactive tables

---

## Problem Statement

Reddit provides rich engagement data through its API, but:

- The data is deeply nested JSON
- Manual browsing does not reveal structural insights
- Engagement patterns are not immediately visible

This application converts raw Reddit API responses into a reactive analytics interface that answers:

- How active is a subreddit?
- Do high-score posts generate discussion?
- When are posts most frequent?
- Are a few authors dominating activity?

---

## System Architecture

### High-Level Flow

```
User Input (subreddit, filters, limit)
    ↓
OAuth 2.0 Authentication
    ↓
Reddit API Request (/r/{subreddit}/hot)
    ↓
JSON Response Validation
    ↓
Data Parsing & Flattening
    ↓
Feature Engineering (hour extraction, aggregations)
    ↓
Reactive Storage (reactiveVal)
    ↓
UI Updates (plots, tables, value boxes)
```

---

## Architecture Components

### 1. Authentication Layer

Reddit requires OAuth 2.0 for API access.

**Grant Type:** Client Credentials (application-only auth)

**Flow:**
- POST request to `https://www.reddit.com/api/v1/access_token`
- Retrieve access token
- Attach token via Authorization header in subsequent requests

**Implementation:**
```r
get_access_token <- function() {
  response <- POST(
    url = "https://www.reddit.com/api/v1/access_token",
    authenticate(client_id, client_secret),
    body = list(grant_type = "client_credentials"),
    encode = "form",
    add_headers(`User-Agent` = user_agent)
  )
  
  if (http_status(response)$category != "Success") {
    return(NULL)
  }
  
  content(response)$access_token
}
```

**Key Requirements:**
- Custom User-Agent header (mandatory for Reddit API)
- HTTP status validation
- Token stored in `reactiveVal()` for session reuse

---

### 2. Data Access Layer

**Endpoint:** `https://oauth.reddit.com/r/{subreddit}/hot`

**Request Structure:**
- GET request with Bearer token
- Query parameters: `limit` (number of posts)
- Headers: `Authorization`, `User-Agent`

**Error Handling:**

The system validates and handles:
- Authentication failure → `showNotification()` with error message
- Invalid subreddit → Returns NULL, triggers UI notification
- HTTP status != 200 → Logs error, returns NULL
- Unexpected JSON structure → Validates before parsing
- Empty datasets → Conditional rendering with `req()`

**Example:**
```r
if (http_status(response)$category != "Success") {
  cat("Error: Failed to fetch data. Status:", http_status(response)$category, "\n")
  return(NULL)
}
```

---

### 3. JSON Parsing & Data Processing

**Reddit API Structure:**
```
data
 └── children
      └── data
           ├── title
           ├── author
           ├── score
           └── ...
```

**Flattening Strategy:**
```r
data_json <- fromJSON(data_text, flatten = TRUE)
posts <- data_json$data$children
```

**Extracted Fields:**
- title
- author
- score
- num_comments
- created_utc
- permalink
- selftext
- url

**Feature Engineering:**
- Convert Unix timestamp → POSIXct
- Extract posting hour from timestamp
- Aggregate author-level metrics (post count, avg score)
- Calculate summary statistics (mean score, mean comments)

---

### 4. Reactive State Management

**Core Reactivity Components:**
```r
token <- reactiveVal(NULL)
reddit_data <- reactiveVal(NULL)

observeEvent(input$fetch, {
  # Fetch and store data
  reddit_data(posts)
})
```

**Reactive Pipeline:**

When the user clicks "Fetch Data":
1. `observeEvent()` triggers API call
2. Data is stored in `reactiveVal()`
3. All downstream components (plots, tables, value boxes) automatically re-render
4. No explicit `update()` calls needed

**This differs from imperative frameworks** where each UI element must be manually refreshed.

**Safety Mechanisms:**
- `req()` ensures data exists before rendering
- `if (is.null(posts))` checks prevent crashes
- Input sanitization with `trimws()`

---

### 5. Visualization Layer

**Value Boxes:**
- Total posts
- Average score
- Average comments

**Plots:**
1. **Score Trend** - Chronological post ordering
2. **Comments vs Score** - Correlation scatter plot
3. **Posts by Hour (UTC)** - Temporal activity distribution
4. **Top Authors** - Top 10 by post count with avg score gradient
5. **Score Distribution** - Histogram of upvote patterns

**Styling:**
```r
theme_minimal() +
theme(
  plot.title = element_text(face = "bold", size = 14),
  axis.title = element_text(size = 12)
)
```

**Color Schemes:**
- Gradient scales for intensity visualization
- Dashboard status classes (primary, info, success, warning, danger)

---

### 6. UI Design

**Framework:** `shinydashboard`

**Layout Structure:**
```r
dashboardPage(
  dashboardHeader(title = "Reddit Dashboard"),
  dashboardSidebar(...),
  dashboardBody(...)
)
```

**Components:**
- Sidebar inputs (subreddit, time filter, post limit)
- Action button trigger
- Tabbed interface (Dashboard, Data Table, About)
- Collapsible visualization panels
- Interactive DataTable

**Table Features:**
```r
datatable(
  options = list(
    pageLength = 10,
    scrollX = TRUE,
    order = list(list(2, 'desc'))  # Sort by score
  )
) %>%
formatStyle(
  'Score',
  background = styleColorBar(c(0, max(posts$score)), 'lightblue')
)
```

- Sortable columns
- Horizontal scroll support
- Conditional color bars for score magnitude
- Default descending sort by score

---

## Key Design Decisions

### 1. Separation of Concerns

Authentication, data retrieval, processing, and rendering are logically separated in distinct functions.

### 2. Defensive Programming

- HTTP status validation before processing
- JSON structure validation before parsing
- Input sanitization (`trimws()`)
- Conditional rendering guards (`req()`, null checks)

### 3. Reactive-First Architecture

State changes propagate automatically via Shiny's reactive model rather than imperative updates. This ensures clean separation between data flow and UI rendering.

### 4. Extensibility

Current architecture supports:
- Endpoint switching (`/top`, `/new`, `/controversial`)
- Sentiment analysis integration
- Historical snapshot persistence
- Multi-subreddit comparison
- Caching layer implementation

---

## Limitations & Known Issues

**API Constraints:**
- **Time filtering limitation:** The `/hot` endpoint does not support time filtering (e.g., `?t=week`). To enable time-based queries, switch to `/top` or `/controversial` endpoints which accept the `t` parameter.
- No token refresh logic (tokens expire after ~1 hour)
- No rate limit backoff handling

**Architecture:**
- No persistent database storage
- No caching mechanism
- Single-file app structure (not modularized)

**Features:**
- No NLP or sentiment analysis layer
- No cross-subreddit comparison mode
