# Azure DevOps Personal Access Token Setup

## ⚡ Quick Setup (5 minutes)

### Step 1: Create PAT in Azure DevOps

1. **Navigate to:** https://siepe.visualstudio.com/_usersSettings/tokens
   (Or click your profile icon → Security → Personal access tokens)

2. **Click:** "+ New Token"

3. **Configure:**
   - **Name:** `GitHub Actions - Mossy Agent`
   - **Organization:** All accessible organizations (or select Siepe)
   - **Expiration:** 90 days (recommended) or custom
   - **Scopes:** Click "Show all scopes" and select:
     - ✅ Work Items: **Read**
     - ✅ Work Items: **Write**
     - ✅ Code: **Read** (optional)

4. **Click:** "Create"

5. **⚠️ COPY THE TOKEN IMMEDIATELY!**
   - It looks like: `ab1cd2ef3gh4ij5kl6mn7op8qr9st0uv1wx2yz3ab4cd5ef6gh7`
   - You won't see it again!
   - Paste it somewhere temporarily (Notepad)

---

### Step 2: Add PAT to GitHub Secrets

1. **Navigate to:** https://github.com/Tayzer9266/siepe/settings/secrets/actions

2. **Click:** "New repository secret"

3. **Enter:**
   - **Name:** `AZURE_DEVOPS_PAT` (exact spelling!)
   - **Secret:** Paste the PAT token you copied

4. **Click:** "Add secret"

---

### Step 3: Test the Workflow

1. **Navigate to:** https://github.com/Tayzer9266/siepe/actions

2. **Click:** "Mossy Automated Review Agent" (left sidebar)

3. **Click:** "Run workflow" button (top right)

4. **Configure:**
   - Branch: `main`
   - Max tickets: `1`
   - Dry run: `true` ✅ (safe test - won't post to ADO)

5. **Click:** "Run workflow"

6. **Wait 2-3 minutes** - workflow will show:
   - 🟡 Yellow spinner = Running
   - ✅ Green check = Success!
   - ❌ Red X = Failed (check logs)

---

## ✅ Success Checklist

- [ ] PAT created in Azure DevOps
- [ ] PAT added to GitHub Secrets as `AZURE_DEVOPS_PAT`
- [ ] Workflow runs without errors
- [ ] Investigation report generated in artifacts
- [ ] Ready for automated 24/7 monitoring!

---

## 🆘 Troubleshooting

### "Authentication failed"
- PAT expired or invalid
- Create new PAT with correct scopes
- Update GitHub secret

### "Cannot find secret AZURE_DEVOPS_PAT"
- Secret name must be exactly: `AZURE_DEVOPS_PAT`
- Check for typos
- Secret must be in repository secrets (not environment secrets)

### "No work items found"
- This is normal if no tickets are tagged "Mossy Review"
- Workflow still succeeded!

---

## 🔄 When Will It Run?

**Automatic Schedule:** Every 6 hours
- 12:00 AM UTC (7:00 PM EST)
- 6:00 AM UTC (1:00 AM EST)
- 12:00 PM UTC (7:00 AM EST)
- 6:00 PM UTC (1:00 PM EST)

**Manual Trigger:** Anytime via "Run workflow" button

---

## 💰 Cost

**GitHub Actions:** FREE
- 2,000 minutes/month for private repos
- Each run takes ~2-5 minutes
- ~400 runs per month = FREE!

**Claude API:** ~$0.01 per investigation
- Budget: $5-10/month for 100-500 tickets

**Total:** $5-10/month for fully automated monitoring

---

## 🎯 Alternative: Skip PAT and Use Local Only

**Don't want to set up PAT?** No problem!

You can use Mossy locally without GitHub Actions:
```powershell
cd c:\source\MD\AdminTools\.github\skills\ado-mossy-review
.\Quick-Check-MossyReview.ps1
```

**Benefits:**
- ✅ No PAT needed
- ✅ Uses your existing Azure CLI login
- ✅ Full database access
- ✅ Completely FREE

**Trade-off:**
- Must run manually (not automated 24/7)
