# AXI4-Lite Slave RTL & SystemVerilog Verification

A Verilog implementation of an **AXI4-Lite Slave** with a **128 × 32-bit internal memory**, verified using a class-based SystemVerilog testbench.

## Overview

The project implements the five AXI4-Lite channels:

- **AW** — Write Address
- **W** — Write Data
- **B** — Write Response
- **AR** — Read Address
- **R** — Read Data

The slave uses an FSM to control read/write transactions and provides decode-error responses for invalid addresses.

## Architecture

```text
Generator
    │
    ▼
 Driver ──────► AXI4-Lite Slave ──────► Monitor
                                      │
                                      ▼
                                  Scoreboard
```

## DUT Specifications

| Parameter | Value |
|---|---|
| Protocol | AXI4-Lite |
| Address Width | 32-bit |
| Data Width | 32-bit |
| Memory Depth | 128 |
| Memory Range | 0–127 |
| RTL | Verilog |
| Verification | SystemVerilog |

Internal memory:

```verilog
reg [31:0] mem[128];
```

## Verification Environment

The testbench contains:

- **Transaction** — represents read/write operations
- **Generator** — creates constrained-random transactions
- **Driver** — drives AXI4-Lite stimulus
- **Monitor** — captures DUT transactions
- **Scoreboard** — maintains a reference memory and checks `RDATA`
- **Environment** — connects all components

Communication between components uses **SystemVerilog mailboxes and events**.

## Verification

The environment verifies:

- Read/write transactions
- Read-after-write behavior
- Multiple memory locations
- Reset behavior
- AXI response codes
- Invalid-address decode errors
- Returned data against the reference model

Example:

```text
[DRV]: op:1 | awaddr:6 | wdata:84
[MON]: op:1 | awaddr:6 | wdata:84 | bresp:0
[SCO]: DATA STORED AT ADDR: 6 AND DATA: 84

[DRV]: op:0 | araddr:6
[MON]: op:0 | araddr:6 | rdata:84 | rresp:0
[SCO]: RESULTS MATCHED
```

## Project Structure

```text
AXI4-Lite-Slave/
├── rtl/
│   └── axilite_s.v
├── tb/
│   └── tb.sv
└── README.md
```

## Key Concepts

- AXI4-Lite protocol
- FSM-based RTL design
- SystemVerilog interfaces & modports
- Constrained randomization
- Virtual interfaces
- Mailboxes & events
- Transaction-based verification
- Monitor and scoreboard
- Reference-model-based checking

## Future Improvements

- [ ] Add SystemVerilog Assertions (SVA)
- [ ] Add functional coverage
- [ ] Improve AXI `VALID && READY` handshake handling
- [ ] Add more corner-case and invalid-address tests
- [ ] Extend the environment toward UVM

## Status

**Completed — Functional AXI4-Lite slave with class-based SystemVerilog verification.**
