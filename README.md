# Reddit Dashboard in R

A powerful and interactive dashboard built with R Shiny that visualizes Reddit data from any subreddit. This dashboard provides real-time insights into Reddit posts, including engagement metrics, author statistics, and temporal patterns

## Project Write-Up

For a detailed explanation of the product thinking, design decisions, and development process behind this dashboard, read the full Medium article:

🔗 Medium Blog: [Insert Medium Article Link Here]

For a deep technical breakdown of the architecture, OAuth flow, reactive design, and implementation details, see:

📄 Technical Documentation:TECHNICAL_DETAILS.md

## Features

- **Interactive Dashboard**: View key metrics and visualizations in a clean, modern interface
- **Real-time Data**: Fetch current data from any subreddit using Reddit's API
- **Multiple Visualizations**:
  - Post scores over time
  - Comments vs. Score scatter plot
  - Posts by hour distribution
  - Top authors analysis
  - Score distribution
- **Data Table**: Detailed view of all fetched posts with sorting and filtering capabilities
- **Customizable Parameters**:
  - Subreddit selection
  - Time filter (day, week, month, year, all time)
  - Number of posts to fetch

## Prerequisites

- R (version 4.0.0 or higher)
- RStudio (recommended)
- Reddit API credentials (client ID and client secret)

## Required R Packages

```R
install.packages(c(
  "shiny",
  "httr",
  "jsonlite",
  "ggplot2",
  "dplyr",
  "lubridate",
  "shinydashboard",
  "DT"
))
```

## Setup

1. Clone this repository
2. Open `Reddit Dashboard.R` in RStudio
3. Replace the API credentials in the code with your own:
   ```R
   client_id <- "your_client_id"
   client_secret <- "your_client_secret"
   ```
4. Run the application

## Usage

1. Launch the application
2. Enter a subreddit name in the sidebar
3. Select your desired time filter and number of posts
4. Click "Fetch Data" to retrieve and visualize the data
5. Explore different tabs to view various visualizations and the data table

## API Credentials

To get Reddit API credentials:

1. Go to https://www.reddit.com/prefs/apps
2. Click "create another app..."
3. Select "script"
4. Fill in the required information
5. Copy the client ID and client secret

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Reddit API for providing the data
- R Shiny team for the amazing framework
- All contributors and users of this dashboard 
