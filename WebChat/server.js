/**
 * MOS Support Agent - Backend Server
 * 
 * This server receives chat messages and invokes the MOS Support Agent
 * by executing PowerShell scripts and following skill workflows.
 */

const express = require('express');
const cors = require('cors');
const { exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Paths
const ADMIN_TOOLS_PATH = path.join(__dirname, '..');
const SKILLS_PATH = path.join(ADMIN_TOOLS_PATH, '.github', 'skills');
const OUTPUT_PATH = path.join(ADMIN_TOOLS_PATH, 'Output');

// Agent configuration
const TAXONOMY_FILE = path.join(ADMIN_TOOLS_PATH, 'MOSSupportTaskTaxonomy.md');

/**
 * Parse user message and route to appropriate skill
 */
async function routeMessage(message) {
    const lowerMessage = message.toLowerCase();
    
    // Extract ticket number if present
    const ticketMatch = message.match(/#?(\d{5,6})/);
    const ticketId = ticketMatch ? ticketMatch[1] : null;

    // Keyword-based routing (from taxonomy)
    const routes = [
        {
            keywords: ['price', 'pricing', 'markit', 'lseg', 'ice', 'vendor', 'cusip', 'market price'],
            skill: 'check-market-price',
            confidence: 0.85,
            category: 'Market Pricing'
        },
        {
            keywords: ['bulk', 'price exception', 'price validation', 'compare prices', 'excel', 'solvas price'],
            skill: 'bulk-price-validation',
            confidence: 0.80,
            category: 'Bulk Price Validation'
        },
        {
            keywords: ['override', 'manual price', 'custom price', 'tag', 'price override'],
            skill: 'price-overrides',
            confidence: 0.85,
            category: 'Price Overrides'
        },
        {
            keywords: ['ssis', 'powershell', 'package', 'etl', 'script', 'job failed', 'seq error'],
            skill: 'check-ssis-errors',
            confidence: 0.80,
            category: 'SSIS/PowerShell Errors'
        },
        {
            keywords: ['dashboard', 'process dashboard', 'remove report', 'delete report', 'operations dashboard'],
            skill: 'remove-process-dashboard-reports',
            confidence: 0.75,
            category: 'Dashboard Management'
        },
        {
            keywords: ['cash', 'reconciliation', 'balance', 'sfr', 'transaction match'],
            skill: 'check-cash-reconciliation',
            confidence: 0.60,
            category: 'Cash Reconciliation',
            status: 'In Development'
        },
        {
            keywords: ['normalize', 'normalization', 'mapping', 'data transform', 'feed'],
            skill: 'check-data-normalization',
            confidence: 0.60,
            category: 'Data Normalization',
            status: 'In Development'
        }
    ];

    // Calculate match scores
    let bestMatch = null;
    let highestScore = 0;

    for (const route of routes) {
        const matchCount = route.keywords.filter(keyword => 
            lowerMessage.includes(keyword)
        ).length;
        
        if (matchCount > 0) {
            const score = (matchCount / route.keywords.length) * route.confidence;
            if (score > highestScore) {
                highestScore = score;
                bestMatch = route;
            }
        }
    }

    // Special: list skills
    if (lowerMessage.includes('list skill') || lowerMessage.includes('help') || lowerMessage.includes('what can you')) {
        return {
            skill: 'help',
            confidence: 1.0,
            category: 'Help',
            data: { ticketId }
        };
    }

    // If no good match, return general investigation
    if (!bestMatch || highestScore < 0.3) {
        return {
            skill: 'general',
            confidence: 0.5,
            category: 'General Investigation',
            data: { ticketId, message }
        };
    }

    return {
        skill: bestMatch.skill,
        confidence: highestScore,
        category: bestMatch.category,
        status: bestMatch.status || 'Ready',
        data: { ticketId, message }
    };
}

/**
 * Execute skill-specific logic
 */
async function executeSkill(route) {
    const { skill, confidence, category, status, data } = route;

    // Handle help command
    if (skill === 'help') {
        return {
            response: `**📚 Available MOS Support Skills**\n\n` +
                `**✅ Production Ready:**\n` +
                `• **check-market-price** - Vendor pricing, Markit, LSEG, ICE analysis\n` +
                `• **bulk-price-validation** - Excel-based price comparison across sources\n` +
                `• **price-overrides** - Manual price override generation (MOS + Solvas)\n` +
                `• **check-ssis-errors** - SSIS package failures, PowerShell debugging\n` +
                `• **remove-process-dashboard-reports** - Dashboard report cleanup\n\n` +
                `**🚧 In Development:**\n` +
                `• **check-cash-reconciliation** - Balance discrepancies, SFR, transaction matching\n` +
                `• **check-data-normalization** - Feed mapping, data transformation\n\n` +
                `**Try asking:**\n` +
                `• "Investigate ticket #82115"\n` +
                `• "Check pricing for CUSIP 83408EAA1"\n` +
                `• "Help with bulk price validation"\n` +
                `• "Analyze SSIS error in pInstFundValueI package"`,
            skill: 'help',
            confidence: 1.0
        };
    }

    // Handle general investigation
    if (skill === 'general') {
        let response = `I understand you're asking about: "${data.message}"\n\n`;
        
        if (data.ticketId) {
            response += `**Ticket ID detected:** #${data.ticketId}\n\n`;
            response += `To investigate this ticket, I need more context. Please specify:\n`;
            response += `• What type of issue? (pricing, cash rec, SSIS error, etc.)\n`;
            response += `• Any specific identifiers (CUSIP, company name, etc.)\n\n`;
        }
        
        response += `**I can help with:**\n`;
        response += `• Market pricing issues\n`;
        response += `• Bulk price validations\n`;
        response += `• SSIS/PowerShell errors\n`;
        response += `• Price overrides\n`;
        response += `• Dashboard report management\n\n`;
        response += `Type "list skills" to see all available capabilities.`;

        return {
            response,
            skill: 'general',
            confidence: 0.5
        };
    }

    // Check if skill file exists
    const skillFile = path.join(SKILLS_PATH, skill, 'SKILL.md');
    
    try {
        await fs.access(skillFile);
    } catch (error) {
        return {
            response: `**⚠️ Skill Status: ${status || 'Not Found'}**\n\n` +
                `The **${skill}** skill is ${status === 'In Development' ? 'currently being developed' : 'not yet available'}.\n\n` +
                `**Detected:** ${category}\n` +
                `**Confidence:** ${Math.round(confidence * 100)}%\n\n` +
                `This skill will be available soon. For now, try one of the production-ready skills.`,
            skill,
            confidence
        };
    }

    // Skill exists - execute it
    const skillContent = await fs.readFile(skillFile, 'utf-8');
    
    // Parse skill requirements from the SKILL.md
    const requirementsMatch = skillContent.match(/## Required Inputs([\s\S]*?)##/);
    const requirements = requirementsMatch ? requirementsMatch[1].trim() : 'See skill documentation';

    let response = `**🔍 Invoking Skill: ${skill}**\n\n`;
    response += `**Category:** ${category}\n`;
    response += `**Confidence:** ${Math.round(confidence * 100)}%\n`;
    
    if (data.ticketId) {
        response += `**Ticket ID:** #${data.ticketId}\n\n`;
        
        // Try to fetch ticket details
        response += `**Next Steps:**\n`;
        response += `1. Fetching ticket details from ADO...\n`;
        response += `2. Extracting key information (company, date, identifiers)\n`;
        response += `3. Executing ${skill} investigation workflow\n\n`;
        
        // Simulate investigation steps (in real implementation, this would call PowerShell)
        response += `**Investigation Commands:**\n`;
        response += `\`\`\`powershell\n`;
        response += `# Fetch ticket details\n`;
        response += `az boards work-item show --id ${data.ticketId} --org https://siepe.visualstudio.com/\n\n`;
        response += `# Execute skill workflow\n`;
        response += `# (See ${skill}/SKILL.md for detailed steps)\n`;
        response += `\`\`\`\n\n`;
    } else {
        response += `\n**Required Information:**\n`;
        response += `This skill needs:\n`;
        
        // Extract required inputs from skill file
        if (skill === 'check-market-price') {
            response += `• Company name (e.g., "Aristotle Pacific Capital")\n`;
            response += `• Price date (e.g., "2026-06-30")\n`;
            response += `• Instrument identifier (CUSIP, ISIN, or LoanX ID)\n`;
        } else if (skill === 'bulk-price-validation') {
            response += `• Excel attachment with securities to validate\n`;
            response += `• Date range for price comparison\n`;
            response += `• Portfolio names\n`;
        } else if (skill === 'check-ssis-errors') {
            response += `• Tenant/Database name\n`;
            response += `• Package name\n`;
            response += `• Error message or code\n`;
            response += `• Timestamp\n`;
        } else {
            response += `• See skill documentation for requirements\n`;
        }
        
        response += `\nPlease provide more details or a ticket number to proceed.`;
    }

    return {
        response,
        skill,
        confidence
    };
}

/**
 * Health check endpoint
 */
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        message: 'MOS Support Agent Backend Running',
        skills: {
            production: 5,
            development: 2,
            planned: 6
        }
    });
});

/**
 * Main agent endpoint
 */
app.post('/api/agent', async (req, res) => {
    try {
        const { message } = req.body;
        
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        console.log(`[${new Date().toISOString()}] Received: ${message}`);

        // Route message to appropriate skill
        const route = await routeMessage(message);
        console.log(`[${new Date().toISOString()}] Routed to: ${route.skill} (confidence: ${route.confidence.toFixed(2)})`);

        // Execute skill
        const result = await executeSkill(route);

        res.json({
            response: result.response,
            skill: result.skill,
            confidence: result.confidence
        });

    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({ 
            error: 'Internal server error',
            message: error.message 
        });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║       MOS Support Agent - Test Console Backend           ║
║                                                           ║
║  Server running on: http://localhost:${PORT}                ║
║  Web UI available at: WebChat/index.html                 ║
║                                                           ║
║  Skills Path: ${SKILLS_PATH.substring(0, 35)}...  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
    `);
    console.log('Ready to process agent requests...\n');
});
