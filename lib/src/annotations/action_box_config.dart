
class ActionBoxConfig {
  final String actionBoxTypeName;
  final String actionRootTypeName;
  final List<String> generateForDir;

  const ActionBoxConfig({
    required this.actionBoxTypeName,
    required this.actionRootTypeName,
    this.generateForDir = const ['lib']});
}


