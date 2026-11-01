# I2C Master–Slave RTL Design and SystemVerilog Verification

## Project Overview

This project implements an **I2C Master–Slave communication system** using Verilog HDL and verifies its functionality using a SystemVerilog-based, self-checking testbench.

The design supports serial data communication between an I2C master and slave using the standard two-wire interface:

- **SCL:** Serial Clock Line
- **SDA:** Serial Data Line

The master initiates read and write transactions, while the slave responds to the master's requests and performs memory operations.

A transaction-based verification environment is developed to generate randomized stimulus, drive transactions, monitor DUT responses, and check the results using a reference scoreboard. SystemVerilog Assertions (SVA) are also used to check important protocol and design behaviors.

## Project Objectives

- Design an I2C master and slave using Verilog HDL.
- Implement serial read and write operations.
- Understand and implement I2C START, STOP, ACK, and NACK conditions.
- Develop a self-checking SystemVerilog verification environment.
- Generate randomized read and write transactions.
- Verify data integrity using a reference model and scoreboard.
- Use SystemVerilog Assertions to check design behavior.
- Analyze simulation waveforms to debug and validate transactions.

## Design Specifications

| Parameter | Specification |
|---|---|
| Protocol | I2C |
| Architecture | Master–Slave |
| Address width | 7 bits |
| Data width | 8 bits |
| Master system clock | 40 MHz |
| I2C clock frequency | 100 kHz |
| Slave memory | 128 × 8 bits |
| Communication | Serial, two-wire |
| Data transfer | Read and Write |
| Verification language | SystemVerilog |
| RTL language | Verilog HDL |
| Simulation | EDA Playground / Riviera-PRO |

## I2C Protocol Overview

I2C is a synchronous serial communication protocol that uses two bidirectional lines.

### 1. START Condition

The master initiates communication by pulling SDA LOW while SCL is HIGH.

### 2. Address Transmission

The master transmits the 7-bit slave address followed by the R/W bit.

- `0` – Write operation
- `1` – Read operation

### 3. ACK/NACK

The receiver acknowledges a successfully received byte by pulling SDA LOW during the ninth clock pulse.

- ACK: SDA LOW
- NACK: SDA HIGH

### 4. Data Transmission

Data is transferred serially, MSB first, in 8-bit groups.

### 5. STOP Condition

The master terminates communication by allowing SDA to transition from LOW to HIGH while SCL is HIGH.

## RTL Architecture

The design consists of three major RTL components:

### 1. I2C Master

The master controls the communication process.

Responsibilities:
- Generate the I2C clock from the system clock.
- Initiate START and STOP conditions.
- Transmit the slave address and R/W bit.
- Perform serial data transmission and reception.
- Handle ACK/NACK responses.
- Generate transaction completion and status signals.

### 2. I2C Slave

The slave responds to master requests.

Responsibilities:
- Detect START and STOP conditions.
- Receive and decode the 7-bit address.
- Identify read and write operations.
- Generate ACK responses.
- Receive and transmit 8-bit data.
- Perform memory read and write operations.
- Handle master ACK/NACK during read operations.

The slave contains a 128 × 8-bit memory, initialized with its corresponding address values.

### 3. I2C Top Module

The top module integrates the master and slave.

Responsibilities:
- Instantiate the master and slave modules.
- Connect the shared SCL and SDA bus.
- Provide the required clock and reset connections.
- Connect transaction data and status signals.
- Combine the modules into a complete I2C communication system.

## Verification Environment

A modular, transaction-based SystemVerilog testbench is developed to verify the RTL design.

The environment consists of the following components:

| Component | Responsibility |
|---|---|
| Interface | Connects the testbench and DUT signals |
| Transaction | Defines randomized transaction fields and constraints |
| Generator | Creates randomized transactions |
| Driver | Drives read and write requests to the DUT |
| Monitor | Captures transaction information and DUT responses |
| Scoreboard | Checks read data against the reference memory |
| Environment | Integrates and coordinates all verification components |
| Assertions | Checks important design properties |
| Testbench Top | Instantiates the DUT, assertions, and verification environment |

### Verification Flow

1. The generator creates randomized transactions.
2. Transactions are passed to the driver through a mailbox.
3. The driver applies the requests to the DUT.
4. The master communicates with the slave.
5. The monitor captures transaction details and responses.
6. The scoreboard compares read data against the expected reference memory.
7. PASS/FAIL results and transaction statistics are reported.

### Scoreboard-Based Checking

The scoreboard maintains a reference memory model.

- For write transactions, the reference memory is updated with the written data.
- For read transactions, the returned DUT data is compared against the expected memory value.
- Each transaction is classified as PASS or FAIL.
- Completed, passed, and failed transaction counts are maintained.

The testbench is configured to generate 30 randomized transactions.

## SystemVerilog Assertions (SVA)

Assertions are used to check important master and slave design behaviors.

### Master Assertions

| Assertion | Purpose |
|---|---|
| Reset behavior | Checks that BUSY and DONE are LOW during reset |
| DONE pulse | Checks that DONE remains a one-cycle pulse |
| Transaction start | Checks that BUSY is asserted after a new transaction request |
| DONE/BUSY relationship | Checks that BUSY is LOW when DONE is asserted |

### Slave Assertions

| Assertion | Purpose |
|---|---|
| Bit counter range | Checks that the bit counter stays within its expected range |
| SDA enable during transmission | Checks SDA enable while sending data |
| SDA stability | Checks that transmitted SDA data remains stable while SCL is HIGH |
| ACK generation | Checks that the slave drives SDA LOW during ACK states |
| STOP condition | Checks that SDA is released during the STOP state |

The slave assertions are connected to the slave RTL using the SystemVerilog `bind` construct.

## Functional Coverage

Functional coverage is used to evaluate whether important transaction scenarios have been exercised.

The coverage model can include the following coverage points:

| Coverage Point | What It Checks |
|---|---|
| Read/Write operation | Both read and write transactions |
| Address coverage | Access to different address ranges |
| Write-data coverage | Different values written to memory |
| Read-data coverage | Different values returned by the slave |
| Operation × Address | Read/write operations across address ranges |
| Operation × Data | Data values observed for different operations |

Additional scenarios of interest include back-to-back transactions and read-after-write operations.

## Simulation and Waveform Analysis

The design and verification environment can be simulated using EDA Playground with a supported SystemVerilog simulator.

The testbench includes:
- Clock generation.
- Reset and transaction execution.
- VCD waveform dumping.
- Simulation timeout protection.
- Final test completion reporting.

### Important Waveform Signals

**Testbench interface (`tb/vif`):**
- `clk`
- `rst`
- `newd`
- `op`
- `addr`
- `din`
- `dout`
- `busy`
- `done`
- `ack_err`

**Master internal signals (`tb/dut/master`):**
- `state`
- `scl`
- `sda`
- `sda_t`
- `sda_en`
- `bitcnt`
- `shift_reg`

**Slave internal signals (`tb/dut/slave`):**
- `state`
- `scl`
- `sda`
- `sda_t`
- `sda_en`
- `bitcnt`
- `shift_reg`

Waveforms are analyzed to understand the complete transaction sequence, verify START/STOP conditions, inspect ACK responses, and debug read/write behavior.

## Tools and Technologies

- Verilog HDL
- SystemVerilog
- SystemVerilog Assertions (SVA)
- Functional Coverage
- EDA Playground
- Riviera-PRO
- VCD Waveform Analysis
- Git and GitHub

## Repository Structure

```text
I2C-Master-Slave-RTL-Verification/
│
├── rtl/
│   ├── i2c_master.v
│   ├── i2c_slave.v
│   └── i2c_top.v
│
├── testbench/
│   ├── i2c_if.sv
│   ├── transaction.sv
│   ├── generator.sv
│   ├── driver.sv
│   ├── monitor.sv
│   ├── scoreboard.sv
│   ├── environment.sv
│   └── tb.sv
│
├── assertions/
│   └── i2c_assertions.sv
│
├── coverage/
│   └── i2c_coverage.sv
│
├── waveforms/
│   └── Simulation_results
        └──I2c_waveform.jpg
│
└── README.md
```

## Expected Verification Results

The testbench is designed to:
- Generate 30 randomized transactions.
- Exercise I2C read and write operations.
- Check returned data using the scoreboard.
- Report transaction PASS/FAIL status.
- Evaluate the configured assertions.
- Display final transaction statistics.

A successful simulation should complete without unexpected assertion failures or scoreboard mismatches.

## Key Learning Outcomes

Through this project, I gained practical experience in:

- I2C protocol operation and serial communication.
- RTL design using Verilog HDL.
- FSM-based hardware design.
- SystemVerilog object-oriented testbench development.
- Transaction-based verification.
- Mailbox-based communication between verification components.
- Scoreboard and reference-model-based checking.
- SystemVerilog Assertions.
- Simulation waveform analysis and debugging.

---

**Author:** Shreya Sharma  
**Domain:** VLSI Design and Functional Verification  
**GitHub:** [spunkycurative](https://github.com/spunkycurative)
