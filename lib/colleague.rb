# frozen_string_literal: true

# Main entry point for the Colleague library
require 'ruby_llm'
require 'dotenv'
require_relative 'colleague/parser'
require_relative 'colleague/agent'
require_relative 'colleague/cli'

# Load environment variables from .env file
Dotenv.load

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)

  config.default_model = "gpt-4o-mini"
  config.default_embedding_model = "text-embedding-3-small"
  config.default_image_model = "dall-e-3"

  config.request_timeout = 120
  config.max_retries = 3
end

module Colleague
  # Version number
  VERSION = '0.1.0'
end
