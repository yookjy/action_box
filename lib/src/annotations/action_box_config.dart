
class ActionBoxConfig {
  final String actionBoxTypeName;
  final String actionRootTypeName;
  final List<String> generateForDir;

  const ActionBoxConfig({
    required this.actionBoxTypeName,
    this.actionRootTypeName = 'ActionRoot',
    this.generateForDir = const ['lib']});
}


