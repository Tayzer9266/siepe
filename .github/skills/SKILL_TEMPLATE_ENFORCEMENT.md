# Enforcement Template for All MOS Support Skills

## Standard Section to Add to Every Skill

Add this section after the main workflow steps and before "Important Notes":

---

## Agent Enforcement (When Invoked for ADO Tickets)

**⚠️ MANDATORY when MOS Support Agent processes this skill for a ticket:**

### Detection Logic
```powershell
# Skill determines if invoked by agent for a ticket
$isTaskMode = $env:MOS_TASK_ID -or $args -contains "-TicketID"
```

### If Task Mode Detected:

1. **Generate Markdown Report** (as documented above)
2. **Attach Report to ADO Ticket:**
   ```powershell
   # Use direct REST API method (from MOSSupport.agent.md)
   $token = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 | ConvertFrom-Json).accessToken
   $uploadUrl = "https://siepe.visualstudio.com/_apis/wit/attachments?fileName=$fileName&api-version=7.0"
   $uploadHeaders = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/octet-stream" }
   $fileBytes = [System.IO.File]::ReadAllBytes($reportPath)
   $uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -Body $fileBytes
   $attachmentUrl = $uploadResponse.url
   
   $workItemUrl = "https://siepe.visualstudio.com/_apis/wit/workitems/$ticketId`?api-version=7.0"
   $patchHeaders = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json-patch+json" }
   $patchBody = "[{`"op`":`"add`",`"path`":`"/relations/-`",`"value`":{`"rel`":`"AttachedFile`",`"url`":`"$attachmentUrl`",`"attributes`":{`"comment`":`"{SkillName} investigation report`"}}}]"
   Invoke-RestMethod -Uri $workItemUrl -Method Patch -Headers $patchHeaders -Body $patchBody
   ```

3. **Post Summary Comment:**
   ```powershell
   $comment = @"
### ✅ {Skill Name} Complete

**Summary:** {One-line summary}

**📄 Detailed Report:** ``$fileName`` (attached)

**Next Steps:**
1. Review attached report
2. {Specific action}

**Questions?** Contact the Back Office SQL Engineers team.
"@
   
   az boards work-item update --id $ticketId --org "https://siepe.visualstudio.com/" --discussion "$comment"
   ```

### If Query Mode (No Ticket):

1. **Generate Markdown Report** (as documented above)
2. **Display findings to user**
3. **Inform:** "Report saved to Output/{FileName}.md"
4. **No ADO operations performed**

---

## How This Enforces Attachment

1. **Agent Detection:** MOS Support Agent sets `$env:MOS_TASK_ID` when processing tickets
2. **Skill Responsibility:** Each skill checks for this variable and enforces attachment in Task Mode
3. **Automatic Fallback:** If variable not set, skill operates in Query Mode (local report only)
4. **Clear Indication:** Mode displayed at start: `[TASK MODE: #82115]` or `[QUERY MODE]`

---

## Integration with Skills

Each skill should include this conditional logic in their output generation section:

```markdown
### Step N: Generate and Attach Report

**Determine Mode:**
- If `$env:MOS_TASK_ID` is set → TASK MODE (attach to ticket)
- If not set → QUERY MODE (local report only)

**TASK MODE Steps:**
1. Generate markdown report
2. Attach to ticket (MANDATORY)
3. Post summary comment
4. Display confirmation

**QUERY MODE Steps:**
1. Generate markdown report
2. Display findings
3. Inform user of report location
```

---

## Verification

**After implementing this in a skill:**

1. Test TASK MODE: `@MOS Support Agent TASK 82115`
   - ✅ Report generated
   - ✅ File attached to ticket
   - ✅ Comment posted
   
2. Test QUERY MODE: `@MOS Support Agent why is price wrong for CUSIP 12345?`
   - ✅ Report generated locally
   - ✅ Findings displayed
   - ❌ No ADO operations

---

**This template ensures:**
- ✅ Attachment ONLY when processing actual tickets
- ✅ No attachment burden for ad-hoc queries
- ✅ Consistent behavior across all skills
- ✅ Clear mode indication to users
