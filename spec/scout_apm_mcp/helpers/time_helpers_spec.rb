require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".format_time" do
    it "formats Time object to ISO 8601 string" do
      time = Time.utc(2025, 1, 15, 12, 30, 45)
      result = described_class.format_time(time)
      expect(result).to eq("2025-01-15T12:30:45Z")
    end

    it "converts non-UTC time to UTC" do
      time = Time.new(2025, 1, 15, 12, 30, 45, "+05:00")
      result = described_class.format_time(time)
      expect(result).to eq("2025-01-15T07:30:45Z")
    end
  end

  describe ".parse_time" do
    it "parses ISO 8601 string with Z suffix" do
      time_str = "2025-01-15T12:30:45Z"
      result = described_class.parse_time(time_str)

      aggregate_failures do
        expect(result).to be_a(Time)
        expect(result.utc?).to be true
        expect(result.year).to eq(2025)
        expect(result.month).to eq(1)
        expect(result.day).to eq(15)
        expect(result.hour).to eq(12)
        expect(result.min).to eq(30)
        expect(result.sec).to eq(45)
      end
    end

    it "parses ISO 8601 string with timezone offset" do
      time_str = "2025-01-15T12:30:45+05:00"
      result = described_class.parse_time(time_str)

      aggregate_failures do
        expect(result).to be_a(Time)
        expect(result.utc?).to be true
        expect(result.hour).to eq(7)
      end
    end

    it "handles lowercase z suffix" do
      time_str = "2025-01-15T12:30:45z"
      result = described_class.parse_time(time_str)

      aggregate_failures do
        expect(result).to be_a(Time)
        expect(result.utc?).to be true
      end
    end
  end

  describe ".make_duration" do
    it "creates duration hash from ISO 8601 strings" do
      from_str = "2025-01-01T00:00:00Z"
      to_str = "2025-01-02T00:00:00Z"
      result = described_class.make_duration(from_str, to_str)

      aggregate_failures do
        expect(result).to be_a(Hash)
        expect(result[:start]).to be_a(Time)
        expect(result[:end]).to be_a(Time)
        expect(result[:start]).to eq(Time.utc(2025, 1, 1, 0, 0, 0))
        expect(result[:end]).to eq(Time.utc(2025, 1, 2, 0, 0, 0))
      end
    end
  end
end
