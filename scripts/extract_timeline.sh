#!/bin/bash

# Extract Map/Reduce Timeline from Hadoop Job
# Usage: ./extract_timeline.sh <application_id> <slowstart_value> [experiment_id]
# Example: ./extract_timeline.sh application_1764041163594_0018 0.3 20251125_141801

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parameters
APP_ID=${1}
SLOWSTART=${2:-0.3}
EXPERIMENT_ID=${3:-$(date +%Y%m%d_%H%M%S)}

if [ -z "$APP_ID" ]; then
    echo "Error: Application ID is required"
    echo "Usage: $0 <application_id> <slowstart_value> [experiment_id]"
    echo "Example: $0 application_1764041163594_0018 0.3"
    exit 1
fi

# Extract job ID from application ID
JOB_ID=$(echo "$APP_ID" | sed 's/application_/job_/')

# Output files
METRICS_DIR="metrics"
TIMELINE_CSV="${METRICS_DIR}/${EXPERIMENT_ID}_slowstart_${SLOWSTART}_timeline.csv"
SUMMARY_CSV="${METRICS_DIR}/${EXPERIMENT_ID}_slowstart_${SLOWSTART}_timeline_summary.csv"

mkdir -p "${METRICS_DIR}"

echo -e "${BLUE}=== Extracting Timeline for ${APP_ID} ===${NC}"
echo -e "${YELLOW}Job ID: ${JOB_ID}${NC}"
echo -e "${YELLOW}Slowstart: ${SLOWSTART}${NC}"
echo -e "${YELLOW}Experiment ID: ${EXPERIMENT_ID}${NC}"

# JobHistory Server URL (try both possible locations)
HISTORY_SERVER_1="http://hadoop001:19888"
HISTORY_SERVER_2="http://localhost:19888"
HISTORY_SERVER=""

# Detect which history server is available
if curl -s -f "${HISTORY_SERVER_1}/ws/v1/history/mapreduce/jobs" > /dev/null 2>&1; then
    HISTORY_SERVER="${HISTORY_SERVER_1}"
    echo -e "${GREEN}Using JobHistory Server: ${HISTORY_SERVER}${NC}"
elif curl -s -f "${HISTORY_SERVER_2}/ws/v1/history/mapreduce/jobs" > /dev/null 2>&1; then
    HISTORY_SERVER="${HISTORY_SERVER_2}"
    echo -e "${GREEN}Using JobHistory Server: ${HISTORY_SERVER}${NC}"
else
    echo -e "${YELLOW}Warning: JobHistory Server not accessible via REST API${NC}"
    echo -e "${YELLOW}Attempting to use yarn logs instead...${NC}"
    
    # Fallback: Use yarn logs
    echo "experiment_id,slowstart_value,task_id,task_type,start_time,finish_time,elapsed_sec,shuffle_finish,merge_finish,reduce_finish" > "${TIMELINE_CSV}"
    
    yarn logs -applicationId "${APP_ID}" 2>/dev/null | grep -E "(Task.*started|Task.*finished)" | while read line; do
        echo "$line" >> "${TIMELINE_CSV}.log"
    done
    
    echo -e "${YELLOW}Timeline data saved to: ${TIMELINE_CSV}${NC}"
    echo -e "${YELLOW}Note: Using yarn logs fallback. For better results, start JobHistory Server:${NC}"
    echo -e "  ${BLUE}mapred --daemon start historyserver${NC}"
    exit 0
fi

# REST API URL
TASKS_URL="${HISTORY_SERVER}/ws/v1/history/mapreduce/jobs/${JOB_ID}/tasks"

echo -e "${BLUE}Fetching tasks information...${NC}"

# Fetch tasks data
TASKS_JSON=$(curl -s "${TASKS_URL}")

if [ -z "$TASKS_JSON" ] || echo "$TASKS_JSON" | grep -q "error"; then
    echo -e "${YELLOW}Error fetching tasks data from JobHistory Server${NC}"
    echo -e "${YELLOW}Response: ${TASKS_JSON}${NC}"
    exit 1
fi

# Initialize CSV file
echo "experiment_id,slowstart_value,task_id,task_type,start_time,finish_time,elapsed_sec,shuffle_finish_time,merge_finish_time,reduce_finish_time" > "${TIMELINE_CSV}"

# Parse JSON and extract task information
echo "$TASKS_JSON" | python3 -c "
import json
import sys
from datetime import datetime

try:
    data = json.load(sys.stdin)
    tasks = data.get('tasks', {}).get('task', [])
    
    for task in tasks:
        task_id = task.get('id', '')
        task_type = task.get('type', '')
        start_time = task.get('startTime', 0) // 1000  # Convert to seconds
        finish_time = task.get('finishTime', 0) // 1000
        elapsed = task.get('elapsedTime', 0) // 1000
        
        # Get successful attempt details
        successful_attempt = task.get('successfulAttempt', '')
        
        # For reduce tasks, try to get shuffle/merge/reduce times
        shuffle_finish = ''
        merge_finish = ''
        reduce_finish = ''
        
        if task_type == 'REDUCE' and successful_attempt:
            # Fetch attempt details
            attempt_url = '${HISTORY_SERVER}/ws/v1/history/mapreduce/jobs/${JOB_ID}/tasks/' + task_id + '/attempts/' + successful_attempt
            import urllib.request
            try:
                with urllib.request.urlopen(attempt_url, timeout=5) as response:
                    attempt_data = json.loads(response.read())
                    attempt_info = attempt_data.get('taskAttempt', {})
                    shuffle_finish = attempt_info.get('shuffleFinishTime', 0) // 1000 if attempt_info.get('shuffleFinishTime') else ''
                    merge_finish = attempt_info.get('mergeFinishTime', 0) // 1000 if attempt_info.get('mergeFinishTime') else ''
                    # reduce_finish is same as finish_time
                    reduce_finish = finish_time
            except:
                pass
        
        print(f'${EXPERIMENT_ID},${SLOWSTART},{task_id},{task_type},{start_time},{finish_time},{elapsed},{shuffle_finish},{merge_finish},{reduce_finish}')
        
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" >> "${TIMELINE_CSV}"

echo -e "${GREEN}Timeline data extracted: ${TIMELINE_CSV}${NC}"

# Generate summary statistics
echo -e "${BLUE}Generating timeline summary...${NC}"

python3 -c "
import csv
from datetime import datetime

# Read timeline data
map_tasks = []
reduce_tasks = []

with open('${TIMELINE_CSV}', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row['task_type'] == 'MAP':
            map_tasks.append({
                'start': int(row['start_time']),
                'finish': int(row['finish_time']),
                'elapsed': int(row['elapsed_sec'])
            })
        elif row['task_type'] == 'REDUCE':
            reduce_tasks.append({
                'start': int(row['start_time']),
                'finish': int(row['finish_time']),
                'elapsed': int(row['elapsed_sec']),
                'shuffle_finish': int(row['shuffle_finish_time']) if row['shuffle_finish_time'] else 0,
                'merge_finish': int(row['merge_finish_time']) if row['merge_finish_time'] else 0
            })

if not map_tasks:
    print('No map tasks found')
    exit(1)

# Calculate statistics
map_start = min(t['start'] for t in map_tasks)
map_end = max(t['finish'] for t in map_tasks)
map_duration = map_end - map_start

reduce_start = min(t['start'] for t in reduce_tasks) if reduce_tasks else 0
reduce_end = max(t['finish'] for t in reduce_tasks) if reduce_tasks else 0
reduce_duration = reduce_end - reduce_start if reduce_tasks else 0

# Calculate overlap
overlap_duration = 0
if reduce_start > 0 and reduce_start < map_end:
    overlap_duration = map_end - reduce_start

# Calculate parallel efficiency
total_sequential = map_duration + reduce_duration
actual_time = reduce_end - map_start if reduce_end > 0 else map_duration
time_saved = total_sequential - actual_time if total_sequential > actual_time else 0
parallel_efficiency = (time_saved / total_sequential * 100) if total_sequential > 0 else 0

# Calculate when reduce started (as percentage of map completion)
reduce_start_pct = 0
if reduce_start > 0 and map_duration > 0:
    reduce_start_pct = ((reduce_start - map_start) / map_duration) * 100

# Write summary
with open('${SUMMARY_CSV}', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['experiment_id', 'slowstart_value', 'num_map_tasks', 'num_reduce_tasks',
                     'map_start_time', 'map_end_time', 'map_duration_sec',
                     'reduce_start_time', 'reduce_end_time', 'reduce_duration_sec',
                     'overlap_duration_sec', 'reduce_start_at_map_pct', 
                     'total_time_sec', 'time_saved_sec', 'parallel_efficiency_pct'])
    writer.writerow(['${EXPERIMENT_ID}', ${SLOWSTART}, len(map_tasks), len(reduce_tasks),
                     map_start, map_end, map_duration,
                     reduce_start, reduce_end, reduce_duration,
                     overlap_duration, round(reduce_start_pct, 2),
                     actual_time, time_saved, round(parallel_efficiency, 2)])

# Print summary
print(f'\n=== Timeline Summary ===')
print(f'Map Tasks: {len(map_tasks)}')
print(f'Map Duration: {map_duration}s ({datetime.fromtimestamp(map_start).strftime(\"%H:%M:%S\")} -> {datetime.fromtimestamp(map_end).strftime(\"%H:%M:%S\")})')
print(f'')
print(f'Reduce Tasks: {len(reduce_tasks)}')
print(f'Reduce Duration: {reduce_duration}s ({datetime.fromtimestamp(reduce_start).strftime(\"%H:%M:%S\")} -> {datetime.fromtimestamp(reduce_end).strftime(\"%H:%M:%S\")})')
print(f'')
print(f'Reduce started at: {reduce_start_pct:.1f}% of Map execution time')
print(f'Overlap Duration: {overlap_duration}s')
print(f'Parallel Efficiency: {parallel_efficiency:.1f}% time saved')
print(f'')
print(f'Timeline details: ${TIMELINE_CSV}')
print(f'Summary stats: ${SUMMARY_CSV}')
"

echo -e "${GREEN}Timeline extraction completed!${NC}"
