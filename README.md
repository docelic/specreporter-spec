# Introduction
SpecReporter is a spec output formatter for Crystal, similar to Ruby minitest-reporters' SpecReporter.

![SpecReporter Demo Video](https://raw.githubusercontent.com/docelic/specreporter-spec/master/doc/specreporter-spec.gif)

## Description

Specreporter-spec looks and works similar to Ruby's "SpecReporter"
module from the minitest-reporters gem.

The changes/improvements compared to the default Crystal formatter include:

- Nicer and more informative output
- Info on elapsed time for each test
- Short and informative backtrace summaries
- Info on total number of assertions ran
- Configurable field widths
- Configurable terminal width
- Configurable elapsed time precision
- Ability to enable/disable sections from default formatter

## Usage

Add this to your application's `shard.yml`:

```yaml
development_dependencies:
  specreporter-spec:
    github: docelic/specreporter-spec
```

Simply add the following content to your `spec/spec_helper.cr`:

```crystal
require "spec"
require "specreporter-spec"

Spec.override_default_formatter(
 Spec::SpecReporterFormatter.new(
  #indent_string: "  ", # Indent string
  #width: 78,           # Terminal width (can use ENV["COLUMNS"])
  #elapsed_width: 3,    # Number of decimals for "elapsed" time
  #status_width: 5,     # Width of the status field
  #skip_errors_report: true,  # Skip the default, unwieldy backtraces
  #skip_slowest_report: true, # Skip the default "slowest" report
  #skip_failed_report: true,  # Skip the default failed reports summary
))
```

Configure the options to your liking.

And run tests in the usual way (`crystal s[pec]`).

Enjoy!

## TODO

The formatter certainly works, but the implementation must be
improved before it could be added to Crystal as build-in formatter.

Code improvements and further feature ideas welcome! Thanks!

## Other / Unrelated Formatters

Other / unrelated spec formatters for Crystal in existence:

- [Rainbow](https://github.com/veelenga/rainbow-spec) - formats the
  standard formatter dots in rainbow colors.

