# Raw Data

### **This is the Single Source of Truth**

   
| Table | Type | Grain | Rows | Source System |
| --- | --- | --- | --- | --- |
| `fact_shipments` | Fact | One row per shipment | 15,000 | Shipment Core |
| `dim_customer` | Dimension | One row per customer | 12 | ClientRegistry |
| `dim_driver` | Dimension | One row per driver | 20 | FleetManager |
| `dim_route` | Dimension | One row per route | 15 | RouteMapper |
| `dim_warehouse` | Dimension | One row per warehouse | 5 | WarehouseOps |
| `dim_date` | Dimension | One row per calendar date | 731 (2024–2025) | Generated |

Assumed that I have been granted access to two years of shipment records exported from five operational systems — each with its own structure, its own quirks, and its own gaps. My mandate is to load the data into SQL Server, conduct a structured analytical investigation across six deliverables, and present the findings to the executive team.

The mission is not to confirm what the stakeholders already believe. My Goal here to find what the data actually says — even if that contradicts every theory in the room.
