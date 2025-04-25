# frozen_string_literal: true

require 'rspec'
require_relative '../lib/colleague/parser'
require 'fileutils'

describe Colleague::Parser do
  describe '#extract_text' do
    it 'extracts text from a txt file' do
      input = 'spec/fixtures/sample.txt'
      extracted_text = Colleague::Parser.extract_text(input)
      expect(extracted_text).to be_a(String)
      expect(extracted_text.length).to be > 0
      expect(extracted_text).to include('Sample text')
    end

    it 'extracts text from a pptx file' do
      input = 'spec/fixtures/sample.pptx'
      extracted_text = Colleague::Parser.extract_text(input)
      expect(extracted_text).to be_a(String)
      expect(extracted_text.length).to be > 0
      expect(extracted_text).to include('Sample PowerPoint File')
    end

    it 'extracts text from a pdf file' do
      input = 'spec/fixtures/sample.pdf'
      extracted_text = Colleague::Parser.extract_text(input)
      expect(extracted_text).to be_a(String)
      expect(extracted_text.length).to be > 0
      expect(extracted_text).to include('Fun fun fun')
    end

    it 'raises an error for unsupported file types' do
      expect do
        Colleague::Parser.extract_text('spec/fixtures/nonexistent.xyz')
      end.to raise_error(/Unsupported file type: .xyz/)
    end
  end
end
