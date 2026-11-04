import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

List<ChoiceOption<ApprovalPolicy>> buildApprovalPolicyChoices() {
  return <ChoiceOption<ApprovalPolicy>>[
    for (final ApprovalPolicy policy in approvalPolicyChoiceOrder)
      ChoiceOption<ApprovalPolicy>(
        value: policy,
        title: describeApprovalPolicyTitle(policy),
        detail: describeApprovalPolicyDetail(policy),
      ),
  ];
}

List<ChoiceOption<ApprovalPolicy?>> buildInheritableApprovalPolicyChoices(
  ApprovalPolicyFallback fallback,
) {
  return <ChoiceOption<ApprovalPolicy?>>[
    ChoiceOption<ApprovalPolicy?>(
      value: null,
      title: fallback.title,
      detail: fallback.detail,
    ),
    for (final ChoiceOption<ApprovalPolicy> choice
        in buildApprovalPolicyChoices())
      ChoiceOption<ApprovalPolicy?>(
        value: choice.value,
        title: choice.title,
        detail: choice.detail,
      ),
  ];
}

class ApprovalPolicyField extends StatelessWidget {
  const ApprovalPolicyField({
    required this.fallback,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final ApprovalPolicyFallback fallback;
  final ApprovalPolicy? selected;
  final ValueChanged<ApprovalPolicy?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: approvalPolicyLabel,
      children: <Widget>[
        ChoiceListField<ApprovalPolicy?>(
          options: buildInheritableApprovalPolicyChoices(fallback),
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
