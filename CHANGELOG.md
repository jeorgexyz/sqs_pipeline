# Changelog

## [0.2.0] - 2026-01-07

### Complete Rewrite and Modernization

#### Added
- Complete GenStage pipeline implementation
- Full AWS integration with ExAws for S3 and SQS
- Automatic gzip decompression for compressed files
- Comprehensive error handling and logging
- Configuration system with dev/test/prod environments
- Docker and docker-compose support
- Automated AWS setup script
- LocalStack testing support
- Detailed README with complete documentation
- Process supervision and fault tolerance
- Parallel processing with multiple consumer pipelines
- JSON output format for processed results

#### Fixed
- Fixed deprecated Elixir syntax (`//` → `\\`)
- Fixed deprecated Supervisor.Spec usage
- Fixed missing module implementations (SQS.Server)
- Fixed inconsistent module naming (Gtube vs GTUBE vs SQS)
- Fixed typo in ProducerConsumber → ProducerConsumer
- Fixed incorrect GenStage subscription syntax
- Fixed missing dependencies (ExAws, Jason, etc.)
- Fixed compilation errors and syntax issues
- Fixed incomplete application supervisor setup

#### Changed
- Modernized to Elixir 1.14+ syntax and patterns
- Simplified architecture with clearer separation of concerns
- Updated GenStage to version 1.2
- Improved configuration with runtime.exs
- Better logging with structured log messages
- Enhanced documentation with examples

#### Technical Improvements
- Proper OTP application structure
- Registry for process naming
- Backpressure handling with demand-driven architecture
- Production-ready release configuration
- Container-ready with optimized Dockerfile
- Test infrastructure with ExUnit

## [0.1.0] - Original

### Initial Release
- Basic GenStage structure
- Incomplete implementation
- Multiple syntax errors
- Missing dependencies
