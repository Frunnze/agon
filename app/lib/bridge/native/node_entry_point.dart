enum NodeEntryPoint {
  start('orchestration_start'),
  handleCommand('orchestration_handle_command');

  const NodeEntryPoint(this.symbol);

  final String symbol;
}

const String stopSymbol = 'orchestration_stop';

const String freeStringSymbol = 'orchestration_free_string';
