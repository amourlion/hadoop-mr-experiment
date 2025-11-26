#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Universal Dataset Generator for Hadoop MapReduce Experiments
Generates text datasets of any size for word count analysis with realistic text patterns.
Usage: python3 generate_data.py <size_in_mb> [options]
"""

import os
import random
import string
import argparse
import sys
from datetime import datetime

class DatasetGenerator:
    def __init__(self):
        # Common English words for realistic text generation
        self.common_words = [
            'hadoop', 'mapreduce', 'yarn', 'hdfs', 'spark', 'kafka', 'storm', 'hive', 'pig', 'zookeeper',
            'distributed', 'computing', 'cluster', 'node', 'data', 'processing', 'analytics', 'streaming',
            'batch', 'real-time', 'big', 'scale', 'framework', 'apache', 'ecosystem', 'pipeline',
            'storage', 'compute', 'memory', 'disk', 'network', 'bandwidth', 'latency', 'throughput',
            'performance', 'optimization', 'tuning', 'configuration', 'monitoring', 'metrics', 'logging',
            'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from',
            'system', 'application', 'service', 'job', 'task', 'process', 'thread', 'queue', 'buffer',
            'algorithm', 'structure', 'pattern', 'design', 'architecture', 'implementation', 'solution',
            'problem', 'issue', 'error', 'exception', 'failure', 'success', 'result', 'output', 'input',
            'file', 'directory', 'path', 'location', 'resource', 'allocation', 'scheduling', 'execution',
            'parallel', 'concurrent', 'sequential', 'synchronous', 'asynchronous', 'blocking', 'non-blocking',
            'master', 'worker', 'client', 'server', 'manager', 'coordinator', 'controller', 'monitor',
            'startup', 'shutdown', 'restart', 'recovery', 'backup', 'restore', 'migration', 'upgrade',
            'version', 'release', 'build', 'deployment', 'production', 'development', 'testing', 'staging',
            'environment', 'container', 'virtual', 'machine', 'instance', 'image', 'snapshot', 'checkpoint'
        ]
        
        # Technical terms for variety
        self.tech_terms = [
            'slowstart', 'reducer', 'mapper', 'shuffle', 'combiner', 'partitioner', 'serialization',
            'compression', 'codec', 'format', 'schema', 'metadata', 'catalog', 'registry', 'repository',
            'warehouse', 'lake', 'mart', 'cube', 'dimension', 'measure', 'aggregation', 'transformation',
            'extraction', 'loading', 'cleaning', 'validation', 'enrichment', 'integration', 'synchronization',
            'replication', 'sharding', 'partitioning', 'bucketing', 'indexing', 'caching', 'memoization',
            'pagination', 'filtering', 'sorting', 'grouping', 'joining', 'union', 'intersection', 'difference'
        ]
        
        # Numbers and identifiers
        self.numbers = [str(i) for i in range(0, 1000, 5)]
        self.hex_chars = '0123456789abcdef'
    
    def generate_word(self):
        """Generate a single word with weighted probability"""
        rand = random.random()
        if rand < 0.6:  # 60% common words
            return random.choice(self.common_words)
        elif rand < 0.8:  # 20% tech terms
            return random.choice(self.tech_terms)
        elif rand < 0.9:  # 10% numbers
            return random.choice(self.numbers)
        else:  # 10% random strings (simulating IDs, hashes, etc.)
            length = random.randint(4, 12)
            if random.random() < 0.5:
                # Hexadecimal-like strings
                return ''.join(random.choices(self.hex_chars, k=length))
            else:
                # Random alphanumeric
                return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
    
    def generate_line(self, min_words=5, max_words=20):
        """Generate a line of text with random number of words"""
        word_count = random.randint(min_words, max_words)
        words = [self.generate_word() for _ in range(word_count)]
        return ' '.join(words)
    
    def generate_structured_content(self, lines_per_block=100):
        """Generate structured content with some patterns for better MapReduce testing"""
        content = []
        
        # Add some repeated patterns for interesting reduce operations
        patterns = [
            "hadoop cluster node-{} status: active",
            "mapreduce job job_{} mapper task-{} completed",
            "yarn application app_{} resource allocation: {} MB memory",
            "hdfs block blk_{} replicated on datanode-{}",
            "spark executor executor-{} task-{} processing partition-{}"
        ]
        
        for _ in range(lines_per_block):
            if random.random() < 0.3:  # 30% structured patterns
                pattern = random.choice(patterns)
                if '{}' in pattern:
                    # Fill in random numbers for placeholders
                    args = [random.randint(1, 999) for _ in range(pattern.count('{}'))]
                    line = pattern.format(*args)
                else:
                    line = pattern
            else:  # 70% random content
                line = self.generate_line()
            
            content.append(line)
        
        return content
    
    def generate_file(self, filepath, target_size_mb, progress_callback=None):
        """Generate a single file with specified size"""
        target_size_bytes = target_size_mb * 1024 * 1024
        current_size = 0
        lines_written = 0
        
        with open(filepath, 'w', encoding='utf-8') as f:
            while current_size < target_size_bytes:
                # Generate content in blocks for better performance
                content_lines = self.generate_structured_content()
                
                for line in content_lines:
                    f.write(line + '\n')
                    current_size += len(line.encode('utf-8')) + 1  # +1 for newline
                    lines_written += 1
                    
                    if current_size >= target_size_bytes:
                        break
                
                # Progress reporting
                if progress_callback and lines_written % 1000000 == 0:
                    progress_pct = min(100, (current_size / target_size_bytes) * 100)
                    progress_callback(filepath, progress_pct, current_size, lines_written)
        
        return current_size, lines_written
    
    def calculate_optimal_files(self, total_size_mb):
        """Calculate optimal number of files based on dataset size"""
        if total_size_mb <= 5:
            return 2  # Small datasets: 2 files
        elif total_size_mb <= 50:
            return 4  # Medium datasets: 4 files
        elif total_size_mb <= 500:
            return 8  # Large datasets: 8 files
        else:
            return max(16, min(32, total_size_mb // 100))  # Very large: 16-32 files
    
    def generate_dataset(self, total_size_mb, output_dir=None, num_files=None, prefix='data'):
        """Generate complete dataset with multiple files"""
        if output_dir is None:
            if total_size_mb <= 5:
                output_dir = 'input-local'
            elif total_size_mb <= 100:
                output_dir = 'input-small'
            else:
                output_dir = 'input-large'
        
        if num_files is None:
            num_files = self.calculate_optimal_files(total_size_mb)
        
        size_per_file_mb = total_size_mb / num_files
        
        print(f"=== Generating {total_size_mb}MB dataset ===")
        print(f"Output directory: {output_dir}")
        print(f"Number of files: {num_files}")
        print(f"Target size per file: {size_per_file_mb:.2f}MB")
        
        # Create output directory if it doesn't exist
        os.makedirs(output_dir, exist_ok=True)
        
        total_bytes = 0
        total_lines = 0
        start_time = datetime.now()
        
        def progress_callback(filepath, progress_pct, current_size, lines_written):
            print(f"  {os.path.basename(filepath)}: {progress_pct:.1f}% ({current_size/1024/1024:.1f}MB, {lines_written:,} lines)")
        
        for i in range(num_files):
            filename = f"{prefix}{i+1:02d}.txt"
            filepath = os.path.join(output_dir, filename)
            
            print(f"\nGenerating file {i+1}/{num_files}: {filename}")
            file_size, file_lines = self.generate_file(filepath, size_per_file_mb, progress_callback)
            
            total_bytes += file_size
            total_lines += file_lines
            
            actual_size_mb = file_size / 1024 / 1024
            print(f"  ✓ Completed: {actual_size_mb:.2f}MB, {file_lines:,} lines")
        
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        print(f"\n🎉 Dataset generation completed!")
        print(f"Total size: {total_bytes/1024/1024:.3f}MB ({total_bytes:,} bytes)")
        print(f"Total lines: {total_lines:,}")
        print(f"Generation time: {duration:.2f} seconds")
        print(f"Average speed: {(total_bytes/1024/1024)/duration:.2f} MB/s")
        
        # Generate upload script for HDFS
        self.create_hdfs_upload_script(output_dir, num_files, prefix)
        
        return output_dir, total_bytes, total_lines
    
    def create_hdfs_upload_script(self, output_dir, num_files, prefix):
        """Create HDFS upload script"""
        upload_script_path = os.path.join(output_dir, 'upload_to_hdfs.sh')
        
        # Determine default HDFS path based on output directory
        if 'local' in output_dir:
            default_hdfs_path = '/mr_input_local'
        elif 'small' in output_dir:
            default_hdfs_path = '/mr_input_small'
        else:
            default_hdfs_path = '/mr_input'
        
        with open(upload_script_path, 'w') as f:
            f.write('#!/bin/bash\n\n')
            f.write('# Upload generated dataset to HDFS\n')
            f.write('# Usage: ./upload_to_hdfs.sh [hdfs_path]\n\n')
            f.write(f'HDFS_PATH=${{1:-"{default_hdfs_path}"}}\n\n')
            f.write('echo "Creating HDFS directory: $HDFS_PATH"\n')
            f.write('hdfs dfs -mkdir -p "$HDFS_PATH"\n\n')
            f.write('echo "Uploading dataset files..."\n')
            for i in range(num_files):
                filename = f"{prefix}{i+1:02d}.txt"
                f.write(f'hdfs dfs -put -f "{filename}" "$HDFS_PATH/"\n')
            f.write('\necho "Upload completed. Verifying..."\n')
            f.write('hdfs dfs -ls "$HDFS_PATH"\n')
            f.write('hdfs dfs -du -h "$HDFS_PATH"\n')
        
        os.chmod(upload_script_path, 0o755)
        
        print(f"\n📝 Additional files created:")
        print(f"  - HDFS upload script: {upload_script_path}")
        print(f"\n🚀 Next steps:")
        print(f"  1. Upload to HDFS: cd {output_dir} && ./upload_to_hdfs.sh")
        print(f"  2. Run experiments: ./monitor_job.sh 0.3 {default_hdfs_path} /mr_output")

def main():
    parser = argparse.ArgumentParser(
        description='Generate datasets of any size for Hadoop MapReduce experiments',
        epilog="""
Examples:
  python3 generate_data.py 1           # Generate 1MB dataset
  python3 generate_data.py 100         # Generate 100MB dataset  
  python3 generate_data.py 1000        # Generate 1GB dataset
  python3 generate_data.py 50 --files 8 --output my-data --prefix test
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('size', type=int, help='Dataset size in MB')
    parser.add_argument('--files', type=int, help='Number of files to generate (auto-calculated if not specified)')
    parser.add_argument('--output', type=str, help='Output directory (auto-determined if not specified)')
    parser.add_argument('--prefix', type=str, default='data', help='File prefix (default: data)')
    
    args = parser.parse_args()
    
    # Validate input
    if args.size <= 0:
        print("❌ Error: Size must be a positive integer")
        return 1
    
    if args.files is not None and args.files <= 0:
        print("❌ Error: Number of files must be a positive integer")
        return 1
    
    generator = DatasetGenerator()
    
    try:
        output_dir, total_bytes, total_lines = generator.generate_dataset(
            total_size_mb=args.size,
            output_dir=args.output,
            num_files=args.files,
            prefix=args.prefix
        )
        
        return 0
        
    except KeyboardInterrupt:
        print("\n❌ Generation interrupted by user")
        return 1
    except Exception as e:
        print(f"❌ Error generating dataset: {e}")
        return 1

if __name__ == '__main__':
    main()
