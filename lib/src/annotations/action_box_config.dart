
class ActionBoxConfig {
  final String actionBoxType;
  final String actionRootType;
  final List<String> generateSourceDir;

  const ActionBoxConfig({
    required this.actionBoxType,
    this.actionRootType = 'ActionRoot',
    this.generateSourceDir = const ['lib']});
}


