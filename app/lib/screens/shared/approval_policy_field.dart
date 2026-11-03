import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

class ApprovalPolicyField extends StatelessWidget {
  const ApprovalPolicyField({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final ApprovalPolicy selected;
  final ValueChanged<ApprovalPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<ChoiceOption<ApprovalPolicy>> options =
        <ChoiceOption<ApprovalPolicy>>[
          for (final ApprovalPolicy policy in ApprovalPolicy.values)
            ChoiceOption<ApprovalPolicy>(
              value: policy,
              title: describeApprovalPolicyTitle(policy),
              detail: describeApprovalPolicyDetail(policy),
            ),
        ];

    return FormFieldBlock(
      label: approvalPolicyLabel,
      children: <Widget>[
        ChoiceListField<ApprovalPolicy>(
          options: options,
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
