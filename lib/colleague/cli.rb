# frozen_string_literal: true

require 'thor'
require 'fileutils'
require_relative 'parser'
require_relative 'agent'

module Colleague
  # CLI class handles the command-line interface
  class CLI < Thor
    desc 'parse FILE OUTPUT', 'Parse text content from a file and write to an output file'
    def parse(file, output)
      # Create output directory if it doesn't exist
      output_dir = File.dirname(output)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      content = Parser.extract_text(file)
      File.write(output, content)
      puts "Content parsed and written to #{output}"
    end

    desc 'summarize FILE [OUTPUT]', 'Extract and summarize text content from a file'
    option :model, type: :string, desc: 'LLM model to use for summarization'
    option :max_tokens, type: :numeric, default: 300, desc: 'Maximum tokens for the summary'
    def summarize(file, output = nil)
      # Extract text from the file
      content = Parser.extract_text(file)

      # Generate summary
      summary = Agent.summarize(content, options)

      if output
        # Create output directory if it doesn't exist
        output_dir = File.dirname(output)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Write summary to output file
        File.write(output, summary)
        puts "Summary written to #{output}"
      else
        # Print summary to console
        puts "\nSummary:\n#{summary}"
      end
    end

    desc 'ask FILE QUERY [OUTPUT]', 'Ask a question about the content of a file'
    option :model, type: :string, desc: 'LLM model to use for analysis'
    option :max_tokens, type: :numeric, default: 500, desc: 'Maximum tokens for the response'
    def ask(file, query, output = nil)
      # Extract text from the file
      content = Parser.extract_text(file)

      # Generate analysis based on query
      analysis = Agent.analyze(content, query, options)

      if output
        # Create output directory if it doesn't exist
        output_dir = File.dirname(output)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        # Write analysis to output file
        File.write(output, analysis)
        puts "Analysis written to #{output}"
      else
        # Print analysis to console
        puts "\nAnalysis:\n#{analysis}"
      end
    end

    desc 'console', 'Start an IRB session with Colleague preloaded'
    def console
      puts "Starting Colleague console (IRB)"
      puts "Colleague version: #{Colleague::VERSION}"

      # Preload TextAnalyzer for easy testing
      require 'irb'
      require 'irb/completion'

      ARGV.clear # Clear arguments to avoid confusing IRB
      IRB.start
    end
  end
end
