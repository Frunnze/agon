import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/item_draft_repository.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

final class NewItemSources {
  const NewItemSources({
    required this.itemDraftRepository,
    required this.runnerRepository,
    required this.deviceRepository,
    required this.folderPicker,
  });

  final ItemDraftRepository itemDraftRepository;
  final RunnerRepository runnerRepository;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;
}
