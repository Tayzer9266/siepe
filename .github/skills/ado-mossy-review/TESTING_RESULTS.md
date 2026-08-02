# Mossy Automated Review - Testing Results

## Final Configuration (August 2, 2026)

### ✅ Working Setup

**Model:** `claude-opus-5` (Claude 5 generation)  
**API Key:** Company account (ANTHROPIC_API_KEY_BU GitHub Secret)  
**Cost:** Billed to company Anthropic account

### Test Results

#### Local Testing
- ✅ Company API key works with `claude-opus-5`
- ✅ Generated 3264 character investigation report for ticket #85713
- ✅ Response parsing handles "thinking" + "text" blocks correctly

#### GitHub Actions Testing  
- ✅ Run #28: SUCCESS with personal API key
- 🔄 Testing company API key next...

### Key Learnings

1. **Model Naming Issue**: The account has access to Claude 4.x/5.x models (not 3.x)
   - ❌ `claude-3-5-sonnet-20240620` → 404 Not Found
   - ✅ `claude-opus-5` → SUCCESS!

2. **API Key Issues**: Both keys were always valid - just needed correct model name

3. **Response Format**: Claude Opus 5 returns thinking block first, then text block
   - Fixed by filtering for `content[].type == "text"`

### Automation Schedule

**Runs every 6 hours:** 00:00, 06:00, 12:00, 18:00 UTC  
**Manual trigger:** Available via GitHub Actions UI  
**Next scheduled run:** Check GitHub Actions page
