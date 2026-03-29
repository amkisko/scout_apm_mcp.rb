require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".get_job_id" do
    it "returns job_id string key" do
      expect(described_class.get_job_id({"job_id" => "encoded"})).to eq("encoded")
    end

    it "returns job_id symbol key" do
      expect(described_class.get_job_id({job_id: "sym"})).to eq("sym")
    end

    it "returns empty string when missing" do
      expect(described_class.get_job_id({"name" => "Worker"})).to eq("")
    end
  end
end
