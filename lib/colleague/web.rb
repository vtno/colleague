# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'tempfile'
require 'fileutils'
require 'securerandom'
require 'json'
require 'net/http'
require 'async'
require_relative '../colleague'

module Colleague
  # Web interface for Colleague
  class Web < Sinatra::Base
    configure :development do
      register Sinatra::Reloader
    end

    # Configure sessions with fixed secret from .env
    use Rack::Session::Cookie,
        key: 'colleague.session',
        secret: ENV.fetch('SESSION_SECRET', "a secret"),
        expire_after: 86400 # 24 hours

    # Enable flash messages
    register Sinatra::Flash

    set :root, File.dirname(__FILE__) + '/web'
    set :public_folder, proc { File.join(root, 'public') }
    set :views, proc { File.join(root, 'views') }
    set :upload_folder, proc { File.join(root, 'uploads') }
    set :text_storage_folder, proc { File.join(root, 'text_storage') }

    # Ensure upload and text storage directories exist
    FileUtils.mkdir_p(settings.upload_folder) unless Dir.exist?(settings.upload_folder)
    FileUtils.mkdir_p(settings.text_storage_folder) unless Dir.exist?(settings.text_storage_folder)

    # Create an answers storage folder for storing conversation answers
    set :answers_storage_folder, proc { File.join(root, 'answers_storage') }
    FileUtils.mkdir_p(settings.answers_storage_folder) unless Dir.exist?(settings.answers_storage_folder)

    # Initialize the analyzer
    @@analyzer = Colleague::Agent::TextAnalyzer.new

    # Home page - Upload form
    get '/' do
      erb :index
    end

    # Handle file upload
    post '/upload' do
      if params[:file] && params[:file][:tempfile]
        begin
          # Save the uploaded file
          filename = params[:file][:filename]
          file_path = File.join(settings.upload_folder, filename)

          File.open(file_path, 'wb') do |file|
            file.write(params[:file][:tempfile].read)
          end

          # Extract text from the file
          extracted_text = Colleague::Parser.extract_text(file_path)

          # Generate a unique ID for this text
          text_id = SecureRandom.uuid

          # Save the extracted text to a file
          text_file_path = File.join(settings.text_storage_folder, "#{text_id}.txt")
          File.write(text_file_path, extracted_text)

          # Store only the filename and text_id in the session (small data)
          session[:filename] = filename
          session[:text_id] = text_id

          # Initialize an empty conversation history
          session[:conversation] = []

          redirect '/ask'
        rescue => e
          flash[:error] = "Error processing file: #{e.message}"
          redirect '/'
        end
      else
        flash[:error] = "No file selected"
        redirect '/'
      end
    end

    # Ask form page
    get '/ask' do
      @filename = session[:filename]
      # Load conversation with answers from files
      @conversation = load_conversation_with_answers(session[:conversation] || [])
      erb :ask
    end

    # Handle question submission
    post '/ask' do
      question = params[:question]
      text_id = session[:text_id]

      if text_id && question && !question.empty?
        # Get the text from the stored file
        text_file_path = File.join(settings.text_storage_folder, "#{text_id}.txt")

        if File.exist?(text_file_path)
          begin
            # Store question for the streaming endpoint to use
            session[:current_question] = question

            # Initialize conversation array if it doesn't exist
            session[:conversation] ||= []

            # Generate a unique ID for this answer
            answer_id = SecureRandom.uuid

            # Add a new entry for this question with the answer_id reference
            session[:conversation] << {
              question: question,
              answer_id: answer_id,
              timestamp: Time.now.to_i
            }

            # Record the index of the current question being answered
            session[:current_question_index] = session[:conversation].length - 1

            # Store the answer_id for the streaming endpoint to use
            session[:current_answer_id] = answer_id

            # Render the result page which will load the streaming content
            @question = question
            @filename = session[:filename]
            @conversation = load_conversation_with_answers(session[:conversation])
            erb :result
          rescue => e
            flash[:error] = e.message
            redirect '/ask'
          end
        else
          flash[:error] = "Document data not found. Please upload your document again."
          redirect '/'
        end
      else
        flash[:error] = "Please provide a question about your document."
        redirect '/ask'
      end
    end

    # SSE endpoint for streaming analysis
    get '/stream_analysis' do
      content_type 'text/event-stream'
      headers 'Cache-Control' => 'no-cache'
      headers 'Connection' => 'keep-alive'

      # Get the current question and text_id from session
      question = session[:current_question]
      text_id = session[:text_id]
      answer_id = session[:current_answer_id]

      stream do |out|
        begin
          if text_id && question && answer_id
            text_file_path = File.join(settings.text_storage_folder, "#{text_id}.txt")

            if File.exist?(text_file_path)
              text = File.read(text_file_path)

              # Create a variable to store the full answer
              full_answer = ""

              # Use block syntax with the analyzer
              @@analyzer.analyze(text, question) do |chunk|
                if chunk && !chunk.empty?
                  # Collect the full answer
                  full_answer += chunk

                  # Escape any newlines in the chunk to maintain proper SSE format
                  escaped_chunk = chunk.gsub("\n", "\\n")
                  out << "data: #{escaped_chunk}\n\n"

                  # Save the answer to a file after each chunk
                  # This ensures we have the latest answer even if connection drops
                  # Trim the answer to remove any unnecessary whitespace
                  trimmed_answer = full_answer.strip
                  answer_file_path = File.join(settings.answers_storage_folder, "#{answer_id}.txt")
                  File.write(answer_file_path, trimmed_answer)
                end
              end
            else
              out << "data: Error: Document not found\n\n"
            end
          else
            out << "data: Error: Missing question, document, or answer ID\n\n"
          end
        rescue => e
          out << "data: Error: #{e.message}\n\n"
        ensure
          # Send the done message
          out << "data: [DONE]\n\n"
        end
      end
    end

    # Add a cleanup method for old text files (optional)
    def self.cleanup_old_text_files(max_age_hours = 24)
      # Clean up old text and answer files
      [settings.text_storage_folder, settings.answers_storage_folder].each do |folder|
        Dir.glob(File.join(folder, "*.txt")).each do |file|
          if File.mtime(file) < Time.now - (max_age_hours * 3600)
            File.unlink(file)
          end
        end
      end
    end

    # Helper method to load conversation with answers from files
    def load_conversation_with_answers(conversation)
      conversation.map do |item|
        # Only try to load answer if we have an answer_id
        if item[:answer_id]
          answer_file_path = File.join(settings.answers_storage_folder, "#{item[:answer_id]}.txt")
          if File.exist?(answer_file_path)
            # Load the answer from file
            answer = File.read(answer_file_path)
            item.merge(answer: answer)
          else
            # If answer file doesn't exist yet, just return the item as is
            item
          end
        elsif item[:answer]
          # For backward compatibility with existing session data
          item
        else
          # No answer yet
          item
        end
      end
    end
  end
end
