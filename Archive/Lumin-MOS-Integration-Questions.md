# Lumin + MOS Support Agent Integration - Questions for Lead Engineer

**Created:** 2026-07-06  
**Purpose:** Critical questions for integrating MOS Support Agent into Lumin (main company agent)  
**Stakeholders:** Lead Engineer, MOS Support Team, Lumin Development Team  
**Related:** MOSBackOfficeSupport.md, MOSSupport.agent.md

---

## Executive Summary

The MOS Support Agent currently operates as a standalone specialized agent for investigating MOS database issues, pricing discrepancies, cash reconciliation, and SSIS errors. It has proven capabilities including:
- Automatic ADO ticket investigation and commenting
- Confidence-based routing using taxonomy
- Multi-database query capabilities
- Structured output generation

**Goal:** Integrate MOS Support Agent into Lumin as a specialized sub-agent or skill set while maintaining its effectiveness and automation capabilities.

---

## 🎯 Integration Architecture Questions

### 1. **Agent Hierarchy & Invocation**

**Q1.1:** How does Lumin support sub-agents or specialized agents?

**Q1.2:** Does Lumin use a routing/orchestration pattern to delegate to specialized agents?

**Q1.3:** Should MOS Support Agent be integrated as a:
- [ ] **Sub-agent** that Lumin invokes via API/tool call?
- [ ] **Skill set** that gets merged into Lumin's capabilities?
- [ ] **Plugin/Extension** that registers itself with Lumin?
- [ ] **Other:** _________________________________

**Q1.4:** Can Lumin maintain separate agent contexts for specialized domains?

---

### 2. **Trigger & Routing Logic**

**Q2.1:** How should Lumin determine when to invoke MOS Support Agent vs. handling requests itself?

**Q2.2:** Which routing approach should we use:
- [ ] **Keyword matching** (e.g., "pricing", "MOS", "cash reconciliation", "SSIS", "Solvas")
- [ ] **Intent classification** (ML model or rule-based)
- [ ] **Explicit mention** (e.g., `@MOS Support Agent`)
- [ ] **ADO ticket metadata** (ticket type, tags, area path, custom fields)
- [ ] **Hybrid approach** (combination of above)

**Q2.3:** Can Lumin use the existing `MOSSupportTaskTaxonomy.md` confidence scoring system?
- Current system scores matches 0-100% and logs tickets with <70% confidence
- Should this be incorporated into Lumin's routing logic?

**Q2.4:** What happens when multiple specialized agents could handle a request?
- Priority system?
- Ask user for clarification?
- Invoke all and aggregate results?

**Q2.5:** Should there be a manual override to force Lumin to use MOS Support Agent?

---

### 3. **Context & State Management**

**Q3.1:** How does context get passed from Lumin to MOS Support Agent?
- Required context: Ticket number, description, user info, conversation history, priority
- Format: JSON, structured object, plain text?

**Q3.2:** Does Lumin maintain conversational state across sub-agent calls?
- Can users ask follow-up questions to MOS Support Agent results?
- Does context persist across multiple invocations?

**Q3.3:** Should MOS Support Agent return:
- [ ] Structured data (JSON/XML) for Lumin to format
- [ ] Formatted markdown for direct display
- [ ] Both (structured + formatted)

**Q3.4:** How much of the conversation history should be shared with MOS Support Agent?
- Full conversation?
- Only relevant context?
- Summarized context?

**Q3.5:** Can Lumin inject additional context that MOS Support Agent should consider?
- User role/permissions
- Related tickets
- Recent system events

---

### 4. **Skill & Tool Registration**

**Q4.1:** How do we register the MOS Support Agent's skills with Lumin?

**Current MOS Skills:**
1. `check-market-price` - Pricing discrepancy investigation
2. `check-cash-reconciliation` - Cash balance mismatch analysis
3. `check-ssis-errors` - SSIS package failure debugging
4. `bulk-price-validation` - Bulk price exception validation

**Q4.2:** Does Lumin have a skill registry or discovery mechanism?
- Dynamic loading?
- Static configuration?
- Runtime registration?

**Q4.3:** Should skills be:
- [ ] Copied into Lumin's skill directory
- [ ] Referenced from MOS Support Agent's location
- [ ] Registered via API/manifest

**Q4.4:** Can skills have dependencies on specific tools or database connections?

**Q4.5:** How are skill conflicts resolved if Lumin and MOS both have similar capabilities?

---

### 5. **ADO Integration**

**Q5.1:** The MOS Support Agent **automatically posts results to ADO tickets**. Should:
- [ ] Lumin handle ADO posting (centralized approach)
- [ ] MOS Support Agent continue posting directly (specialized approach)
- [ ] Both post (Lumin posts summary + MOS posts detailed investigation)
- [ ] Configurable based on ticket type

**Q5.2:** Who manages Azure CLI authentication for ADO access?
- Lumin's service account?
- MOS Support Agent's service account?
- User's credentials?

**Q5.3:** Should Lumin be aware of ADO posting results?
- Success/failure notification
- Ability to retry failed posts
- Link to posted comment in response

**Q5.4:** Should ADO comments be tagged to indicate they came from Lumin → MOS Support Agent?
- Example: `[Lumin/MOS Support] Investigation Results...`

**Q5.5:** What ADO permissions are required?
- Read tickets
- Post comments
- Update work items
- Create work items

---

### 6. **Database Access & Permissions**

**MOS Support Agent currently queries:**
- `mos-sql-p.mos.siepe.local,52155` - Core, Feeds, Reference, Enterprise, Portal
- `SOLVAS-SQL-D.mos.siepe.local,52156` - Solvas_AM, Feeds

**Q6.1:** How does Lumin handle database credentials?
- [ ] Pass-through authentication (Windows Integrated)
- [ ] Service account per agent
- [ ] Credential vault integration (Azure Key Vault, HashiCorp Vault)
- [ ] Connection string configuration

**Q6.2:** Should MOS Support Agent:
- [ ] Use Lumin's database connections
- [ ] Maintain its own connections
- [ ] Request connection from Lumin per query

**Q6.3:** Are there query timeouts or resource limits?
- Max query duration?
- Max result set size?
- Concurrent query limits?

**Q6.4:** How do we handle connection failures or database unavailability?
- Retry logic?
- Fallback databases?
- Error reporting to user?

**Q6.5:** Should database access be audited?
- Who queried what and when?
- Sensitive data access logging?

---

### 7. **Response Format & UX**

**Q7.1:** When Lumin invokes MOS Support Agent, should the response:
- [ ] Be shown directly to the user (pass-through)
- [ ] Be summarized/reformatted by Lumin
- [ ] Include both Lumin's context and MOS's technical details
- [ ] Be interactive (allow drill-down)

**Q7.2:** Should MOS reports stay in markdown format or convert to:
- [ ] Keep markdown
- [ ] Convert to HTML
- [ ] Convert to plain text
- [ ] Adaptive Card / Teams card format
- [ ] Other: _________________________________

**Q7.3:** How should code blocks, SQL queries, and data tables be displayed?
- Syntax highlighting?
- Copy buttons?
- Collapsible sections?

**Q7.4:** Should visualizations be included?
- Charts for trends?
- Diagrams for system flows?
- Screenshots or links?

**Q7.5:** How should large result sets be handled?
- Pagination?
- Summary with "show more" option?
- Export to file?

---

### 8. **Configuration & Deployment**

**Q8.1:** Where should MOS Support Agent's configuration live?
- [ ] As part of Lumin's config
- [ ] Separate agent configuration file
- [ ] In `.agent.md` files (current structure)
- [ ] Database-driven configuration
- [ ] Environment variables

**Current MOS Configuration Structure:**
```
AdminTools/.github/
├── agents/
│   └── MOSSupport.agent.md
└── skills/
    ├── check-market-price/SKILL.md
    ├── check-cash-reconciliation/SKILL.md
    ├── check-ssis-errors/SKILL.md
    └── bulk-price-validation/SKILL.md
```

**Q8.2:** Should this structure be:
- [ ] Migrated to Lumin's structure
- [ ] Referenced from current location
- [ ] Duplicated with Lumin-specific overrides

**Q8.3:** How are configuration updates deployed?
- CI/CD pipeline?
- Manual deployment?
- Hot reload capability?

**Q8.4:** Are there environment-specific configurations?
- Development vs. Production
- Different database connections
- Different ADO projects

**Q8.5:** How do we version the integration?
- Separate versioning for Lumin and MOS Support Agent?
- Unified versioning?
- Compatibility matrix?

---

### 9. **Monitoring & Logging**

**Q9.1:** Should MOS Support Agent executions be logged:
- [ ] In Lumin's logs only
- [ ] Separately for MOS-specific analytics
- [ ] In both places (correlated by request ID)

**Q9.2:** What metrics should be tracked?

| Metric | Captured By | Purpose |
|--------|-------------|---------|
| Invocation count | ? | Volume tracking |
| Confidence scores | ? | Routing accuracy |
| Resolution time | ? | Performance monitoring |
| ADO ticket updates | ? | Automation success rate |
| Database query performance | ? | Resource optimization |
| Error rate | ? | Reliability tracking |
| User satisfaction | ? | Quality assessment |

**Q9.3:** Where should logs be stored?
- Centralized logging system (e.g., Seq, Splunk, ELK)?
- SQL Server tables?
- File system?

**Q9.4:** What log levels are appropriate?
- DEBUG: SQL queries, configuration lookups
- INFO: Agent invocations, skill executions
- WARN: Low confidence routing, retries
- ERROR: Failures, exceptions

**Q9.5:** Should there be real-time monitoring/alerting?
- Agent failure alerts
- Performance degradation alerts
- Unusual activity alerts

---

### 10. **Error Handling & Fallback**

**Q10.1:** If MOS Support Agent fails, should Lumin:
- [ ] Retry with different parameters
- [ ] Fall back to general support response
- [ ] Escalate to human immediately
- [ ] Log error and continue with best effort
- [ ] Ask user for more context

**Q10.2:** What constitutes a "failure"?
- Agent timeout?
- Database connection failure?
- No results found?
- Low confidence score?
- Exception/error?

**Q10.3:** Should there be graceful degradation?
- Partial results better than no results?
- Summary instead of detailed investigation?

**Q10.4:** How should transient vs. permanent failures be handled differently?

**Q10.5:** Who gets notified of failures?
- User?
- Support team?
- Engineering team?
- All of the above?

---

### 11. **Multi-Agent Collaboration**

**Q11.1:** Can Lumin invoke **multiple specialized agents** for a single ticket?
- Example scenario: Market price check + SSIS error investigation for related issue
- Sequential execution?
- Parallel execution?

**Q11.2:** How does Lumin coordinate and merge results from multiple agents?
- Aggregation strategy?
- Conflict resolution?
- Result prioritization?

**Q11.3:** Can agents communicate with each other?
- Direct agent-to-agent calls?
- Through Lumin orchestrator only?
- Shared context store?

**Q11.4:** How are dependencies between agents handled?
- Agent A results needed before invoking Agent B

**Q11.5:** Should there be limits on agent chaining?
- Max depth of agent calls?
- Max total execution time?

---

### 12. **Backward Compatibility**

**Q12.1:** Should the current direct invocation still work?
- Current: `@MOS Support Agent investigate ticket #82115`
- Should this continue to work after integration?

**Q12.2:** Or should all invocations go through Lumin?
- New: `@Lumin investigate MOS ticket #82115`
- How do we migrate existing users?

**Q12.3:** What's the migration timeline?
- Immediate cutover?
- Phased rollout?
- Parallel operation period?

**Q12.4:** How do we communicate changes to users?
- Documentation updates?
- Training sessions?
- In-app notifications?

**Q12.5:** What about existing integrations or scripts that invoke MOS Support Agent directly?

---

## 📋 Integration Pattern Options

**Q13:** Which integration pattern fits best with Lumin's architecture?

### **Option A: Router Pattern**
```
User → Lumin (Router) → Detects "MOS" keywords → Invokes MOS Support Agent → Returns results to Lumin → Lumin responds to user
```
**Pros:** 
- Centralized control
- Consistent UX
- Easy to add more specialized agents
- Single point of monitoring

**Cons:** 
- Additional latency (extra hop)
- More complex routing logic
- Single point of failure

---

### **Option B: Skill Registration Pattern**
```
Lumin loads MOS skills at startup → User asks question → Lumin uses MOS skills directly → Posts to ADO
```
**Pros:** 
- Direct execution (faster)
- Simpler architecture
- Lower latency
- No agent-to-agent calls

**Cons:** 
- Tight coupling between Lumin and MOS logic
- Harder to maintain separate agents
- Skills become Lumin's responsibility

---

### **Option C: Hybrid Pattern**
```
User → Lumin → Simple queries handled by Lumin → Complex MOS queries delegated to MOS Support Agent
```
**Pros:** 
- Best of both worlds
- Optimized for common cases
- Flexibility in routing

**Cons:** 
- Need clear delegation criteria
- More complex logic
- Potential for routing errors

---

### **Option D: Plugin/Extension Pattern**
```
MOS Support Agent registers as Lumin plugin → Lumin discovers capabilities → Routes based on plugin metadata
```
**Pros:**
- Loose coupling
- Easy to add/remove plugins
- Plugin can update independently
- Clear separation of concerns

**Cons:**
- Requires plugin architecture
- Versioning complexity
- Discovery mechanism needed

---

## 🔧 Technical Integration Questions

### 14. **API/Interface**

**Q14.1:** What's the interface between Lumin and MOS Support Agent?
- [ ] REST API (HTTP/HTTPS)
- [ ] gRPC
- [ ] Function call (same process)
- [ ] Message queue (RabbitMQ, Azure Service Bus)
- [ ] Direct Python module import
- [ ] PowerShell script invocation
- [ ] WebSockets

**Q14.2:** What data format should be used?
- [ ] JSON
- [ ] Protocol Buffers
- [ ] XML
- [ ] Custom binary format

**Q14.3:** Is the interface synchronous or asynchronous?
- Synchronous: Lumin waits for MOS response
- Asynchronous: MOS posts back when done
- Hybrid: Quick ack + detailed results later

---

### 15. **Authentication & Security**

**Q15.1:** How does Lumin authenticate when calling MOS Support Agent?
- [ ] API key
- [ ] OAuth 2.0 / JWT tokens
- [ ] Mutual TLS
- [ ] Windows Integrated Authentication
- [ ] No authentication (trusted network)

**Q15.2:** Do both need separate Azure CLI tokens for ADO?
- Shared token?
- Independent tokens?
- Token delegation?

**Q15.3:** How is sensitive data (connection strings, credentials) protected?
- Encryption at rest?
- Encryption in transit?
- Credential rotation policy?

**Q15.4:** Are there network security considerations?
- Firewall rules?
- VPN requirements?
- Network segmentation?

**Q15.5:** What about data privacy/compliance?
- PII handling
- Data retention policies
- Audit requirements

---

### 16. **Rate Limiting & Resource Management**

**Q16.1:** Are there rate limits on:
- [ ] Database queries (per second/minute)
- [ ] ADO API calls (Azure DevOps limits)
- [ ] Agent invocations (concurrent or per time period)
- [ ] Token bucket algorithm needed?

**Q16.2:** How should resource contention be handled?
- Queue requests?
- Reject with error?
- Priority-based queuing?

**Q16.3:** What about cost management?
- API call costs (if applicable)
- Database query costs
- Compute resource costs

**Q16.4:** Should there be resource quotas per user/team?

**Q16.5:** How do we handle "runaway" queries or infinite loops?
- Timeouts?
- Circuit breakers?
- Kill switches?

---

### 17. **Testing Strategy**

**Q17.1:** How do we test the integration?
- [ ] Unit tests (individual components)
- [ ] Integration tests (Lumin + MOS end-to-end)
- [ ] Load tests (concurrent users)
- [ ] Chaos engineering (failure scenarios)

**Q17.2:** Can we use the existing MOS test cases?
- Should they be converted?
- Referenced as-is?
- Adapted for Lumin context?

**Q17.3:** Do we need integration tests between Lumin and MOS?
- Happy path scenarios
- Error scenarios
- Performance benchmarks

**Q17.4:** What's the test environment strategy?
- Separate test database?
- Mock ADO integration?
- Isolated test agent instances?

**Q17.5:** How do we test ADO integration without spamming real tickets?
- Test ADO project?
- Mock ADO API?
- Dry-run mode?

---

### 18. **Performance Requirements**

**Q18.1:** What are the performance SLAs?
- Response time targets? (e.g., <5 seconds for simple queries)
- Throughput? (e.g., 100 requests/minute)
- Availability? (e.g., 99.9% uptime)

**Q18.2:** What's acceptable latency for agent invocation?
- Lumin → MOS Support Agent round trip time?

**Q18.3:** Should results be cached?
- Cache frequently requested data?
- Cache duration?
- Cache invalidation strategy?

**Q18.4:** Are there database query performance requirements?
- Max query execution time?
- Query optimization needed?

---

## 📝 Recommended Next Steps

After gathering answers, we should create:

1. **Integration Design Document** covering:
   - Architecture diagrams (Lumin + MOS Support Agent interaction)
   - Routing decision tree with confidence thresholds
   - Data flow diagrams (request/response)
   - Sequence diagrams for key scenarios
   - Component interaction diagrams

2. **Configuration Specification**:
   - Required configuration parameters
   - Environment-specific settings
   - Feature flags
   - Default values

3. **Deployment Plan**:
   - Phased rollout approach
   - Rollback procedures
   - Migration steps
   - Validation checkpoints

4. **Testing Plan**:
   - Test scenarios and cases
   - Performance benchmarks
   - Integration test suite
   - User acceptance criteria

5. **Monitoring & Alerting Plan**:
   - Metrics to track
   - Dashboard requirements
   - Alert thresholds
   - Incident response procedures

6. **Documentation Updates**:
   - User documentation (how to use Lumin with MOS)
   - Developer documentation (how to extend/maintain)
   - Runbook (troubleshooting guide)
   - Change log

7. **Training Plan**:
   - User training materials
   - Developer onboarding
   - Support team enablement

---

## 📊 Decision Matrix Template

| Decision Point | Options | Pros | Cons | Recommendation | Notes |
|----------------|---------|------|------|----------------|-------|
| Integration Pattern | A, B, C, D | | | | |
| Routing Method | Keywords, Intent, Explicit | | | | |
| ADO Posting | Lumin, MOS, Both | | | | |
| Database Connections | Pass-through, Shared, Separate | | | | |
| Response Format | Structured, Formatted, Both | | | | |

---

## 🎯 Success Criteria

Define what "successful integration" means:

- [ ] Lumin can correctly route MOS-related queries to MOS Support Agent
- [ ] Response time meets performance targets
- [ ] ADO integration works seamlessly
- [ ] No degradation in MOS Support Agent capabilities
- [ ] Users have positive experience
- [ ] Monitoring and logging are comprehensive
- [ ] Error handling is robust
- [ ] Documentation is complete
- [ ] Tests pass with >90% coverage
- [ ] Backward compatibility maintained (or migration successful)

---

## 📞 Next Meeting Agenda

1. Review this questionnaire with lead engineer
2. Prioritize questions (critical vs. nice-to-have)
3. Schedule follow-up sessions for deep dives
4. Assign action items for research/prototyping
5. Set timeline for integration phases
6. Define success criteria and KPIs

---

**Document Owner:** [Your Name]  
**Last Updated:** 2026-07-06  
**Next Review:** [Schedule after lead engineer meeting]  
**Status:** DRAFT - Pending Lead Engineer Review
