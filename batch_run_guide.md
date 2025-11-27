开启jobserver
mapred --daemon start historyserver

清理远端./scripts/remote_clean_metrics.sh 

清理本地./scripts/cleanup_disk.sh 

打开./gemini_monitor_plus.sh

打开远端的./gemini_monitor_plus.sh和./collect_metrics.sh

运行任务./scripts/batch_experiment.sh /mr_input_1gb /mr_output_batch_1gb

收集远端数据
./scripts/collect_remote_metrics.sh 

打包数据
./scripts/package_results.sh
