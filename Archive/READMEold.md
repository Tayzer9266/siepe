# AdminTools - Administrative Application

## Overview

AdminTools is an enterprise administrative application for the Siepe financial platform, providing system administrators with comprehensive tools to manage data, configurations, integrations, and monitoring across the platform.

**Location**: `Applications/AdminTools/`

**Technology Stack**:
- **Backend**: ASP.NET MVC with C# (.NET Framework)
- **Frontend**: AngularJS 1.6 with Bootstrap
- **UI Components**: Kendo UI grids and widgets
- **Data Access**: Custom DBUtility layer
- **Build**: Webpack bundling
- **Styling**: Dark theme support

---

## 📚 MOS Operations Documentation

This repository contains comprehensive documentation for MOS (Management Operating System) operations and the proposed transformation initiative:

### Strategic Documents

| Document | Purpose | Audience |
|----------|---------|----------|
| **[MOS Transformation Proposal (Executive)](./MOS-Transformation-Proposal-Executive.md)** | **Executive pitch for $626K AdminTools enhancement initiative** | **Leadership, Stakeholders** |
| [MOS Support Enhancement Plan](./MOS-Support-Enhancement-Plan.md) | Detailed 4-phase technical roadmap for enhancements | Product Managers, Architects |
| [MOS Back Office Backlog Analysis](./MOS-BackOffice-Backlog-Analysis.md) | Automation opportunities and ROI analysis | Operations Managers, Business Analysts |

### Operational Documents

| Document | Purpose | Audience |
|----------|---------|----------|
| [MOS Support Role Documentation](./MOS-Support-Role.md) | Complete guide to MOS Support operations with diagrams and layman explanations | MOS Support Team, New Hires, Business Users |
| [MOS Client Support Issues Summary](./MOS-Client-Support-Issues-Summary.md) | Catalog of 33+ documented operational issues and resolutions | MOS Support Team, Developers |
| [MOS Database Schema](./MOS-Database-Schema.md) | Production database schema (Core & Reference) | Developers, Data Analysts |
| [MOS System Connections Reference](./MOS-System-Connections-Reference.md) | Connection strings, URLs, Azure DevOps, MCP configurations | Developers, DevOps, Integrations |

### Quick Links

- 🎯 **[Start Here: Executive Proposal](./MOS-Transformation-Proposal-Executive.md)** - If you're evaluating the initiative
- 📊 **[Power BI Metrics](./MOS-Support-Role.md#power-bi-metrics-for-mos-operations-dashboard)** - Dashboard specifications and KPIs
- 🔍 **[SQL Queries](./MOS-BackOffice-Backlog-Analysis.md#appendix-a-sql-script-library-for-quick-implementation)** - Production-ready queries for dashboards
- 🔗 **[Database Connections](./MOS-System-Connections-Reference.md#-mos-production-database)** - Connection strings and setup

---

## Feature Areas

### 1. Authorization & Security

**Purpose**: Manage user access, permissions, and security settings

#### Authorization
- User and group management
- Permission administration
- Role-based access control

#### Key Management
- Encryption key management
- Security credential storage
- Certificate management

---

### 2. Data Management

**Purpose**: Maintain data quality, integrity, and perform administrative database operations

#### Data Integrity
- Test result history tracking
- Data quality monitoring
- Validation rule execution
- Historical test result viewing

#### Data Maintenance
- Data cleanup utilities
- Report dashboards
- Data integrity reports
- Maintenance task scheduling

#### Dataset Expected
- Expected dataset configuration
- Data validation rules
- Dataset expectation management

#### Raw Data Sets
- Raw data viewing and browsing
- Data inspection tools
- Historical data access

#### Database Admin
- Direct database administration
- Schema management
- Database maintenance operations

#### Query Runner
- SQL query execution interface
- Ad-hoc query capability
- Query result export
- Query history

---

### 3. Configuration Management

**Purpose**: Configure and manage system settings, integrations, and data processing rules

#### Configuration Editor
Multi-purpose configuration interface with specialized editors:
- **Delivery Configuration**: Configure data delivery settings
- **Message Aggregation**: Message processing and aggregation rules
- **Position Reconciliation**: Position rec configuration
- **Reconciliation Data Sources**: Data source mappings for reconciliation

#### Data Source Editor
- Configure data sources
- Manage datasource connections
- Edit datasource metadata
- Connection testing

#### Generic Normalization
- Data normalization rule configuration
- Field mapping definitions
- Transformation rules

---

### 4. Import/Export Tools

**Purpose**: Move data in and out of the system

#### Generic Import
- Configurable data import system
- Template-based imports
- Import history tracking
- Error handling and validation

#### Exporter
- Export data to multiple formats
- Excel export capabilities
- Scheduled exports
- Custom export templates

#### File Management
Comprehensive file management with remote access:
- **Remote Session Management**: SFTP/FTP session handling
- **File Upload/Download**: Transfer files to/from remote servers
- **File Content Viewer**: Preview file contents
- **Remote Configurations**: Manage remote connection settings
- **File Object Grid**: Browse and manage remote files

---

### 5. Integration & Messaging

**Purpose**: Manage external integrations and message flows

#### Bloomberg Jobs
- Bloomberg data feed management
- Job scheduling and monitoring
- Bloomberg service configuration
- Feed status tracking

#### Email Adapter
Email system integration and management:
- **Mailbox Configuration**: Email account setup
- **Sender Management**: Configure email senders
- **Message Templates**: Email template management
- **Email Monitoring**: Track sent/received emails

#### Script Adapter
- Script execution management
- Script configuration
- Execution history
- Grid history viewing

#### PubSub (RabbitMQ)
Message queue management:
- **Subscription Management**: Create/edit subscriptions
- **Message Publishing**: Send PubSub messages
- **Published Messages**: View message history
- **Subscription Logging**: Monitor subscription activity
- **Topic Management**: Manage message topics

#### AWS
- AWS service integration
- S3 bucket management
- AWS resource configuration

---

### 6. Reporting

**Purpose**: Create, manage, and deliver reports

#### Reports
Comprehensive reporting system:
- **Data Workbench**: Interactive data analysis
- **Report Editor**: Visual report designer
- **Report Viewer**: View and export reports
- **Dynamic Reports**: Configurable dynamic reports
- **Dynamic Report Type Editor**: Define custom report types

#### Report Subscription
Automated report delivery system:
- **Subscription Management**: Schedule report delivery
- **Template Editor**: Create static and dynamic templates
- **Administration Interface**: Manage subscriptions globally
- **Subscription Logs**: Track delivery history
- **Import/Export**: Bulk subscription management
- **CRON Schedule Configuration**: Advanced scheduling
- **Token Validation**: Template token management
- **Delivery Configuration**: Email/file delivery settings

---

### 7. Financial Operations

**Purpose**: Manage position splits, reconciliation, and performance analysis

#### Split Positions
Position splitting and mapping for financial instruments:
- **Trade Split Mapping**: Configure trade splits
- **Position Split Mapping**: Map split positions
- **Split History**: Track historical splits
- **P&L Recalculation**: Recalculate profit/loss after splits
- **Split Trade Summary**: View trade split summaries
- **End Split Position Mapping**: Close split configurations

#### Reconciliation
Position reconciliation tools:
- **Single Source Debug**: Debug reconciliation issues
- **Comparison Fields**: Configure comparison criteria
- **Position Rec**: Reconciliation execution

#### Instrument Arbitration
- Instrument identifier management
- Identifier resolution and mapping
- Multi-source instrument matching
- Identifier validation

#### PPA (Performance & Attribution)
- Performance monitoring
- Attribution analysis
- Threshold configuration
- Performance reporting

---

### 8. Workflow & Monitoring

**Purpose**: Orchestrate batch processes and monitor system operations

#### Choreographer
Batch process orchestration:
- **Batch List**: View all batch processes
- **Batch Details**: Detailed batch information
- **Workflow Management**: Configure process workflows
- **Dependency Management**: Define process dependencies
- **Execution Monitoring**: Real-time batch tracking

#### Process Dashboard
- Real-time process monitoring
- Process status overview
- Performance metrics
- Historical process data

#### Regression Test
Quality assurance and testing:
- **Planned Outages**: Schedule and track outages
- **Heat Maps**: Visual test result analysis
- **Test History**: Historical test results
- **Test Configuration**: Define regression tests

---

### 9. System Administration

**Purpose**: System-level administration and monitoring

#### Logging
System log viewing and analysis:
- **SQL Logging**: Database query logging
- **Logbook Entries**: System event logging
- **Log Filtering**: Advanced log search
- **Log Export**: Export log data

#### Calendars
- Business calendar management
- Calendar editor
- Holiday configuration
- Trading day definitions

#### Mapping
- **Employee-Company Mapping**: Map employees to companies
- Relationship management
- View by employee or company

#### WSO Reporting
Wholesale Services Operations reporting:
- **On-Demand Reporting**: Generate reports on request
- **Bulk Download**: Download multiple reports
- **Request Information**: Track WSO requests
- **Report Groups**: Organize WSO reports

---

## Application Structure

```
AdminTools/
├── Data/                          # Data access layer
├── Models/                        # Domain models
│   ├── Admin/
│   ├── Administrator/
│   ├── Application/
│   ├── DeliveryConfiguration/
│   ├── Employee/
│   ├── Grid/
│   ├── Logging/
│   ├── Menu/
│   ├── Page/
│   ├── PubSub/
│   └── WsoReport/
├── Services/                      # Business logic services
│   ├── Application/
│   ├── BloombergJobs/
│   ├── Employee/
│   ├── Page/
│   ├── PubSub/
│   ├── Search/
│   ├── User/
│   └── WsoReport/
├── Test/                          # Unit tests
└── Web/                           # Web application
    ├── Areas/                     # MVC Areas (feature modules)
    │   ├── Authorization/
    │   ├── Aws/
    │   ├── BloombergJobs/
    │   ├── Calendars/
    │   ├── Choreographer/
    │   ├── ConfigurationEditor/
    │   ├── DatabaseAdmin/
    │   ├── DataIntegrity/
    │   ├── DataMaintenance/
    │   ├── DatasetExpected/
    │   ├── DataSourceEditor/
    │   ├── EmailAdapter/
    │   ├── Exporter/
    │   ├── FileManagement/
    │   ├── GenericImport/
    │   ├── GenericNormalization/
    │   ├── Home/
    │   ├── InstrumentArbitration/
    │   ├── KeyManagement/
    │   ├── Logging/
    │   ├── Mapping/
    │   ├── PPA/
    │   ├── ProcessDashboard/
    │   ├── PubSub/
    │   ├── QueryRunner/
    │   ├── RawDataSets/
    │   ├── Reconciliation/
    │   ├── RegressionTest/
    │   ├── Report/
    │   ├── ReportSubscription/
    │   ├── ScriptAdapter/
    │   ├── SplitPositions/
    │   └── WSOReporting/
    ├── js-npm/                    # Frontend JavaScript (npm packages)
    │   ├── parsley/              # Form validation
    │   └── siepe.queryBuilder/   # Query builder component
    └── client-specific/           # Client-specific customizations
```

---

## Key Dependencies

### NPM Packages
- **@progress/kendo-ui**: UI components and grids
- **@siepe/angular-utils**: Siepe utility libraries
- **@siepe/dynamic-reports**: Dynamic reporting framework
- **@siepe/expression-builder**: Expression builder component
- **@siepe/siepe-kendo**: Kendo UI wrappers
- **angular**: AngularJS framework (1.6.x)
- **@uirouter/angularjs**: UI routing
- **angular-ui-bootstrap**: Bootstrap components
- **angular-toastr**: Notification system
- **angular-schema-form**: Form generation

### Build Tools
- **webpack**: Module bundling
- **babel**: JavaScript transpilation
- **eslint**: Code linting
- **lodash-webpack-plugin**: Optimization

---

## Common Use Cases

### For System Administrators
1. **User Management**: Use Authorization to manage users and permissions
2. **Data Quality**: Use Data Integrity to monitor and fix data issues
3. **System Monitoring**: Use Process Dashboard and Logging to track system health
4. **Configuration Changes**: Use Configuration Editor to modify system settings

### For Data Managers
1. **Import Data**: Use Generic Import to load external data
2. **Data Cleanup**: Use Data Maintenance to fix data issues
3. **Query Data**: Use Query Runner for ad-hoc queries
4. **Export Reports**: Use Report Subscription to schedule regular reports

### For Integration Managers
1. **Bloomberg Setup**: Use Bloomberg Jobs to manage market data feeds
2. **Email Configuration**: Use Email Adapter to configure email integrations
3. **Message Queue**: Use PubSub to manage RabbitMQ subscriptions
4. **File Transfers**: Use File Management for SFTP/FTP operations

### For Operations Teams
1. **Batch Monitoring**: Use Choreographer to track batch processes
2. **Process Status**: Use Process Dashboard for real-time monitoring
3. **Issue Investigation**: Use Logging to diagnose problems
4. **Report Delivery**: Use Report Subscription to deliver reports

---

## Authentication & Authorization

AdminTools supports multiple authentication modes configured via `AppSettings.AuthenticationMode`:
- **AzureSSO**: Azure Active Directory
- **Saml2**: SAML 2.0 federation
- **Forms**: Forms-based authentication
- **Windows**: Windows integrated authentication
- **Bearer**: Token-based authentication

Permissions are managed through:
- **SQL Authorization**: Database-driven permissions
- **Application Roles**: Claims-based permissions
- **Auth Policies**: Pre-configured policy sets

---

## Development Notes

### Build Commands
```bash
# Frontend
cd Applications/AdminTools/Web
npm install
npm run start              # Webpack build

# Backend
cd Applications/AdminTools
dotnet build AdminTools.sln
```

### Coding Standards
- **C# Indentation**: Tabs
- **Braces**: Allman style (opening brace on new line)
- **Private fields**: `_camelCase` with underscore prefix
- **ID fields**: Use `long` for all database IDs

### Architecture Patterns
- **MVC Areas**: Each feature is a separate Area
- **DBUtility**: Custom data access layer with stored procedures
- **AngularJS Components**: Component-based UI architecture
- **Dependency Injection**: Unity container for backend, Angular DI for frontend

---

## Related Documentation

- Main repository CLAUDE.md: `c:\source\Git.Trunk\CLAUDE.md`
- Portal.Core (primary application): `Applications/Portal.Core/CLAUDE.md`
- Microservice templates: `Microservices/SiepeMinimalApiTemplate/`

---

## Summary

AdminTools serves as the **centralized administrative hub** for the Siepe financial platform, providing:

✅ **Complete system configuration** across all modules  
✅ **Data integrity and quality management** tools  
✅ **Integration management** for external systems  
✅ **Report creation and delivery** automation  
✅ **Financial operations support** (splits, reconciliation, performance)  
✅ **System monitoring and logging** capabilities  
✅ **User and permission management**  

It's designed for system administrators, data managers, and operations teams who need powerful tools to maintain and monitor the Siepe platform.



