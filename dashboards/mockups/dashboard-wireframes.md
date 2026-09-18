# Dashboard Wireframes — NovaPay Digital Bank

> **AI Attribution Block**: Dashboard wireframes designed with AI-assisted research. Reviewed by Nihal N.

## 1. Engineering Dashboard Wireframe

The Engineering Dashboard provides real-time operational visibility for the SRE and development teams.

```mermaid
block-beta
    columns 4
    
    block:dora:4
        columns 4
        A["Deployment Frequency\n3.2/day\n🟢 Elite"]
        B["Lead Time\n47 min\n🟢 Elite"]
        C["Change Failure Rate\n3.1%\n🟢 Elite"]
        D["MTTR\n8 min\n🟢 Elite"]
    end
    
    block:pipeline:2
        columns 1
        E["Pipeline Success Rate (7d)\n━━━━━━━━━━━━━━\n📈 96.3% trending up"]
    end
    
    block:stages:2
        columns 1
        F["Stage Duration Breakdown\n▓▓▓ Build: 9m\n▓▓▓▓ SAST: 12m\n▓▓▓ Scan: 8m\n▓▓▓▓▓ Integration: 15m\n▓▓▓▓▓▓ DAST: 20m\n▓▓ Compliance: 4m\n▓▓▓▓ Deploy: 12m"]
    end
    
    block:http:2
        columns 1
        G["HTTP Request Rate & Errors\n━━━━━━━━━━━━━━\nRPS: 2,450 | 5xx: 0.02%"]
    end
    
    block:latency:2
        columns 1
        H["Latency Distribution\n━━━━━━━━━━━━━━\np50: 45ms | p95: 120ms | p99: 180ms"]
    end
```

### Panel Specifications

| Row | Panels | Data Source | Refresh |
|-----|--------|------------|---------|
| Row 1 | 4x DORA metric stat panels | Prometheus | 30s |
| Row 2 | Pipeline success rate (time series) + Stage durations (bar chart) | Prometheus | 30s |
| Row 3 | HTTP request rate (time series) + Latency percentiles (time series) | Prometheus | 10s |
| Row 4 | Canary analysis status + Active alerts | Prometheus + Alertmanager | 10s |

---

## 2. Management Dashboard Wireframe

The Management Dashboard provides weekly/monthly executive visibility into delivery performance.

```mermaid
block-beta
    columns 6
    
    block:exec:6
        columns 6
        A["Deploys\nThis Week\n12"]
        B["Avg Lead\nTime\n0.8h"]
        C["Change\nFailure\n3.1%"]
        D["MTTR\n8 min"]
        E["Availability\n99.997%"]
        F["Active\nIncidents\n0"]
    end
    
    block:trend1:3
        columns 1
        G["Weekly Deployment Trend (12 weeks)\n▁▂▃▃▄▅▅▆▆▇▇█\nTrending: +15% MoM"]
    end
    
    block:trend2:3
        columns 1
        H["Lead Time Trend (12 weeks)\n█▇▇▆▅▅▄▃▃▂▂▁\nImproving: -22% MoM"]
    end
    
    block:cost:2
        columns 1
        I["Cost per Deploy\n$0.42\n⬇ -18%"]
    end
    
    block:auto:2
        columns 1
        J["Automation Ratio\n96.4%\n🟢 Target: >95%"]
    end
    
    block:feedback:2
        columns 1
        K["Dev Feedback Loop\n8.2 min\n🟢 Target: <10 min"]
    end
```

### Panel Specifications

| Row | Panels | Audience | Refresh |
|-----|--------|----------|---------|
| Row 1 | 6x KPI stat panels | CTO, VP Engineering | 5m |
| Row 2 | Deployment trend + Lead time trend (12 weeks) | CTO | 1h |
| Row 3 | Cost/deploy + Automation ratio + Developer feedback | VP Engineering | 5m |

---

## 3. Regulatory Dashboard Wireframe

The Regulatory Dashboard provides audit-ready compliance evidence for RBI and PCI-DSS reviews.

```mermaid
block-beta
    columns 4
    
    block:compliance:4
        columns 4
        A["Gate Pass Rate\n99.7%\n🟢"]
        B["Open CVEs\n0 Critical\n0 High"]
        C["Image Signing\n100%\n🟢"]
        D["SBOM Coverage\n100%\n🟢"]
    end
    
    block:rbi:4
        columns 6
        E["RBI 4.2\nChange Mgmt\n✅"]
        F["RBI 4.3\nSoD\n✅"]
        G["RBI 5.1\nVuln Assess\n✅"]
        H["RBI 5.4\nEncryption\n✅"]
        I["RBI 6.1\nAudit Trail\n✅"]
        J["RBI 6.3\nIncident Mgmt\n✅"]
    end
    
    block:audit:4
        columns 1
        K["Compliance Gate Audit Log\n────────────────────────────────────\nTimestamp | Pipeline | Commit | Gates Passed\n2026-08-24 10:15 | #4521 | a1b2c3d | SAST,DAST,DEP,POL\n2026-08-24 09:30 | #4520 | e4f5g6h | SAST,DAST,DEP,POL\n2026-08-23 16:45 | #4519 | i7j8k9l | SAST,DAST,DEP,POL"]
    end
```

### Panel Specifications

| Row | Panels | Audience | Refresh |
|-----|--------|----------|---------|
| Row 1 | 4x compliance KPIs (gauge + stat) | Head of Compliance, RBI Auditor | 1h |
| Row 2 | 6x RBI section compliance status (stat with value mapping) | RBI Auditor | 1h |
| Row 3 | Audit trail log table (Loki data source) | Compliance team | 15m |
| Row 4 | PCI-DSS requirement coverage (table) | PCI-DSS assessor | 1h |
