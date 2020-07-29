# Delta Architecture

## Overview

Delta is built around a
[GenStage](https://hexdocs.pm/gen_stage/GenStage.html) pipeline, taking data
from Producers and writing it to Sinks.

The basic unit is a [File](lib/delta/file.ex), a chunk of possibly-encoded data.

## Producers

Delta produces files from two sources: polled HTTP endpoints and webhooks.

### Polling

Polling sources make an HTTP request for data at a configurable interval.

### Webhooks

Webhooks accept an HTTP POST to particular endpoints, and treat the body of
the request as the content of the file.

### Filters

Both polling and webhook sources also accept filters, which can arbitrarily
process the File into 0 or more Files. Some example filters:

- ensure the body is GZip-compressed (or not compressed)
- convert a JSON body into multiple Files based on an access path
- rename the File based on an access path
- set the `updated_at` value based on an access path

## Sinks

Sinks take the generated Files and write them somewhere.

### S3

The most useful sink writes the Files to an Amazon S3 bucket.

### Log

Useful for debugging, the Log sink logs a message for each File.


### Configuration

By default, Delta loads configuration the `DELTA_JSON` environment
variable. You can see a sample JSON configuration in
[priv/default_configuration.json](priv/default_configuration.json).
