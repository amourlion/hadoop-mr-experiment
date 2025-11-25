#!/usr/bin/env python3
"""
Timeline Visualizer for MapReduce Tasks
Visualizes the start and finish times of MAP and REDUCE tasks
"""

import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend for server environments
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from datetime import datetime
import sys
import os

def convert_timestamp(ts):
    """Convert Unix timestamp (in seconds) to datetime"""
    try:
        return datetime.fromtimestamp(int(ts))
    except (ValueError, TypeError):
        return None

def create_timeline_visualization(csv_file):
    """
    Create a timeline visualization from the CSV file
    
    Args:
        csv_file: Path to the CSV file containing task timeline data
    """
    # Read the CSV file
    df = pd.read_csv(csv_file)
    
    # Convert timestamps to datetime
    df['start_dt'] = df['start_time'].apply(convert_timestamp)
    df['finish_dt'] = df['finish_time'].apply(convert_timestamp)
    
    # Get the minimum start time as reference point
    min_time = df['start_dt'].min()
    
    # Calculate relative times in seconds from the start
    df['start_rel'] = (df['start_dt'] - min_time).dt.total_seconds()
    df['finish_rel'] = (df['finish_dt'] - min_time).dt.total_seconds()
    df['duration'] = df['finish_rel'] - df['start_rel']
    
    # Separate MAP and REDUCE tasks
    map_tasks = df[df['task_type'] == 'MAP'].copy()
    reduce_tasks = df[df['task_type'] == 'REDUCE'].copy()
    
    # Sort by start time
    map_tasks = map_tasks.sort_values('start_rel')
    reduce_tasks = reduce_tasks.sort_values('start_rel')
    
    # Create figure
    fig, ax = plt.subplots(figsize=(14, 8))
    
    # Color scheme
    map_color = '#3498db'      # Blue for MAP tasks
    reduce_color = '#e74c3c'   # Red for REDUCE tasks
    shuffle_color = '#f39c12'  # Orange for shuffle phase
    merge_color = '#9b59b6'    # Purple for merge phase
    reduce_phase_color = '#2ecc71'  # Green for reduce phase
    
    # Plot MAP tasks
    y_position = 0
    for idx, row in map_tasks.iterrows():
        ax.barh(y_position, row['duration'], left=row['start_rel'], 
                height=0.8, color=map_color, alpha=0.8, edgecolor='black', linewidth=0.5)
        # Add task label
        task_label = row['task_id'].split('_')[-1]
        ax.text(row['start_rel'] + row['duration']/2, y_position, 
                f"M{task_label}", ha='center', va='center', fontsize=8, fontweight='bold')
        y_position += 1
    
    # Add gap between MAP and REDUCE tasks
    y_position += 1
    
    # Plot REDUCE tasks with phases
    reduce_start_y = y_position
    for idx, row in reduce_tasks.iterrows():
        # Calculate phase durations
        start_rel = row['start_rel']
        
        if pd.notna(row['shuffle_finish_time']):
            shuffle_dt = convert_timestamp(row['shuffle_finish_time'])
            shuffle_rel = (shuffle_dt - min_time).total_seconds()
            shuffle_duration = shuffle_rel - start_rel
            
            # Shuffle phase
            ax.barh(y_position, shuffle_duration, left=start_rel, 
                    height=0.8, color=shuffle_color, alpha=0.8, edgecolor='black', linewidth=0.5)
            ax.text(start_rel + shuffle_duration/2, y_position, 
                    'Shuffle', ha='center', va='center', fontsize=7)
            
            current_pos = shuffle_rel
            
            if pd.notna(row['merge_finish_time']):
                merge_dt = convert_timestamp(row['merge_finish_time'])
                merge_rel = (merge_dt - min_time).total_seconds()
                merge_duration = merge_rel - shuffle_rel
                
                # Merge phase
                ax.barh(y_position, merge_duration, left=current_pos, 
                        height=0.8, color=merge_color, alpha=0.8, edgecolor='black', linewidth=0.5)
                ax.text(current_pos + merge_duration/2, y_position, 
                        'Merge', ha='center', va='center', fontsize=7)
                
                current_pos = merge_rel
                
                if pd.notna(row['reduce_finish_time']):
                    reduce_dt = convert_timestamp(row['reduce_finish_time'])
                    reduce_rel = (reduce_dt - min_time).total_seconds()
                    reduce_duration = reduce_rel - merge_rel
                    
                    # Reduce phase
                    ax.barh(y_position, reduce_duration, left=current_pos, 
                            height=0.8, color=reduce_phase_color, alpha=0.8, edgecolor='black', linewidth=0.5)
                    ax.text(current_pos + reduce_duration/2, y_position, 
                            'Reduce', ha='center', va='center', fontsize=7)
        else:
            # If no phase information, just plot the full reduce task
            ax.barh(y_position, row['duration'], left=row['start_rel'], 
                    height=0.8, color=reduce_color, alpha=0.8, edgecolor='black', linewidth=0.5)
        
        # Add task label on the left
        task_label = row['task_id'].split('_')[-1]
        ax.text(-2, y_position, f"R{task_label}", ha='right', va='center', fontsize=8, fontweight='bold')
        y_position += 1
    
    # Set labels and title
    ax.set_xlabel('Time (seconds from start)', fontsize=12, fontweight='bold')
    ax.set_ylabel('Tasks', fontsize=12, fontweight='bold')
    
    # Get experiment info
    experiment_id = df['experiment_id'].iloc[0]
    slowstart_value = df['slowstart_value'].iloc[0]
    
    ax.set_title(f'MapReduce Task Timeline\nExperiment: {experiment_id} | Slowstart: {slowstart_value}', 
                 fontsize=14, fontweight='bold', pad=20)
    
    # Set y-axis labels
    y_ticks = list(range(len(map_tasks))) + [reduce_start_y - 1] + list(range(reduce_start_y, reduce_start_y + len(reduce_tasks)))
    y_labels = [f"MAP {i+1}" for i in range(len(map_tasks))] + [''] + [f"REDUCE {i+1}" for i in range(len(reduce_tasks))]
    ax.set_yticks(y_ticks)
    ax.set_yticklabels(y_labels, fontsize=9)
    
    # Add grid
    ax.grid(axis='x', alpha=0.3, linestyle='--')
    ax.set_axisbelow(True)
    
    # Create legend
    legend_elements = [
        mpatches.Patch(color=map_color, label='MAP Task', alpha=0.8),
        mpatches.Patch(color=shuffle_color, label='Shuffle Phase', alpha=0.8),
        mpatches.Patch(color=merge_color, label='Merge Phase', alpha=0.8),
        mpatches.Patch(color=reduce_phase_color, label='Reduce Phase', alpha=0.8),
    ]
    ax.legend(handles=legend_elements, loc='upper right', fontsize=10)
    
    # Add statistics text box
    total_map_time = map_tasks['duration'].sum()
    total_reduce_time = reduce_tasks['duration'].sum()
    total_elapsed = df['finish_rel'].max()
    
    stats_text = f'Statistics:\n'
    stats_text += f'MAP Tasks: {len(map_tasks)}\n'
    stats_text += f'REDUCE Tasks: {len(reduce_tasks)}\n'
    stats_text += f'Total Elapsed: {total_elapsed:.1f}s\n'
    stats_text += f'Avg MAP Duration: {map_tasks["duration"].mean():.1f}s\n'
    if len(reduce_tasks) > 0:
        stats_text += f'Avg REDUCE Duration: {reduce_tasks["duration"].mean():.1f}s'
    
    ax.text(0.02, 0.98, stats_text, transform=ax.transAxes, 
            fontsize=9, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    plt.tight_layout()
    
    # Save to visualization/pics folder
    os.makedirs('visualization/pics', exist_ok=True)
    output_file = os.path.join('visualization/pics', 
                               os.path.basename(csv_file).replace('.csv', '_timeline.png'))
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Timeline visualization saved to: {output_file}")
    
    plt.close()

def main():
    """Main function"""
    if len(sys.argv) < 2:
        print("Usage: python timeline_visualizer.py <csv_file>")
        print("Example: python timeline_visualizer.py metrics/20251125_141801_slowstart_0.3_timeline.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    
    if not os.path.exists(csv_file):
        print(f"Error: File '{csv_file}' not found")
        sys.exit(1)
    
    create_timeline_visualization(csv_file)

if __name__ == '__main__':
    main()
