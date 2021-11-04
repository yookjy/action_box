class ActionBoxConfig {
  final String actionBoxType;
  final String actionRootType;
  final List<String> generateSourceDir;

  const ActionBoxConfig(
      {this.actionBoxType = 'ActionBox',
      this.actionRootType = 'ActionRoot',
      this.generateSourceDir = const ['lib']});
}
