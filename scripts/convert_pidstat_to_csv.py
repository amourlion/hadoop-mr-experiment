#!/usr/bin/env python3
"""
Convert pidstat output to CSV format
Usage: python3 convert_pidstat_to_csv.py <input_file> <output_file>
"""

import sys
import re
import csv
from datetime import datetime

def parse_pidstat_line(line):
    """Parse a single pidstat data line and extract metrics"""
    # Remove extra whitespace and split
    parts = line.strip().split()
    if len(parts) < 8:
        return None
    
    # Skip header lines
    if any(header in line for header in ['%usr', '%system', 'kB_rd/s', 'kB_wr/s', 'minflt/s', 'majflt/s']):
        return None
    
    # Try to parse data line - must end with java
    if not (len(parts) >= 8 and parts[-1] == 'java'):
        return None
    
    try:
        # Extract timestamp (first two parts)
        timestamp = parts[0] + ' ' + parts[1]
        uid = parts[2]
        pid = parts[3]
        
        # Determine metric type by analyzing the data pattern
        if len(parts) >= 10:
            # Check if this looks like CPU metrics: %usr %system %guest %wait %CPU CPU
            try:
                float(parts[4])  # %usr
                float(parts[5])  # %system  
                float(parts[6])  # %guest
                float(parts[7])  # %wait
                float(parts[8])  # %CPU
                int(parts[9])    # CPU core
                
                return {
                    'timestamp': timestamp,
                    'uid': uid,
                    'pid': pid,
                    'metric_type': 'cpu',
                    'usr_pct': parts[4],
                    'system_pct': parts[5], 
                    'guest_pct': parts[6],
                    'wait_pct': parts[7],
                    'cpu_pct': parts[8],
                    'cpu_core': parts[9],
                    'command': parts[-1]
                }
            except ValueError:
                pass
        
        if len(parts) >= 9:
            # Check if this looks like memory metrics: minflt/s majflt/s VSZ RSS %MEM
            try:
                if '.' in parts[4] and '.' in parts[5]:  # minflt/s and majflt/s usually have decimals
                    float(parts[4])  # minflt/s
                    float(parts[5])  # majflt/s
                    int(parts[6])    # VSZ (should be large integer)
                    int(parts[7])    # RSS (should be large integer)
                    float(parts[8])  # %MEM
                    
                    return {
                        'timestamp': timestamp,
                        'uid': uid,
                        'pid': pid,
                        'metric_type': 'memory',
                        'minflt_per_s': parts[4],
                        'majflt_per_s': parts[5],
                        'vsz_kb': parts[6],
                        'rss_kb': parts[7],
                        'mem_pct': parts[8],
                        'command': parts[-1]
                    }
            except ValueError:
                pass
                
            # Check if this looks like I/O metrics: kB_rd/s kB_wr/s kB_ccwr/s iodelay
            try:
                float(parts[4])  # kB_rd/s
                float(parts[5])  # kB_wr/s  
                float(parts[6])  # kB_ccwr/s
                int(parts[7])    # iodelay
                
                return {
                    'timestamp': timestamp,
                    'uid': uid,
                    'pid': pid,
                    'metric_type': 'io',
                    'kb_rd_per_s': parts[4],
                    'kb_wr_per_s': parts[5],
                    'kb_ccwr_per_s': parts[6],
                    'iodelay': parts[7],
                    'command': parts[-1]
                }
            except ValueError:
                pass
                
    except (IndexError, ValueError):
        pass
    
    return None

def convert_pidstat_to_csv(input_file, output_file):
    """Convert pidstat output file to CSV format"""
    
    # Define CSV headers for different metric types
    cpu_headers = ['timestamp', 'uid', 'pid', 'usr_pct', 'system_pct', 'guest_pct', 'wait_pct', 'cpu_pct', 'cpu_core', 'command']
    memory_headers = ['timestamp', 'uid', 'pid', 'minflt_per_s', 'majflt_per_s', 'vsz_kb', 'rss_kb', 'mem_pct', 'command']
    io_headers = ['timestamp', 'uid', 'pid', 'kb_rd_per_s', 'kb_wr_per_s', 'kb_ccwr_per_s', 'iodelay', 'command']
    
    # Collect all data by metric type
    cpu_data = []
    memory_data = []
    io_data = []
    
    try:
        with open(input_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('Linux') or line.startswith('#'):
                    continue
                    
                parsed = parse_pidstat_line(line)
                if parsed:
                    if parsed['metric_type'] == 'cpu':
                        cpu_data.append(parsed)
                    elif parsed['metric_type'] == 'memory':
                        memory_data.append(parsed)
                    elif parsed['metric_type'] == 'io':
                        io_data.append(parsed)
    
        # Write to CSV file
        with open(output_file, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            
            # Write CPU data
            if cpu_data:
                writer.writerow(['# CPU Metrics'])
                writer.writerow(cpu_headers)
                for row in cpu_data:
                    writer.writerow([row.get(h, '') for h in cpu_headers])
                writer.writerow([])  # Empty row separator
            
            # Write Memory data  
            if memory_data:
                writer.writerow(['# Memory Metrics'])
                writer.writerow(memory_headers)
                for row in memory_data:
                    writer.writerow([row.get(h, '') for h in memory_headers])
                writer.writerow([])  # Empty row separator
                
            # Write I/O data
            if io_data:
                writer.writerow(['# I/O Metrics'])
                writer.writerow(io_headers)
                for row in io_data:
                    writer.writerow([row.get(h, '') for h in io_headers])
        
        print(f"Converted {input_file} to {output_file}")
        print(f"  CPU records: {len(cpu_data)}")
        print(f"  Memory records: {len(memory_data)}")
        print(f"  I/O records: {len(io_data)}")
        return True
        
    except Exception as e:
        print(f"Error converting {input_file}: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 convert_pidstat_to_csv.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    success = convert_pidstat_to_csv(input_file, output_file)
