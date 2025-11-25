# MapReduce Timeline Visualization

This folder contains tools for visualizing MapReduce task timelines.

## Setup

Install required Python packages:

```bash
pip3 install pandas matplotlib --user
```

## Usage

Run the timeline visualizer with your CSV file:

```bash
python3 visualization/timeline_visualizer.py metrics/20251125_141801_slowstart_0.3_timeline.csv
```

## Features

The timeline visualizer creates a comprehensive visualization showing:

- **MAP Tasks**: Displayed in blue, showing the execution timeline of all map tasks
- **REDUCE Tasks**: Broken down into three phases:
  - **Shuffle Phase** (Orange): Time spent shuffling data from mappers
  - **Merge Phase** (Purple): Time spent merging shuffled data
  - **Reduce Phase** (Green): Time spent in the actual reduce computation

## Output

The script generates two PNG files:
1. In the same directory as the input CSV file
2. In the `visualization/` folder

The visualization includes:
- A Gantt-chart style timeline showing all tasks
- Color-coded phases for reduce tasks
- Statistics box showing:
  - Number of MAP and REDUCE tasks
  - Total elapsed time
  - Average task durations
- Grid lines for easy time reference
- Legend explaining the color coding

## CSV Format

Expected CSV columns:
- `experiment_id`: Experiment identifier
- `slowstart_value`: Slowstart configuration value
- `task_id`: Unique task identifier
- `task_type`: Either "MAP" or "REDUCE"
- `start_time`: Unix timestamp (seconds)
- `finish_time`: Unix timestamp (seconds)
- `elapsed_sec`: Task duration
- `shuffle_finish_time`: (REDUCE only) Shuffle phase completion time
- `merge_finish_time`: (REDUCE only) Merge phase completion time
- `reduce_finish_time`: (REDUCE only) Reduce phase completion time

## Example

```bash
# Generate timeline visualization
python3 visualization/timeline_visualizer.py metrics/20251125_141801_slowstart_0.3_timeline.csv

# Output will be saved to:
# - metrics/20251125_141801_slowstart_0.3_timeline_timeline.png
# - visualization/20251125_141801_slowstart_0.3_timeline_timeline.png
