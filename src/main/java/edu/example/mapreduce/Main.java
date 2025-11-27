package edu.example.mapreduce;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.mapreduce.Job;

import org.apache.hadoop.io.*;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class Main {

    public static void main(String[] args) throws Exception {

        // 调试：打印一下实际收到的参数
        System.out.println("==== Main args ====");
        System.out.println("args.length = " + args.length);
        for (int i = 0; i < args.length; i++) {
            System.out.println("args[" + i + "] = " + args[i]);
        }
        System.out.println("===================");

        // 给一个“默认路径”，即使参数不对也能跑
        String inputPath;
        String outputPath;

        if (args.length >= 2) {
            inputPath = args[0];
            outputPath = args[1];
        } else {
            System.err.println("WARN: 参数数量不是 2，使用默认 HDFS 路径");
            inputPath = "/mr_input";
            outputPath = "/mr_output_01";
        }

        Configuration conf = new Configuration();

        // ⭐ 实验 A：控制 Reduce 启动时机
        conf.setFloat("mapreduce.job.reduce.slowstart.completedmaps", 1.0f);
        
        // 设置内存配置，确保不超过集群限制
        // conf.set("mapreduce.map.memory.mb", "3072");
        // conf.set("mapreduce.reduce.memory.mb", "6144");
        // conf.set("mapreduce.map.java.opts", "-Xmx2458m");
        // conf.set("mapreduce.reduce.java.opts", "-Xmx4915m");

        Job job = Job.getInstance(conf, "ReduceStartExperiment");
        job.setJarByClass(Main.class);

        job.setNumReduceTasks(4);  // 使用4个Reduce任务分担压力


        job.setMapperClass(MapperA.class);
        job.setReducerClass(ReducerA.class);

        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        FileInputFormat.addInputPath(job, new Path(inputPath));
        FileOutputFormat.setOutputPath(job, new Path(outputPath));

        boolean success = job.waitForCompletion(true);
        System.exit(success ? 0 : 1);
    }
}
