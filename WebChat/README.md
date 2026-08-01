# MOS Support Agent - Web Chat Testing Interface

A standalone web chat interface for testing and developing MOS Support Agent skills interactively.

## Features

- 🎨 **Beautiful Chat UI** - Modern, responsive design
- 🤖 **Agent Integration** - Routes messages to appropriate skills
- 📊 **Skill Routing** - Automatic keyword-based routing with confidence scoring
- 🔍 **Testing Console** - Test skills without ADO integration
- ⚡ **Quick Actions** - Pre-configured common queries
- 📝 **Markdown Support** - Code blocks, formatting in responses

## Quick Start

### 1. Install Dependencies

```powershell
cd C:\source\MD\AdminTools\WebChat
npm install
```

### 2. Start the Backend Server

```powershell
node server.js
```

You should see:
```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║       MOS Support Agent - Test Console Backend           ║
║                                                           ║
║  Server running on: http://localhost:3000                ║
║  Web UI available at: WebChat/index.html                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

### 3. Open the Web Chat

Open `index.html` in your browser:
```powershell
# Using default browser
start index.html

# Or directly in Chrome
start chrome index.html
```

## Usage

### Testing Skills

Try these example queries:

**Market Pricing:**
- "investigate ticket #82115"
- "check market price for CUSIP 83408EAA1"
- "pricing issue for Aristotle on 2026-06-30"

**Bulk Price Validation:**
- "bulk price validation"
- "compare prices across multiple securities"
- "price exception review"

**SSIS Errors:**
- "analyze SSIS error"
- "PowerShell script failure"
- "package pInstFundValueI failed"

**General:**
- "list skills" - See all available skills
- "help" - Get help and examples

### Quick Action Buttons

Click the quick action buttons at the top for common queries:
- 🔍 Investigate Ticket
- 💰 Check Pricing
- ⚙️ SSIS Error
- 📊 Bulk Validation
- 📚 List Skills

## Architecture

```
┌─────────────────┐
│   Web Browser   │
│   (index.html)  │
└────────┬────────┘
         │ HTTP POST
         │ /api/agent
         ▼
┌─────────────────┐
│   Node.js       │
│   (server.js)   │
│                 │
│ • Route message │
│ • Match skills  │
│ • Execute logic │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  Skills Library         │
│  .github/skills/        │
│                         │
│  • check-market-price   │
│  • bulk-price-validation│
│  • check-ssis-errors    │
│  • price-overrides      │
│  • remove-dashboard...  │
└─────────────────────────┘
```

## Skill Routing

The backend uses keyword-based routing from `MOSSupportTaskTaxonomy.md`:

| Keywords | Skill | Confidence |
|----------|-------|-----------|
| price, pricing, markit, lseg | check-market-price | 85% |
| bulk, price exception | bulk-price-validation | 80% |
| ssis, powershell, etl | check-ssis-errors | 80% |
| override, manual price | price-overrides | 85% |
| dashboard, remove report | remove-process-dashboard-reports | 75% |

## Development

### Adding New Skills

1. Create skill in `.github/skills/[skill-name]/SKILL.md`
2. Add routing rule to `server.js`:

```javascript
{
    keywords: ['your', 'keywords'],
    skill: 'skill-name',
    confidence: 0.80,
    category: 'Category Name'
}
```

3. Test in web chat

### Customizing UI

Edit `index.html`:
- **Colors:** Modify gradient colors in CSS
- **Quick Actions:** Add buttons in `.quick-actions` section
- **Styling:** Update styles in `<style>` block

### Enhanced Backend Integration

Future enhancements:
- Execute actual PowerShell scripts
- Query databases directly
- Generate investigation reports
- Post results to ADO tickets

## Troubleshooting

### Backend Not Starting

**Error:** `Cannot find module 'express'`
```powershell
npm install
```

### Connection Failed

**Error:** "Backend offline"
- Ensure server is running: `node server.js`
- Check port 3000 is available
- Verify `API_URL` in index.html matches server port

### Skills Not Found

**Error:** "Skill not yet available"
- Check skill exists in `.github/skills/[skill-name]/SKILL.md`
- Verify skill path in server.js `SKILLS_PATH`
- Review skill status (Production Ready vs. In Development)

## Files

```
WebChat/
├── index.html          # Web chat UI
├── server.js           # Backend API server
├── package.json        # Node.js dependencies
└── README.md           # This file
```

## Next Steps

### Integration Enhancements

1. **PowerShell Execution**
   - Execute actual skill workflows
   - Run database queries
   - Generate real investigation reports

2. **ADO Integration**
   - Fetch ticket details via Azure CLI
   - Post results to ticket discussion
   - Attach generated reports

3. **Database Connectivity**
   - Query MOS production databases
   - Execute stored procedures
   - Return real data in responses

4. **Authentication**
   - Add user login
   - Validate database permissions
   - Track usage metrics

5. **Advanced Features**
   - Upload Excel files for bulk validation
   - Real-time query results
   - Syntax highlighting for SQL
   - Export investigation reports

## Support

For issues or questions:
- Review skill documentation in `.github/skills/`
- Check `MOSSupportTaskTaxonomy.md` for routing rules
- See `MOSBackOfficeSupport.md` for agent workflow

---

**Status:** ✅ Ready for Testing  
**Version:** 1.0  
**Last Updated:** 2026-07-13
