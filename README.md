# feedsmith-cr

A native Crystal port of [Feedsmith](https://github.com/macieklamberski/feedsmith), preserving its feed structures, parsing rules, namespaces, and generated output as closely as possible. It parses RSS 0.90–2.0, Atom 0.3/1.0, RDF/RSS 1.0, JSON Feed 1/1.1, and OPML. It generates RSS 2.0, Atom 1.0, JSON Feed 1.1, and OPML. The upstream library does not provide an RDF generator.

The port targets upstream commit `ec294d8d796f8b267afc3bbe0f42f6972595c0e2`. Parsing and generation run entirely in Crystal, with a native XML tokenizer and writer and no external shards. Node and the original TypeScript project are needed only when regenerating development fixtures and rules.

## Installation

With this repository beside your application's directory, add a local shard dependency:

```yaml
dependencies:
  feedsmith-cr:
    path: ../feedsmith-cr
```

Run `shards install`. Crystal 1.21.1 or newer is required.

## Parsing

```crystal
require "feedsmith-cr"

document = <<-XML
  <rss version="2.0">
    <channel>
      <title>Example</title>
      <item><title>First post</title></item>
    </channel>
  </rss>
  XML

result = Feedsmith.parse_feed(document)
puts result.format                        # rss
puts result.feed["title"].as_s             # Example
puts result.feed["items"][0]["title"].as_s  # First post
puts result.to_json

feed = Feedsmith.parse_rss_feed(document, max_items: 10)
puts feed["link"].null?                    # true when absent
```

`parse_feed` returns `Feedsmith::AnyFeed`, with `format` and `feed` properties. Specific parsers return `Feedsmith::Value`. JSON Feed accepts either a JSON string or a Hash/Value object. XML formats accept XML strings.

Public method names follow Crystal's snake_case convention; object field names retain their upstream spelling:

| Upstream JavaScript | Crystal |
| --- | --- |
| `detectFeed` | `Feedsmith.detect_feed` |
| `parseFeed` | `Feedsmith.parse_feed` |
| `detectRssFeed`, `parseRssFeed`, `generateRssFeed` | `Feedsmith.detect_rss_feed`, `parse_rss_feed`, `generate_rss_feed` |
| `detectAtomFeed`, `parseAtomFeed`, `generateAtomFeed` | `Feedsmith.detect_atom_feed`, `parse_atom_feed`, `generate_atom_feed` |
| `detectRdfFeed`, `parseRdfFeed` | `Feedsmith.detect_rdf_feed`, `parse_rdf_feed` |
| `detectJsonFeed`, `parseJsonFeed`, `generateJsonFeed` | `Feedsmith.detect_json_feed`, `parse_json_feed`, `generate_json_feed` |
| `parseOpml`, `generateOpml` | `Feedsmith.parse_opml`, `generate_opml` |

Detection returns a format string or nil; specific detectors return Bool. The corresponding `DetectError`, `MalformedError`, `ParseError`, and `GenerateError` classes are available under `Feedsmith`.

Dates remain strings by default. Supply a block to parse them into a Time or another supported value:

```crystal
feed = Feedsmith.parse_json_feed(json) do |raw|
  Time.parse(raw, "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC)
end
```

OPML supports `extra_outline_attributes: ["customAttribute"]`. Advanced options can also be passed in a `Feedsmith::Value` object using upstream keys such as `maxItems`, `extraOutlineAttributes`, or `stylesheets`.

## Generation

```crystal
xml = Feedsmith.generate_rss_feed({
  "title" => "Example",
  "link" => "https://example.com",
  "description" => "Example feed",
  "items" => [{
    "title" => "First post",
    "pubDate" => Time.utc(2026, 10, 9, 12),
  }],
})

json = Feedsmith.generate_json_feed({
  "title" => "Example",
  "items" => [{"id" => "1", "content_text" => "Hello"}],
})
puts xml
puts json.to_json
```

Generators accept Hashes, Arrays, NamedTuples, and `Feedsmith::Value` objects. XML generators return String; JSON Feed generation returns Value. Dates accept strings and Crystal Time values. XML generator options include `stylesheets`, and OPML generation supports `extra_outline_attributes`.

Namespace support follows upstream: Acast, Admin, APP, arXiv, Atom, BlogChannel, Creative Commons/ccREL, Content, Dublin Core and Terms, FeedBurner, FeedPress, Geo/GeoRSS, Google Play, iTunes, Media RSS, OpenSearch, Pingback, Podcast, PRISM, Podlove Simple Chapters, RawVoice, RDF, Slash, Source, Spotify, Syndication, Threading, Trackback, Well-Formed Web, XML, and YouTube. Namespace fields use the original names, including `blogChannel`, `dc`, `dcterms`, `googleplay`, `itunes`, and `podcast`.

## Crystal differences

`Feedsmith::Value` preserves the original flexible object shapes through a runtime value wrapper. Use `[]`, `as_s`, `as_i`, `as_f`, `as_bool`, `as_a`, `as_h`, and `to_json` to access results. Missing values and JavaScript `undefined` become a Value whose raw value is nil; test them with `null?`. Unset fields are omitted when serializing objects. Crystal has no invalid Time equivalent, so use nil to omit invalid dates. TypeScript's generic namespace interfaces and compile-time strict-mode constraints are represented by Value rather than per-format static field schemas; the upstream `strict` option does not impose runtime schema validation.

## Development and parity

Run the checked-in upstream behavior suite:

```sh
crystal spec
```

The suite replays 5,161 distinct calls collected from 4,582 upstream tests across 93 files, including public APIs, shared helpers, every format/namespace utility, and returned getter/setter functions. It compares parsed structures, exact generated XML, JSON output, error classes/messages, alternate namespace prefixes, legacy feeds, CDATA/XHTML, date conversion, item limits, and stylesheet options. Additional specs exercise idiomatic Crystal Hash/NamedTuple inputs, Time values, and date blocks.

To regenerate fixtures from an upstream checkout with its development dependencies installed:

```sh
node scripts/export_parity.cjs ../feedsmith
node scripts/port_config.cjs ../feedsmith
node scripts/port_rules.cjs ../feedsmith
crystal spec
```

The exporter reads the upstream source and validates its original assertions without modifying it. The fixture records the upstream revision, skipped upstream tests, and 62 JavaScript-specific calls omitted from replay because they rely on opaque callback identity, mock builders, namespace-resolver factories, BigInt, or Symbol. Generated `src/feedsmith/rules.cr` contains native Crystal field rules; update its generator when changing those rules.

## License

MIT. Original Feedsmith by Maciej Lamberski; Crystal port by Wilson Tovar. The original copyright is preserved in [LICENSE](LICENSE).
