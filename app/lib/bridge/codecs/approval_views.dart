import 'package:agent_orchestration/bridge/codecs/approval_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workflow_views.dart';

final class SkillChangeView implements JsonEncodable {
  SkillChangeView({required this.skillName, required List<DiffLine> changes})
    : changes = List<DiffLine>.unmodifiable(changes);

  factory SkillChangeView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return SkillChangeView(
      skillName: readField(fields, 'skill_name', decodeText),
      changes: readListField(fields, 'changes', DiffLine.fromJson),
    );
  }

  final String skillName;
  final List<DiffLine> changes;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'skill_name': skillName,
      'changes': encodeList(changes),
    };
  }
}

final class ApprovalView implements JsonEncodable {
  const ApprovalView({
    required this.approval,
    required this.description,
    required this.isWaiting,
    required this.skillChange,
  });

  factory ApprovalView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ApprovalView(
      approval: readField(fields, 'approval', ApprovalRequest.fromJson),
      description: readField(fields, 'description', decodeText),
      isWaiting: readField(fields, 'is_waiting', decodeFlag),
      skillChange: readOptionalField(
        fields,
        'skill_change',
        SkillChangeView.fromJson,
      ),
    );
  }

  final ApprovalRequest approval;
  final String description;
  final bool isWaiting;
  final SkillChangeView? skillChange;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'approval': approval.toJson(),
      'description': description,
      'is_waiting': isWaiting,
      'skill_change': skillChange?.toJson(),
    };
  }
}

final class ApprovalsView implements JsonEncodable {
  ApprovalsView({
    required this.waitingCount,
    required List<ApprovalView> approvals,
  }) : approvals = List<ApprovalView>.unmodifiable(approvals);

  factory ApprovalsView.fromJson(Object? json) {
    final JsonObject fields = decodeObject(json);
    return ApprovalsView(
      waitingCount: readField(fields, 'waiting_count', decodeCount),
      approvals: readListField(fields, 'approvals', ApprovalView.fromJson),
    );
  }

  final int waitingCount;
  final List<ApprovalView> approvals;

  @override
  JsonObject toJson() {
    return <String, Object?>{
      'waiting_count': waitingCount,
      'approvals': encodeList(approvals),
    };
  }
}
