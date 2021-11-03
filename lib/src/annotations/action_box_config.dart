class ActionBoxConfig {
  final String actionRootType;
  final List<String> generateSourceDir;

  const ActionBoxConfig(
      {this.actionRootType = 'ActionRoot',
      this.generateSourceDir = const ['lib']});
}
