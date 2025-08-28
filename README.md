# EL_Parser - Ethereum Execution Layer Log Parser

A bash script for analyzing Ethereum execution client logs to extract throughput metrics (TPS and Mgas/s).

## Supported Clients

- **Geth** - Parses "Imported new potential chain segment" log entries
- **Nethermind** - Analyzes "Block throughput" log entries
- **Besu** - Processes "Imported #" entries with performance metrics
- **Reth** - Parses "Block added to canonical chain" with gas throughput
- **Erigon** - Extracts metrics from "Executed blocks" log entries

## Usage

```bash
./EL_Parser.sh [options]
```

### Options

- `-h` - Show help message
- `-n <limit>` - Limit to <limit> lines parsed, potentially useful for VERY large logfiles (default: off)
- `-l <logfile>` - Choose the logfile to parse, set it permanently with the LOGFILE variable
- `-c <client>` - Choose which client to parse the logs for, set it permanently with the CLIENT variable
- `-t <tps|mgas>` - Will return the maximum and average throughput of the client as measured by tps/mgas (default: both)

### Examples

```bash
# Parse Geth logs with default settings
./EL_Parser.sh -c geth -l geth.log

# Get only TPS metrics from last 1000 lines of Erigon logs
./EL_Parser.sh -c erigon -l erigon.log -n 1000 -t tps

```

## Output

The script outputs maximum and average values for:
- **TPS (Transactions Per Second)** - Transaction processing rate
- **Mgas/s (Million Gas Per Second)** - Gas consumption rate

## Configuration

Default values can be modified at the top of the script:
- `LOGFILE` - Default log file path
- `CLIENT` - Default client type
- `LIMIT` - Default line limit (0 = no limit)

## Requirements

- Bash shell
- AWK (for log parsing)
- Standard Unix utilities (tail, etc.)
