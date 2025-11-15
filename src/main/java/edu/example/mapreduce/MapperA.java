package edu.example.mapreduce;

import org.apache.hadoop.io.*;
import org.apache.hadoop.mapreduce.Mapper;

import java.io.IOException;

public class MapperA extends Mapper<LongWritable, Text, Text, IntWritable> {

    private final static IntWritable one = new IntWritable(1);
    private final Text word = new Text();

    @Override
    protected void map(LongWritable key, Text value, Context context)
            throws IOException, InterruptedException {

        String line = value.toString();
        String[] tokens = line.split("\\s+");

        for (String token : tokens) {
            if (token.isEmpty())
                continue;
            word.set(token);
            context.write(word, one);
        }
    }
}
