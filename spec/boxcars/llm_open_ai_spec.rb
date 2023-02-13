# frozen_string_literal: true

RSpec.describe Boxcars::LLMOpenAI do
  context "without an open ai api key" do
    it "raises an error" do
      expect do
        described_class.new.client(prompt: "write a poem", openai_access_token: nil)
      end.to raise_error(Boxcars::ConfigurationError)
    end

    it "can write a short poem" do
      VCR.use_cassette("llm_open_ai") do
        expect(described_class.new.run("write a haiku about love")).to eq("Love is a flower\nBlooming eternal beauty\nPure and divine love")
      end
    end
  end
end
