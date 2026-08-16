require "simplecov-cobertura"

SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
SimpleCov.track_files "{,lib/}*.sh"
SimpleCov.add_filter "/tests/"
