# MOS Database Schema - Real Data
**Queried:** 2026-06-30 13:20:23
**Server:** mos-sql-p.mos.siepe.local,52155

## Available Databases

name     
----     
Core     
Reference

## Database & Schema Structure

**Databases:**
- **Core** - Main operational database (contains all tables listed below)
- **Reference** - Reference/lookup data database

**Schemas in Core Database:**
- **`dbo`** - Default schema (contains all tables: tPosition, tCashRec, tCompanyPortfolioMap, etc.)
- **`CashRec`** - Cash Reconciliation procedures and views
- **`OMS`** - Order Management System / Trade operations
- **`Client`** - Client-facing operations and reports
- **`Portal`** - Portal/UI operations
- **`Report`** - Reporting procedures
- **`Attribution`** - Performance attribution
- **`Lumen`** - Lumen system integration
- **`SvcMapping`** - Mapping services
- **`SvcLegalEntity`** - Legal entity services

**Naming Convention:**
- Tables: `tTableName` (prefix 't', stored in `Core.dbo` schema)
- Procedures: `SchemaName.pProcedureName` (prefix 'p')
- Views: `SchemaName.vViewName` (prefix 'v')

## Core Database - Key Tables

### Position Tables

TABLE_NAME                     
----------                     
tPosition                      
tPositionCashFlow              
tPositionPL                    
tPositionPriceWeighting        
tPositionPriceWeightingCriteria
tPositionRecAttachment         
tPositionSplitTrade            
tPositionType                  
tPositionValue                 
tPositionValueType             



### Cash Rec Tables

TABLE_NAME                         
----------                         
[tFundAccountThreshold_ToBeDeleted]
tAccountReinvestment               
tAccountTransfer                   
tAccountTransferNote               
tAccountTrueUp                     
tAppliedTransaction                
tBreakCategory                     
tCashMovement                      
tCashMovementStatus                
tCashMovementType                  
tCashRec                           
tCashRecDiscrepancyNote            
tCashRecFund                       
tCashRecReinvestment               
tCashRecTransfer                   
tCashRecUnapprovalNote             
tDataSource                        
tDataSourceType                    
tFundDistribution                  
tFundGroup                         



### Mapping Tables

TABLE_NAME                           
----------                           
tAgentToolMap                        
tAnalystGroupMap                     
tBusinessObjectKeywordMap            
tCharacteristicValueCharacteristicMap
tClientFieldMap                      
tCompanyPersonMap                    
tCompanyPortfolioMap                 
tDeliveryContentMechanismMap         
tEmailExcelMap                       
tEmailMapping                        
tEmailPdfMap                         
tExpenseAllocationTypeMap            
tExpenseProjectMap                   
tExpenseTagMap                       
tExpenseTypeVendorCategoryMap        
tExpenseVendorMap                    
tFieldMapping                        
tFundCalendarTypeMap                 
tFundFundAdministratorMap            
tFundFundAdminMap                    



## Key Stored Procedures for MOS Support

### Trade Booking Procedures

ProcedureName                                  
-------------                                  
OMS.pAddTradeConfirmations                     
OMS.pAddVconTradeConfirmations                 
Client.pAnalystTradeExport                     
Client.pAnalystTrades                          
Portal.pAnalystTrades                          
Attribution.pBasketTrades                      
Report.pCashRecon_Solvas_USBank                
Report.pCashReconMatchedInactiveSolvasDataset  
Report.pCashReconUnmatchedInactiveSolvasDataset
Report.pClearParOpenTradesReport               
Portal.pClearParPendingTradeMetrics            
Portal.pClearParSettledTradeMetrics            
Portal.pCounterpartyTradeExport                
Client.pCounterpartyTradeExport                
Client.pCounterpartyTrades                     



### Cash Rec Procedures

ProcedureName                                
-------------                                
CashRec.pApprovedCashRecReport               
CashRec.pCashRecD                            
CashRec.pCashRecDashboardXML                 
Client.pCashRecDatasources                   
CashRec.pCashRecDiscrepancyNoteIU            
CashRec.pCashRecFundD                        
CashRec.pCashRecFundI                        
CashRec.pCashRecFundIU                       
CashRec.pCashRecFundsXML                     
CashRec.pCashRecI                            
Report.pCashRecon                            
Report.pCashRecon_Solvas_USBank              
Client.pCashReconciliationEmailReport        
Client.pCashReconciliationReport             
Report.pCashReconMatchedInactiveSolvasDataset



### Mapping & Entity Procedures

ProcedureName                           
-------------                           
Client.pAccountMappingDetails           
Lumen.pAllPromptMappingsForQuery        
Client.pAnalystPositionsByPortfolio     
dbo.pCAMOSPortfolioFundNameChange       
Portal.pClearPortfolioPerformance       
dbo.pCompanyPortfolioMapD               
Client.pCompanyPortfolioMapD            
Client.pCompanyPortfolioMapI            
dbo.pCompanyPortfolioMapI               
Client.pCompanyPortfolioMapU            
dbo.pCompanyPortfolioMapU               
dbo.pCompareEntityMergeInventory        
SvcMapping.pCorePortfolioCoreMapStatus  
SvcLegalEntity.pCounterpartyEntityIU    
Portal.pCounterpartyPositionsByPortfolio



## Key Views for Monitoring


ViewName                              
--------                              
CashRec.vCashRecActive                
CashRec.vCashRecDiscrepancyNoteActive 
CashRec.vCashRecDiscrepancyNoteCurrent
CashRec.vCashRecDiscrepancyNoteRaw    
CashRec.vCashRecFundActive            
CashRec.vCashRecFundRaw               
CashRec.vCashRecRaw                   
CashRec.vCashRecReinvestmentActive    
CashRec.vCashRecReinvestmentRaw       
CashRec.vCashRecStatus                
CashRec.vCashRecStatusActive          
CashRec.vCashRecTransferActive        
CashRec.vCashRecTransferRaw           
CashRec.vCashRecUnapprovalNoteActive  
CashRec.vCashRecUnapprovalNoteCurrent 
CashRec.vCashRecUnapprovalNoteRaw     
dbo.vPosition                         
Client.vPosition                      
Lumen.vPosition                       
dbo.vPositionActive                   
OMS.vPositionAdjustmentActive         
OMS.vPositionAdjustmentRaw            
OMS.vPositionAndTrade                 
dbo.vPositionCashFlowActive           
dbo.vPositionCashFlowRaw              



