require "spec_helper"

RSpec.describe ScoutApmMcp::Helpers do
  describe ".parse_range" do
    it "parses 30min range" do
      result = described_class.parse_range("30min")
      expect(result).to eq(1800)
    end

    it "parses 60min range" do
      result = described_class.parse_range("60min")
      expect(result).to eq(3600)
    end

    it "parses 3hrs range" do
      result = described_class.parse_range("3hrs")
      expect(result).to eq(10800)
    end

    it "parses 6hrs range" do
      result = described_class.parse_range("6hrs")
      expect(result).to eq(21600)
    end

    it "parses 12hrs range" do
      result = described_class.parse_range("12hrs")
      expect(result).to eq(43200)
    end

    it "parses 1day range" do
      result = described_class.parse_range("1day")
      expect(result).to eq(86400)
    end

    it "parses 3days range" do
      result = described_class.parse_range("3days")
      expect(result).to eq(259200)
    end

    it "handles plural forms" do
      aggregate_failures do
        expect(described_class.parse_range("30mins")).to eq(1800)
        expect(described_class.parse_range("1hour")).to eq(3600)
        expect(described_class.parse_range("2hours")).to eq(7200)
      end
    end

    it "handles case-insensitive input" do
      aggregate_failures do
        expect(described_class.parse_range("30MIN")).to eq(1800)
        expect(described_class.parse_range("1DAY")).to eq(86400)
        expect(described_class.parse_range("3Hrs")).to eq(10800)
      end
    end

    it "handles whitespace" do
      aggregate_failures do
        expect(described_class.parse_range(" 30min ")).to eq(1800)
        expect(described_class.parse_range("1 day")).to eq(86400)
      end
    end

    it "returns nil for nil input" do
      expect(described_class.parse_range(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.parse_range("")).to be_nil
    end

    it "raises error for invalid format" do
      expect { described_class.parse_range("invalid") }.to raise_error(ArgumentError, /Invalid range format/)
    end

    it "raises error for unsupported time units" do
      expect { described_class.parse_range("30weeks") }.to raise_error(ArgumentError, /Invalid range format/)
    end
  end

  describe ".calculate_range" do
    it "calculates range ending at now when to is nil" do
      freeze_time = Time.utc(2025, 1, 15, 12, 0, 0)
      allow(Time).to receive(:now).and_return(freeze_time)

      result = described_class.calculate_range(range: "1day")

      aggregate_failures do
        expect(result[:from]).to eq("2025-01-14T12:00:00Z")
        expect(result[:to]).to eq("2025-01-15T12:00:00Z")
      end
    end

    it "calculates range ending at specified time" do
      to_time = "2025-01-15T12:00:00Z"
      result = described_class.calculate_range(range: "3hrs", to: to_time)

      aggregate_failures do
        expect(result[:from]).to eq("2025-01-15T09:00:00Z")
        expect(result[:to]).to eq(to_time)
      end
    end

    it "returns nil from when range is nil" do
      result = described_class.calculate_range(range: nil, to: "2025-01-15T12:00:00Z")

      aggregate_failures do
        expect(result[:from]).to be_nil
        expect(result[:to]).to eq("2025-01-15T12:00:00Z")
      end
    end

    it "returns nil from when range is empty" do
      result = described_class.calculate_range(range: "", to: "2025-01-15T12:00:00Z")

      aggregate_failures do
        expect(result[:from]).to be_nil
        expect(result[:to]).to eq("2025-01-15T12:00:00Z")
      end
    end
  end
end
