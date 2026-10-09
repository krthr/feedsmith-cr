require "./spec_helper"

# Checked-in goldens come from running the unmodified TypeScript implementation.
module UpstreamParity
  extend self

  def normalize(value : Feedsmith::Value) : JSON::Any
    case raw = value.raw
    when Nil, Bool, Int64, String
      JSON::Any.new(raw)
    when Float64
      if raw.finite?
        JSON::Any.new(raw)
      else
        marker = raw.nan? ? "NaN" : raw > 0 ? "Infinity" : "-Infinity"
        JSON::Any.new({"$number" => JSON::Any.new(marker)})
      end
    when Time
      JSON::Any.new(raw.to_utc.to_s("%Y-%m-%dT%H:%M:%S.%LZ"))
    when Array(Feedsmith::Value)
      JSON::Any.new(raw.map { |item| normalize(item) })
    when Hash(String, Feedsmith::Value)
      fields = {} of String => JSON::Any
      raw.each { |key, item| fields[key] = normalize(item) unless item.null? }
      JSON::Any.new(fields)
    else
      JSON::Any.new(nil)
    end
  end

  def restore(value : JSON::Any) : Feedsmith::Value
    case raw = value.raw
    when Hash(String, JSON::Any)
      if date = raw["$date"]?
        return Feedsmith::Value.new(Time.parse(date.as_s, "%Y-%m-%dT%H:%M:%S.%LZ", Time::Location::UTC))
      elsif raw["$invalid_date"]?
        # Crystal has no invalid Time value. Nil gives the same omission
        # behavior at every upstream generation boundary tested here.
        return Feedsmith::Value.null
      elsif marker = raw["$number"]?
        number = case marker.as_s
                 when "NaN" then Float64::NAN
                 when "Infinity" then Float64::INFINITY
                 else -Float64::INFINITY
                 end
        return Feedsmith::Value.new(number)
      elsif callback = raw["$callback"]?
        kind = callback.as_s
        message = raw["message"]?.try(&.as_s) || "Date parser failed"
        return Feedsmith::Value.function do |args|
          raise Exception.new(message) if kind == "throw"
          parsed_time = Feedsmith::Common.parse_time(args[0])
          next Feedsmith::Value.null unless parsed_time
          if kind == "timestamp"
            Feedsmith::Value.new(parsed_time.to_unix_ms)
          else
            Feedsmith::Value.new(parsed_time)
          end
        end
      elsif native = raw["$native_callback"]?
        name = native.as_s
        return Feedsmith::Value.function { |args| Feedsmith::Common.call(name, args) }
      elsif raw["$unsupported_callback"]?
        return Feedsmith::Value.function { |_| Feedsmith::Value.null }
      end
      Feedsmith::Value.object(raw.to_h { |key, item| {key, restore(item)} })
    when Array(JSON::Any)
      Feedsmith::Value.array(raw.map { |item| restore(item) })
    else
      Feedsmith::Value.from(value)
    end
  end

  def dispatch(record : JSON::Any) : Feedsmith::Value
    path = record["path"].as_s
    name = record["function"].as_s
    args = record["args"].as_a.map { |item| restore(item) }
    return Feedsmith::Common.call(name, args) if path == "src/common/utils.ts"
    if path.ends_with?("/utils.ts")
      result = Feedsmith::Rules.call(path, name, args)
      if invocation = record.as_h["invoke_args"]?
        result = result.call(invocation.as_a.map { |item| restore(item) })
      end
      return result
    end
    input = args[0]? || Feedsmith::Value.null
    options = args[1]? || Feedsmith::Value.object
    case path
    when "src/common/detect.ts"
      Feedsmith::Value.from(Feedsmith.detect_feed(input))
    when "src/common/parse.ts"
      result = Feedsmith.parse_feed(input, options)
      Feedsmith::Value.from({"format" => Feedsmith::Value.new(result.format), "feed" => result.feed})
    when "src/feeds/rss/detect/index.ts"
      Feedsmith::Value.new(Feedsmith.detect_rss_feed(input))
    when "src/feeds/atom/detect/index.ts"
      Feedsmith::Value.new(Feedsmith.detect_atom_feed(input))
    when "src/feeds/rdf/detect/index.ts"
      Feedsmith::Value.new(Feedsmith.detect_rdf_feed(input))
    when "src/feeds/json/detect/index.ts"
      Feedsmith::Value.new(Feedsmith.detect_json_feed(input))
    when "src/feeds/rss/parse/index.ts"
      Feedsmith.parse_rss_feed(input, options)
    when "src/feeds/atom/parse/index.ts"
      Feedsmith.parse_atom_feed(input, options)
    when "src/feeds/rdf/parse/index.ts"
      Feedsmith.parse_rdf_feed(input, options)
    when "src/feeds/json/parse/index.ts"
      Feedsmith.parse_json_feed(input, options)
    when "src/opml/parse/index.ts"
      Feedsmith.parse_opml(input, options)
    when "src/feeds/rss/generate/index.ts"
      Feedsmith::Value.new(Feedsmith.generate_rss_feed(input, options))
    when "src/feeds/atom/generate/index.ts"
      Feedsmith::Value.new(Feedsmith.generate_atom_feed(input, options))
    when "src/feeds/json/generate/index.ts"
      Feedsmith.generate_json_feed(input, options)
    when "src/opml/generate/index.ts"
      Feedsmith::Value.new(Feedsmith.generate_opml(input, options))
    else
      raise "Unknown fixture API: #{path} #{name}"
    end
  end
end

fixtures = JSON.parse(File.read(File.join(__DIR__, "fixtures/upstream.json")))

describe "Feedsmith upstream behavior (#{fixtures["revision"].as_s})" do
  fixtures["cases"].as_a.each_with_index do |record, index|
    it "#{index}: #{record["path"].as_s} #{record["function"].as_s}: #{record["test"].as_s}" do
      if error = record.as_h["error"]?
        caught = nil.as(Exception?)
        begin
          UpstreamParity.dispatch(record)
        rescue failure
          caught = failure
        end
        caught.should_not be_nil
        if failure = caught
          failure.message.should eq(error["message"].as_s)
          expected_type = error["name"].as_s
          unless expected_type == "Error"
            failure.class.name.split("::").last.should eq(expected_type)
          end
        end
      else
        actual = UpstreamParity.dispatch(record)
        UpstreamParity.normalize(actual).should eq(record["expected"])
      end
    end
  end
end
