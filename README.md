# Delta

Logs HTTP files to an S3 bucket at a configurable frequency.

A delta is the place where a river merges into a larger body of water: in our case, it's where our various HTTP files are merged into our data lake.

## Configuration

Delta is built around a
[GenStage](https://hexdocs.pm/gen_stage/GenStage.html) pipeline, taking data
from Producers and writing it to Sinks.

The basic unit is a [File](lib/delta/file.ex), a chunk of possibly-encoded data.

Delta is configured by JSON. Example:

```json
{
  "producers": {
    "polling_producer_name": {
      "url": "https://cdn.mbta.com/realtime/VehiclePositions.pb",
    },
    "webhook_producer_name": {
      "type": "webhook",
    },
  },
  "sinks": {
    "s3_sink_name": {
      "type": "s3",
      "bucket": "bucket_name",
      "producers": [
        "polling_producer_name",
        "webhook_producer_name"
      ]
    },
    "log_sink_name": {
      "producers": [
        "polling_producer_name",
        "webhook_producer_name"
      ]
    }
  }
}
```

## Producers

Delta produces files from two sources: polled HTTP endpoints and webhooks.

### HTTP Polling

Polling sources make an HTTP request for data at a configurable interval.

Configuration options:
* `url`: Required.
* `frequency`: Default 60000.
* `headers`: Default `{}`. Can fetch values if given an environment variable name. Example: `{"content-type": "application/x-protobuf", "authorization": {"system": "API_SECRET_KEY"}}`.
* `filters`: Default `[]`. See Filters below.

### S3 Polling

Makes a request to S3, authenticated by IAM

Configuration options:
* `type`: Must be `"s3"`.
* `bucket`: Required string.
* `path`: Required string.
* `frequency`: Default 60000.
* `filters`: Default `[]`. See Filters below.

### Webhooks

Webhooks accept an HTTP POST to `/webhook/:webhook_producer_name`, and treat the body of
the request as the content of the file.

Configuration options:
* `type`: Must be `"webhook"`.
* `authorization`: A string. Default `null`. If present, checks that incoming requests have an `"authorization"` header set to this value.
* `filters`: Default `[]`. See Filters below.

### Filters

Both polling and webhook sources also accept filters, which can arbitrarily
process the File into 0 or more Files. Some example filters:

- ensure the body is GZip-compressed (or not compressed)
- convert a JSON body into multiple Files based on an access path
- rename the File based on an access path
- set the `updated_at` value based on an access path

Each entry in the configuration is a list whose first element is the string name of a function in [`lib/delta/file.ex`](lib/delta/file.ex), and any further elements are arguments to pass to that function.

Example:
```json
"filters": [
  ["ensure_not_encoded"],
  ["json_updated_at", ["metadata", "timestamp"]],
]
```

All producers will always finish with `["ensure_content_type"]` and `["ensure_gzipped"]`.

## Sinks

Sinks take the generated Files and write them somewhere.

### S3

The most useful sink writes the Files to an Amazon S3 bucket.

Writes to the given bucket at the path `{prefix}/{year}/{month}/{day}/{time}_{url}.gz`.

Configuration options:
* `type`: must be `"s3"`.
* `bucket`: Required string.
* `prefix`: Default `""`. Will prepend this to all file names it writes to s3.
* `acl`: Default `"public-read"`. Passed to `S3.put_object`.
* `producers`: Required list of string producer names.
* `filename_rewrites`: Default `[]`. Contains a list of maps like - `%{pattern: "old_value", replacement: "new_value"}` - this will be applied to the resulting s3 filename. Note: the full collection gets applied to every resultant producer filename, so these configurations should be relatively specific. 

### Log

Useful for debugging, the Log sink logs a message for each File.

Configuration options:
* `type`: must be `"log"`.
* `producers`: Required list of string producer names.

## Headers

Delta uses the `content-type` and `content-encoding` headers. If the `content-type` is missing, it can fall back to the known extensions listed in `config/config.exs`, with a default of `application/octet-stream`. The only supported `content-encoding` is `"gzip"`.

## Installation

```
asdf install
mix deps.get
env DELTA_JSON="$(cat config.json)" mix phx.server
```

Delta loads configuration from the `DELTA_JSON` environment variable.
With `MIX_ENV=dev`, it will fall back to [priv/default_configuration.json](priv/default_configuration.json).
