# Security policy

## Reporting a vulnerability

Please report security issues **privately**, through GitHub's
[private vulnerability reporting](https://github.com/Ourea-Technologies/ensemble-weather-r/security/advisories/new)
for this repository. Do not open a public issue, pull request or discussion
for a suspected vulnerability.

Include what you found, how to reproduce it, and the package version
(`packageVersion("ensembleweather")`). We acknowledge reports within three
working days and keep you informed until a fix is released. We credit
reporters in the advisory unless you prefer otherwise.

## Supported versions

Security fixes go into the latest release. Before 1.0, that is the latest
0.x minor version.

## What the package guarantees

- The API key is sent only as `X-API-Key`, only to the configured base URL's
  origin (a redirect to another host, port or scheme drops it), and never
  appears in printed output, logs or error messages. The response cache is
  keyed by a SHA-256 digest of the key, never the key itself.
- TLS certificate verification is always on; the package has no option to
  turn it off, and a verification failure is never retried.
- Response bodies are bounded at 64 MiB (by libcurl while reading, and again
  after).
- JSON is parsed by jsonlite into plain lists and decoded into fixed,
  declared types; nothing in a response is evaluated, and no R object is
  ever deserialised from the network.

Vulnerabilities in the API service itself can be reported the same way; we
will route them.
