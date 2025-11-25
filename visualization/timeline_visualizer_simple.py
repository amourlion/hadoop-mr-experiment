#!/usr/bin/env python3
"""
Simple Timeline Visualizer for MapReduce Tasks (No external dependencies)
Creates an HTML-based timeline visualization
"""

import csv
import sys
import os
from datetime import datetime

def convert_timestamp(ts):
    """Convert Unix timestamp to datetime"""
    try:
        return datetime.fromtimestamp(int(ts))
    except (ValueError, TypeError):
        return None

def create_html_timeline(csv_file):
    """Create an HTML timeline visualization"""
    
    # Read CSV data
    tasks = []
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            tasks.append(row)
    
    if not tasks:
        print("No tasks found in CSV file")
        return
    
    # Get experiment info
    experiment_id = tasks[0]['experiment_id']
    slowstart_value = tasks[0]['slowstart_value']
    
    # Convert timestamps and find min time
    min_time = None
    for task in tasks:
        task['start_dt'] = convert_timestamp(task['start_time'])
        task['finish_dt'] = convert_timestamp(task['finish_time'])
        if min_time is None or task['start_dt'] < min_time:
            min_time = task['start_dt']
    
    # Calculate relative times
    max_time = 0
    for task in tasks:
        task['start_rel'] = (task['start_dt'] - min_time).total_seconds()
        task['finish_rel'] = (task['finish_dt'] - min_time).total_seconds()
        task['duration'] = task['finish_rel'] - task['start_rel']
        if task['finish_rel'] > max_time:
            max_time = task['finish_rel']
    
    # Separate MAP and REDUCE tasks
    map_tasks = [t for t in tasks if t['task_type'] == 'MAP']
    reduce_tasks = [t for t in tasks if t['task_type'] == 'REDUCE']
    
    # Sort by start time
    map_tasks.sort(key=lambda x: x['start_rel'])
    reduce_tasks.sort(key=lambda x: x['start_rel'])
    
    # Calculate statistics
    avg_map_duration = sum(t['duration'] for t in map_tasks) / len(map_tasks) if map_tasks else 0
    avg_reduce_duration = sum(t['duration'] for t in reduce_tasks) / len(reduce_tasks) if reduce_tasks else 0
    
    # Generate HTML
    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>MapReduce Timeline - {experiment_id}</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }}
        .header {{
            text-align: center;
            margin-bottom: 30px;
        }}
        h1 {{
            color: #333;
            margin-bottom: 5px;
        }}
        .subtitle {{
            color: #666;
            font-size: 14px;
        }}
        .timeline {{
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .task-row {{
            display: flex;
            align-items: center;
            margin-bottom: 5px;
            height: 35px;
        }}
        .task-label {{
            width: 120px;
            font-weight: bold;
            font-size: 12px;
            text-align: right;
            padding-right: 15px;
        }}
        .task-bar-container {{
            flex: 1;
            position: relative;
            height: 25px;
        }}
        .task-bar {{
            position: absolute;
            height: 100%;
            border-radius: 3px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 10px;
            font-weight: bold;
            color: white;
            border: 1px solid rgba(0,0,0,0.2);
            box-sizing: border-box;
        }}
        .map-task {{
            background-color: #3498db;
        }}
        .reduce-shuffle {{
            background-color: #f39c12;
        }}
        .reduce-merge {{
            background-color: #9b59b6;
        }}
        .reduce-phase {{
            background-color: #2ecc71;
        }}
        .section-divider {{
            height: 20px;
        }}
        .time-axis {{
            display: flex;
            margin-left: 135px;
            margin-top: 10px;
            border-top: 2px solid #333;
            position: relative;
        }}
        .time-marker {{
            position: absolute;
            font-size: 11px;
            color: #666;
            top: 5px;
        }}
        .legend {{
            margin-top: 30px;
            padding: 15px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .legend-title {{
            font-weight: bold;
            margin-bottom: 10px;
        }}
        .legend-items {{
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
        }}
        .legend-item {{
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .legend-color {{
            width: 30px;
            height: 15px;
            border-radius: 3px;
            border: 1px solid rgba(0,0,0,0.2);
        }}
        .stats {{
            margin-top: 20px;
            padding: 15px;
            background: #fff9e6;
            border-radius: 8px;
            border-left: 4px solid #f39c12;
        }}
        .stats-title {{
            font-weight: bold;
            margin-bottom: 10px;
            color: #333;
        }}
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
        }}
        .stat-item {{
            font-size: 13px;
            color: #555;
        }}
        .stat-label {{
            font-weight: bold;
            color: #333;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>MapReduce Task Timeline</h1>
        <div class="subtitle">Experiment: {experiment_id} | Slowstart: {slowstart_value}</div>
    </div>
    
    <div class="timeline">
"""
    
    # Add MAP tasks
    for i, task in enumerate(map_tasks):
        task_num = task['task_id'].split('_')[-1]
        left_percent = (task['start_rel'] / max_time) * 100
        width_percent = (task['duration'] / max_time) * 100
        
        html += f"""        <div class="task-row">
            <div class="task-label">MAP {i+1}</div>
            <div class="task-bar-container">
                <div class="task-bar map-task" style="left: {left_percent:.2f}%; width: {width_percent:.2f}%;">
                    M{task_num} ({task['duration']:.0f}s)
                </div>
            </div>
        </div>
"""
    
    # Add divider
    html += '        <div class="section-divider"></div>\n'
    
    # Add REDUCE tasks
    for i, task in enumerate(reduce_tasks):
        task_num = task['task_id'].split('_')[-1]
        html += f'        <div class="task-row">\n'
        html += f'            <div class="task-label">REDUCE {i+1}</div>\n'
        html += f'            <div class="task-bar-container">\n'
        
        start_rel = task['start_rel']
        
        # Add phases if available
        if task.get('shuffle_finish_time') and task['shuffle_finish_time']:
            shuffle_dt = convert_timestamp(task['shuffle_finish_time'])
            shuffle_rel = (shuffle_dt - min_time).total_seconds()
            shuffle_duration = shuffle_rel - start_rel
            
            left_percent = (start_rel / max_time) * 100
            width_percent = (shuffle_duration / max_time) * 100
            html += f'                <div class="task-bar reduce-shuffle" style="left: {left_percent:.2f}%; width: {width_percent:.2f}%;">Shuffle</div>\n'
            
            current_pos = shuffle_rel
            
            if task.get('merge_finish_time') and task['merge_finish_time']:
                merge_dt = convert_timestamp(task['merge_finish_time'])
                merge_rel = (merge_dt - min_time).total_seconds()
                merge_duration = merge_rel - shuffle_rel
                
                left_percent = (current_pos / max_time) * 100
                width_percent = (merge_duration / max_time) * 100
                html += f'                <div class="task-bar reduce-merge" style="left: {left_percent:.2f}%; width: {width_percent:.2f}%;">Merge</div>\n'
                
                current_pos = merge_rel
                
                if task.get('reduce_finish_time') and task['reduce_finish_time']:
                    reduce_dt = convert_timestamp(task['reduce_finish_time'])
                    reduce_rel = (reduce_dt - min_time).total_seconds()
                    reduce_duration = reduce_rel - merge_rel
                    
                    left_percent = (current_pos / max_time) * 100
                    width_percent = (reduce_duration / max_time) * 100
                    html += f'                <div class="task-bar reduce-phase" style="left: {left_percent:.2f}%; width: {width_percent:.2f}%;">Reduce</div>\n'
        
        html += '            </div>\n'
        html += '        </div>\n'
    
    # Add time axis
    html += '        <div class="time-axis">\n'
    for i in range(0, int(max_time) + 1, max(1, int(max_time / 10))):
        left_percent = (i / max_time) * 100
        html += f'            <div class="time-marker" style="left: {left_percent:.1f}%;">{i}s</div>\n'
    html += '        </div>\n'
    
    html += """    </div>
    
    <div class="legend">
        <div class="legend-title">Legend</div>
        <div class="legend-items">
            <div class="legend-item">
                <div class="legend-color map-task"></div>
                <span>MAP Task</span>
            </div>
            <div class="legend-item">
                <div class="legend-color reduce-shuffle"></div>
                <span>Shuffle Phase</span>
            </div>
            <div class="legend-item">
                <div class="legend-color reduce-merge"></div>
                <span>Merge Phase</span>
            </div>
            <div class="legend-item">
                <div class="legend-color reduce-phase"></div>
                <span>Reduce Phase</span>
            </div>
        </div>
    </div>
    
    <div class="stats">
        <div class="stats-title">Statistics</div>
        <div class="stats-grid">
            <div class="stat-item"><span class="stat-label">MAP Tasks:</span> """ + str(len(map_tasks)) + """</div>
            <div class="stat-item"><span class="stat-label">REDUCE Tasks:</span> """ + str(len(reduce_tasks)) + """</div>
            <div class="stat-item"><span class="stat-label">Total Elapsed:</span> """ + f"{max_time:.1f}s" + """</div>
            <div class="stat-item"><span class="stat-label">Avg MAP Duration:</span> """ + f"{avg_map_duration:.1f}s" + """</div>
"""
    
    if reduce_tasks:
        html += f'            <div class="stat-item"><span class="stat-label">Avg REDUCE Duration:</span> {avg_reduce_duration:.1f}s</div>\n'
    
    html += """        </div>
    </div>
</body>
</html>
"""
    
    # Save HTML file
    output_file = csv_file.replace('.csv', '_timeline.html')
    with open(output_file, 'w') as f:
        f.write(html)
    print(f"HTML timeline saved to: {output_file}")
    
    # Also save to visualization folder
    viz_output = os.path.join('visualization', os.path.basename(csv_file).replace('.csv', '_timeline.html'))
    with open(viz_output, 'w') as f:
        f.write(html)
    print(f"HTML timeline also saved to: {viz_output}")
    print(f"\nOpen the HTML file in a web browser to view the timeline.")

def main():
    if len(sys.argv) < 2:
        print("Usage: python timeline_visualizer_simple.py <csv_file>")
        print("Example: python timeline_visualizer_simple.py metrics/20251125_141801_slowstart_0.3_timeline.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    
    if not os.path.exists(csv_file):
        print(f"Error: File '{csv_file}' not found")
        sys.exit(1)
    
    create_html_timeline(csv_file)

if __name__ == '__main__':
    main()
