# frozen_string_literal: true

require 'ruby_llm'

module Colleague
  # Agent module provides LLM-based summarization and analysis
  module Agent
    class TextAnalyzer
      def initialize
        @summarizer = RubyLLM.chat(model: "gpt-3.5-turbo")
        @summarizer.with_instructions("You are to summarize or analyze the text provided to you. Do nothing else. Deline politely.")

        @analyzer = RubyLLM.chat(model: "gpt-4o-mini")
        @analyzer.with_instructions("Analyze the text provided to you and answer the question. If asked to do something related to the text try helping. for example, answer the question from the text itself. Do nothing else. Deline politely.")
      end

      def summarize(text)
        result = ""
        begin
          @summarizer.ask(text) do |chunk|
            result += chunk.content
            print chunk.content
          end
          return result
        rescue => e
          raise "Error during summarization: #{e.message}"
        end
      end

      def analyze(text, query)
        result = ""
        begin
          question_with_context = "context: #{text}\nquestion: #{query}"
          @analyzer.ask(question_with_context) do |chunk|
            # Ensure content is not nil before using it
            content = chunk&.content || ""
            result += content
            print content if !content.empty?

            # Yield to the block if one is given and content is not empty
            yield(content) if block_given? && !content.empty?
          end

          result
        rescue => e
          raise "Error during analysis: #{e.message}"
        end
      end
    end
  end
end
