---

## Understanding the Trade Business (Layman's Guide)

### The Big Picture: What Are We Actually Doing?

Imagine you're running a **giant investment club** where different groups of people pool their money together to buy and sell loans and bonds. Your job is to:
- Keep track of who owns what
- Make sure the prices are accurate
- Verify all the cash coming in and going out
- Ensure everyone's records match

That's essentially what MOS Support does—but at a massive scale with millions of dollars flowing through multiple computer systems every day.

---

### The Key Players (Entities Explained)

#### 1. **The Investors (Funds & Portfolios)**

Think of these as different "investment clubs":
- **Fund**: A big pot of money (e.g., "ABC Loan Fund" with $500 million)
- **Portfolio**: A subset within that fund (e.g., "Senior Secured Loans" or "High Yield Bonds")

**Real-World Analogy**: Like different departments in a company—all part of the same organization but each has its own budget and goals.

#### 2. **The Trading Desk (IPOS)**

This is where traders **decide to buy or sell** investments:
- Trader sees an opportunity: "I want to buy $5 million of XYZ Company's loan"
- They enter the trade into IPOS (the trade entry system)
- IPOS is like the "order form" system

**Real-World Analogy**: Like placing an order on Amazon—you pick what you want, enter the details, and hit "submit."

#### 3. **The Loan Manager (Solvas)**

Solvas is the **specialized system for managing loans**:
- Tracks which loans the funds own
- Manages loan facilities (credit lines to companies)
- Keeps detailed records of loan positions
- Handles complex loan accounting

**Real-World Analogy**: Like a specialized inventory management system at a car dealership—tracks every vehicle (loan), its details, who owns it, and its value.

#### 4. **The Central Hub (MOS - Management Operating System)**

MOS is the **master coordinator**—the brain of the operation:
- Receives data from everywhere (Solvas, custodians, price vendors)
- Calculates positions (who owns how much of what)
- Generates reports for clients
- Acts as the "single source of truth"

**Real-World Analogy**: Like air traffic control—receives information from multiple sources, coordinates everything, ensures nothing crashes.

#### 5. **The Organizer (CAMOS)**

CAMOS manages **entity relationships and mappings**:
- Which portfolio belongs to which fund?
- Which client owns which portfolios?
- How do different systems refer to the same portfolio?

**Real-World Analogy**: Like an organizational chart for a company—shows who reports to whom and how everything connects.

#### 6. **The Banks (Custodians: Citi, Northern Trust, US Bank)**

Custodians are the **actual banks holding the money**:
- They keep the physical cash
- They hold the securities
- They send daily statements showing cash movements
- They act as the "bank account" for the funds

**Real-World Analogy**: Like your personal bank—they hold your money, process transactions, and send you statements.

#### 7. **The Pricing Services (Markit, ICE, Sycamore)**

These are **independent companies that tell us what investments are worth**:
- Markit: Specializes in loan pricing
- ICE: Specializes in bond pricing
- They provide daily "market prices" for positions

**Real-World Analogy**: Like Zillow for real estate or Kelley Blue Book for cars—they tell you what things are worth based on market data.

#### 8. **The Traffic Cop (Process Flow)**

Process Flow is the **automation and orchestration system**:
- Runs scheduled jobs (e.g., "Load Solvas trades at 8 AM")
- Moves data between systems
- Monitors for errors
- Triggers workflows

**Real-World Analogy**: Like a factory assembly line supervisor—ensures each step happens in the right order at the right time.

---

### How a Trade Flows Through the System (Step-by-Step)

Let's follow a **$10 million loan trade** from start to finish:

#### **Step 1: The Trade is Entered (Morning)**

**What Happens:**
- Trader wants to buy $10M of "ABC Corporation Senior Loan"
- Trader enters trade into **IPOS** (trade entry system)
- Trade details: Company name, amount, price, which portfolio should own it

**In Layman's Terms**: Filling out an order form to buy something.

---

#### **Step 2: Trade Books in Solvas (Within Minutes)**

**What Happens:**
- IPOS sends trade to **Solvas** (loan management system)
- Solvas checks: "Does the loan facility exist?"
- Solvas checks: "Is this portfolio allowed to trade?"
- If everything looks good, Solvas records the trade

**In Layman's Terms**: Like a warehouse receiving a purchase order and checking if the item exists and if the buyer has permission.

**⚠️ COMMON PROBLEM**: What if the portfolio isn't recognized?
- **Error**: "Unmapped Entity" or "Facility Not Found"
- **MOS Support Action**: Look up the correct mapping, create it in CAMOS, re-run the trade
- **Why It Happens**: New portfolios or new loan facilities that haven't been set up yet

---

#### **Step 3: Process Flow Loads Trade into MOS (Throughout the Day)**

**What Happens:**
- **Process Flow** runs every 30 minutes (scheduled job)
- It asks Solvas: "Any new trades?"
- Solvas sends trade data
- Process Flow loads it into **MOS**

**In Layman's Terms**: Like a mail carrier picking up packages every 30 minutes and delivering them to the distribution center.

**⚠️ COMMON PROBLEM**: What if Solvas times out?
- **Error**: "Process Flow Trade Bookings with No Results"
- **MOS Support Action**: Check Solvas connection, re-run the job manually
- **Why It Happens**: Network issues, Solvas is slow, or data volume is too high

---

#### **Step 4: MOS Allocates the Trade to Portfolios (Afternoon)**

**What Happens:**
- MOS receives trade: "$10M ABC Loan purchased"
- MOS looks up: "Which portfolio(s) should get this?"
- MOS uses mappings from **CAMOS** to figure it out
- MOS updates the position: "Portfolio XYZ now owns $10M of ABC Loan"

**In Layman's Terms**: Like a school distributing textbooks—figuring out which classroom gets which books based on enrollment.

**⚠️ COMMON PROBLEM**: What if the portfolio mapping is missing?
- **Error**: "Unable to allocate trade - no entity mapping"
- **MOS Support Action**: Create mapping in CAMOS (Portfolio → EntityID → Fund)
- **Why It Happens**: New portfolios, reorganizations, or data entry errors

---

#### **Step 5: Price the Position (End of Day)**

**What Happens:**
- End of day, MOS needs to know: "What is this $10M loan worth TODAY?"
- MOS checks **Security Master** (which gets prices from **Markit**)
- Markit says: "ABC Loan is trading at 98.5% of face value"
- Calculation: $10M × 98.5% = $9,850,000
- MOS records this as the position's market value

**In Layman's Terms**: Like checking your stock portfolio at the end of the day—you owned 100 shares at $50 each, they're now worth $48 each = $4,800.

**⚠️ COMMON PROBLEM**: What if the price looks wrong?
- **Error**: "Price Variance Exception - 5% difference from yesterday"
- **MOS Support Action**: Check if Markit has correct data, verify with trader, potentially override the price with approval
- **Why It Happens**: Vendor data errors, market events, or missing prices

---

#### **Step 6: Cash Reconciliation (End of Day)**

**What Happens:**
- The trade settles (money exchanges hands)
- **Custodian** (e.g., Citi Bank) sends statement: "$10M went out to pay for ABC Loan"
- **Solvas** says: "$10M should have been paid for ABC Loan"
- **Cash Rec module** in MOS tries to match them automatically

**In Layman's Terms**: Like reconciling your credit card statement—matching your receipts to the bank's charges.

**⚠️ COMMON PROBLEM**: What if they don't match?
- **Error**: "Unmatched Transaction - Solvas shows $10M, Bank shows $10.1M"
- **MOS Support Action**: Investigate the $100K difference, check if it's fees, timing, or an error
- **Manual Fix**: Match the transactions once the reason is found
- **Why It Happens**: Timing differences, fees, bank errors, or incorrect booking

---

#### **Step 7: Client Reporting (Next Morning)**

**What Happens:**
- MOS has all the data: positions, prices, cash movements
- MOS generates reports: "As of yesterday, Portfolio XYZ owns $9.85M of ABC Loan (market value)"
- Reports go to **Client Portal** or are emailed

**In Layman's Terms**: Like getting your monthly bank statement or 401(k) statement.

---

### What MOS Support Does (In Simple Terms)

MOS Support is like the **911 dispatcher and repair crew** for this whole system:

#### **When Things Go Wrong:**

1. **Trade won't book?** → Find out why (missing mapping? timeout? wrong data?) and fix it
2. **Price looks wrong?** → Investigate the source, verify with vendors, override if needed
3. **Cash doesn't match?** → Compare the two sides, find the discrepancy, manually match
4. **Position doesn't reconcile?** → Figure out where the difference comes from, correct it
5. **System integration fails?** → Check connections, restart jobs, coordinate with IT

#### **Daily Monitoring:**

- Watch dashboards for errors (like security guards watching monitors)
- Read email alerts (currently 2-4 hour delay before issues are noticed)
- Run SQL queries to check data (50+ queries per day!)
- Coordinate with traders, operations teams, and IT

#### **The Manual Work (Current State):**

- **15 minutes** to map a single entity manually
- **45-60 minutes** average to resolve an issue
- **50 SQL queries per day** to investigate problems
- **High stress** because issues impact client money and reports

---

### Why This Is Complex

#### **Multiple Systems That Must Stay in Sync:**

Imagine you have:
- 6 different spreadsheets (systems)
- Each updated by different people (teams)
- All tracking the same investments
- They MUST match perfectly every day

If even ONE spreadsheet has wrong data, the whole picture is wrong.

#### **High Stakes:**

- Client portfolios worth **hundreds of millions of dollars**
- Errors can mean incorrect reports to regulators
- Trading decisions are made based on this data
- Clients trust us to be accurate

#### **Many Moving Parts:**

- 1,270 trades per day (average)
- Hundreds of portfolios
- Thousands of loan and bond positions
- Multiple custodian banks
- Multiple price vendors
- Different time zones and schedules

---