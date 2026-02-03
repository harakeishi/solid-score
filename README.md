# solid-score

[![Gem Version](https://badge.fury.io/rb/solid_score.svg)](https://badge.fury.io/rb/solid_score)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2.0-ruby.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A static analysis tool that scores Ruby classes and modules against SOLID principles using AST analysis.

## Features

- **SOLID Principles Analysis**: Scores each class/module on all five SOLID principles (SRP, OCP, LSP, ISP, DIP)
- **Multiple Output Formats**: Text (table) and JSON output for CI/CD integration
- **Git Diff Mode**: Analyze only changed files to prevent score regression
- **Configurable Thresholds**: Set minimum scores for CI quality gates
- **Customizable Weights**: Adjust the importance of each principle in the total score

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'solid_score'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install solid_score
```

## Quick Start

```bash
# Analyze current directory
solid-score .

# Analyze specific directory
solid-score app/models

# Output as JSON
solid-score app/ --format json

# Analyze only changed files (git diff)
solid-score . --diff origin/main

# Use configuration file
solid-score . --config .solid-score.yml
```

## Usage

### Command Line Options

```
Usage: solid-score [path] [options]

Options:
    --format FORMAT              Output format: text (default), json
    --config FILE                Path to configuration file
    --min-score SCORE            Minimum total score (exit 1 if below)
    --min-srp SCORE              Minimum SRP score
    --min-ocp SCORE              Minimum OCP score
    --min-lsp SCORE              Minimum LSP score
    --min-isp SCORE              Minimum ISP score
    --min-dip SCORE              Minimum DIP score
    --diff REF                   Analyze only files changed since REF (git ref)
    --max-decrease SCORE         Maximum allowed score decrease per class
    --exclude PATTERN            Exclude patterns (comma-separated)
    --version                    Show version
    -h, --help                   Show help
```

### Output Examples

#### Text Format (default)

```
solid-score v0.1.0

Analyzed 5 class(es)

Class                                      SRP   OCP   LSP   ISP   DIP   Total
-------------------------------------------------------------------------------
OrderService                             100.0 100.0 100.0 100.0 100.0   100.0
UserRepository                            80.0  90.0 100.0  95.0  85.0    88.0
PaymentProcessor                          60.0  70.0 100.0  80.0  50.0    68.5
ShapeCalculator                           60.0  35.0 100.0 100.0 100.0    78.2
GodClass                                  30.0 100.0 100.0  65.0 100.0    72.0
-------------------------------------------------------------------------------
Average                                   66.0  79.0 100.0  88.0  87.0    81.3
```

#### JSON Format

```json
{
  "version": "0.1.0",
  "classes": [
    {
      "class_name": "OrderService",
      "file_path": "app/services/order_service.rb",
      "srp": 100,
      "ocp": 100.0,
      "lsp": 100,
      "isp": 100,
      "dip": 100.0,
      "total": 100.0,
      "confidence": {
        "srp": "high",
        "ocp": "low",
        "lsp": "low_medium",
        "isp": "medium_high",
        "dip": "high"
      }
    }
  ],
  "summary": {
    "total_classes": 1,
    "average_score": 100.0
  }
}
```

## Configuration

Create a `.solid-score.yml` file in your project root:

```yaml
# Target paths to analyze
paths:
  - app/models
  - app/services
  - lib

# Patterns to exclude (glob format)
exclude:
  - spec/**
  - test/**
  - tmp/**
  - vendor/**

# Output format
format: text  # or json

# Score thresholds (CI will fail if below)
thresholds:
  total: 70
  srp: 60
  ocp: 50
  lsp: 50
  isp: 50
  dip: 60

# Weight of each principle in total score (must sum to 1.0)
weights:
  srp: 0.30   # 30%
  ocp: 0.15   # 15%
  lsp: 0.10   # 10%
  isp: 0.20   # 20%
  dip: 0.25   # 25%

# Git diff analysis settings
diff:
  max_decrease: 5     # Max allowed score decrease per class
  new_class_min: 70   # Minimum score for new classes
```

## SOLID Principles Scoring

### SRP (Single Responsibility Principle)

**Metric**: LCOM4 (Lack of Cohesion of Methods 4)

Measures class cohesion using graph connectivity analysis. A class with high cohesion (methods working with shared instance variables) scores higher.

- **Score 100**: All methods are connected (single responsibility)
- **Score 0**: Methods are completely disconnected (multiple responsibilities)
- **Confidence**: High

### OCP (Open/Closed Principle)

**Metric**: Conditional complexity + type checking patterns

Detects patterns that suggest a class needs modification for extension:
- `if/else` chains with type checking (`is_a?`, `kind_of?`, `instance_of?`)
- `case/when` statements with multiple branches
- Conditional density in methods

- **Confidence**: Low-Medium (heuristic-based)

### LSP (Liskov Substitution Principle)

**Metric**: Inheritance contract compliance

Detects potential violations:
- Method signature changes (different parameters than parent)
- Missing `super` calls in overridden methods
- Return type inconsistencies

- **Confidence**: Low-Medium (requires runtime analysis for full accuracy)

### ISP (Interface Segregation Principle)

**Metric**: Interface bloat detection

Measures:
- Number of public methods
- Method parameter count
- Unused method dependencies

- **Confidence**: Medium-High

### DIP (Dependency Inversion Principle)

**Metric**: Concrete dependency ratio

Calculates the ratio of concrete class instantiations to total dependencies:
- Direct `ClassName.new` calls penalize the score
- Standard library classes (Array, Hash, String, etc.) are whitelisted
- Dependency injection patterns score higher

- **Confidence**: High

## CI/CD Integration

### GitHub Actions

```yaml
name: SOLID Score Check

on:
  pull_request:
    branches: [main]

jobs:
  solid-score:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for diff mode

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Install solid-score
        run: gem install solid_score

      - name: Check SOLID scores
        run: solid-score app/ lib/ --min-score 70

      - name: Check score regression (diff mode)
        run: solid-score . --diff origin/main --max-decrease 5
```

### Exit Codes

| Code | Description |
|------|-------------|
| 0    | All checks passed |
| 1    | Score below threshold or regression detected |
| 2    | Invalid arguments or configuration error |

## Development

After checking out the repo, run:

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Run linter
bundle exec rubocop

# Run the tool locally
bundle exec solid-score spec/fixtures
```

## Limitations

- **Static Analysis Only**: Cannot detect runtime behavior or duck typing patterns
- **OCP/LSP Accuracy**: These principles are difficult to measure statically; scores are heuristic-based
- **Module Support**: Module analysis is less accurate than class analysis
- **Metaprogramming**: Heavy use of `define_method`, `method_missing`, etc. may affect accuracy

## Requirements

- Ruby >= 3.2.0

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/harakeishi/solid-score.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## References

- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID) - Wikipedia
- [LCOM4 Metric](https://www.aivosto.com/project/help/pm-oo-cohesion.html) - Lack of Cohesion of Methods
- [Robert C. Martin - Clean Architecture](https://www.amazon.com/Clean-Architecture-Craftsmans-Software-Structure/dp/0134494164)
