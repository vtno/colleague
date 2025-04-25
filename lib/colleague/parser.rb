# frozen_string_literal: true

require 'pdf-reader'
require 'zip'
require 'nokogiri'
require 'docx'

module Colleague
  # Parser module handles text extraction from different file formats
  module Parser
    class << self
      def extract_text(file)
        text = case File.extname(file).downcase
        when '.pdf'
          extract_pdf_text(file)
        when '.docx'
          extract_docx_text(file)
        when '.pptx'
          extract_pptx_text(file)
        when '.txt'
          File.read(file)
        when '.html'
          extract_html_text(file)
        else
          raise "Unsupported file type: #{File.extname(file)}"
        end

        # Clean the text by replacing line breaks, multiple spaces, and tabs with a single space
        clean_text(text)
      end

      private

      def clean_text(text)
        # Replace line breaks, tabs, and multiple spaces with a single space
        cleaned = text.gsub(/\s+/, ' ')
        # Trim leading and trailing whitespace
        cleaned.strip
      end

      def extract_pdf_text(file)
        reader = PDF::Reader.new(file)
        reader.pages.map(&:text).join("\n")
      end

      def extract_docx_text(file)
        doc = Docx::Document.open(file)
        doc.paragraphs.map(&:text).join("\n")
      end

      def extract_pptx_text(file)
        text = ''
        Zip::File.open(file) do |zip_file|
          # PPTX files store slide content in ppt/slides/slide*.xml files
          zip_file.glob('ppt/slides/slide*.xml').sort.each do |entry|
            content = entry.get_input_stream.read
            doc = Nokogiri::XML(content)
            # Extract text from all text elements in the slide
            slide_text = doc.xpath('//a:t',
                                   'a' => 'http://schemas.openxmlformats.org/drawingml/2006/main').map(&:text).join(' ')
            text += "#{slide_text}\n\n" if slide_text.strip.length.positive?
          end
        end
        text
      end

      def extract_html_text(file)
        html = File.read(file)
        doc = Nokogiri::HTML(html)
        doc.text
      end
    end
  end
end
