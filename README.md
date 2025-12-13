# Power Operations App

A Flutter application for visualizing power operations data with charts, connecting to MS SQL Server through a thin Dart API layer.

## Features

- 📊 **Real-time Charts** - Line, bar, and pie charts for power data visualization
- ⚡ **Fast Data Loading** - Optimized pagination, caching, and parallel data fetching
- 📱 **Multi-Platform** - Supports Web, Android, iOS, and Windows
- 🔄 **Auto-Refresh** - Configurable auto-refresh for real-time data
- 📈 **Dashboard** - Overview of power statistics and latest readings
- 🔍 **Filtering** - Filter data by station, date range, and more

## Project Structure

```
power_operations_app/
├── lib/                          # Flutter Frontend
│   ├── core/                     # Core utilities
│   │   ├── config/               # API configuration
│   │   ├── constants/            # App constants
│   │   └── theme/                # App theme
│   ├── data/                     # Data layer
│   │   └── models/               # Data models
│   ├── providers/                # State management
│   ├── services/                 # API services
│   │   └── api/                  # HTTP client & services
│   └── ui/                       # UI layer
│       ├── screens/              # App screens
│       └── widgets/              # Reusable widgets
│           ├── charts/           # Chart widgets
│           └── common/           # Common widgets
├── backend/                      # Dart Backend API
│   ├── bin/                      # Server entry point
│   ├── lib/                      # Backend logic
│   │   ├── config/               # Database configuration
│   │   ├── repositories/         # Data access layer
│   │   ├── routes/               # API routes
│   │   └── services/             # Business logic
│   └── sql/                      # SQL scripts
└── README.md
```

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- MS SQL Server (2016+)

### 1. Setup Database

1. Create a new database in MS SQL Server
2. Run the SQL script to create tables: `backend/sql/create_tables.sql`
3. (Optional) Insert sample data:
```sql
EXEC sp_InsertSamplePowerData @NumRecords = 5000;
```

### 2. Configure Backend

```bash
cd power_operations_app/backend
copy .env.example .env
# Edit .env with your database credentials
dart pub get
dart run bin/server.dart
```

### 3. Run Frontend

```bash
cd power_operations_app
flutter pub get
flutter run -d chrome   # For Web
flutter run -d windows  # For Windows
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/api/power-data` | Get paginated power data |
| `/api/power-data/latest` | Get latest power readings |
| `/api/chart-data` | Get chart visualization data |
| `/api/dashboard` | Get dashboard summary |

## Performance Optimizations

- **Pagination** - All list data is paginated
- **Caching** - GET requests cached for 5 minutes
- **Parallel Loading** - Multiple requests in parallel
- **Request Cancellation** - Cancelled when new requests made
- **Indexed Database** - SQL indexes on frequent columns
