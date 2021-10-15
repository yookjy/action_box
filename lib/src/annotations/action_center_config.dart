
class ActionCenterConfig {
  final String actionBoxTypeName;
  final String actionRootTypeName;
  final List<String> generateForDir;

  const ActionCenterConfig({
    required this.actionBoxTypeName,
    required this.actionRootTypeName,
    this.generateForDir = const ['lib']});
}


