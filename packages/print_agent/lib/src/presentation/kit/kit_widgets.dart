import 'dart:async';

import 'package:flutter/material.dart';

import 'agent_ui_kit.dart';
import 'kit_tokens.dart';

AgentUiKit get _kit => PrintAgentUi.kit;

/// Chữ: [AppText] dịch [text] (khoá đa ngôn ngữ), [AppText.raw] hiện nguyên.
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.tone = AppTextTone.primary,
    this.textColor,
    this.textAlign = TextAlign.left,
    this.maxLines = _variantMaxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap,
  }) : translate = true;

  const AppText.raw(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.tone = AppTextTone.primary,
    this.textColor,
    this.textAlign = TextAlign.left,
    this.maxLines = _variantMaxLines,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap,
  }) : translate = false;

  static const int _variantMaxLines = -1;

  final String text;
  final bool translate;
  final AppTextVariant variant;
  final AppTextTone tone;
  final Color? textColor;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => _kit.text(
    AgentTextSpec(
      text: text,
      translate: translate,
      variant: variant,
      tone: tone,
      textColor: textColor,
      textAlign: textAlign,
      maxLines: maxLines == _variantMaxLines ? null : maxLines,
      useVariantMaxLines: maxLines == _variantMaxLines,
      overflow: overflow,
      softWrap: softWrap,
    ),
  );
}

class AppRow extends Row {
  const AppRow({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.spacing = 0.0,
    super.children,
  });
}

class AppColumn extends Column {
  const AppColumn({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.spacing = 0.0,
    super.children,
  });
}

/// Lề co giãn theo màn hình (như `AppPadding` của app).
class AppPadding extends StatelessWidget {
  const AppPadding({
    super.key,
    required EdgeInsets padding,
    required this.child,
  }) : _design = padding,
       _l = 0,
       _t = 0,
       _r = 0,
       _b = 0;

  const AppPadding.all(double value, {super.key, required this.child})
    : _design = null,
      _l = value,
      _t = value,
      _r = value,
      _b = value;

  const AppPadding.symmetric({
    super.key,
    double horizontal = 0,
    double vertical = 0,
    required this.child,
  }) : _design = null,
       _l = horizontal,
       _t = vertical,
       _r = horizontal,
       _b = vertical;

  const AppPadding.only({
    super.key,
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
    required this.child,
  }) : _design = null,
       _l = left,
       _t = top,
       _r = right,
       _b = bottom;

  final EdgeInsets? _design;
  final double _l;
  final double _t;
  final double _r;
  final double _b;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: _design ?? _kit.insets(EdgeInsets.fromLTRB(_l, _t, _r, _b)),
    child: child,
  );
}

Widget get sdsSizedBox4 => _kit.gap(4);
Widget get sdsSizedBox8 => _kit.gap(8);

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) => _kit.divider();
}

class BaseTap extends StatelessWidget {
  const BaseTap({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => _kit.tap(onTap: onTap, child: child);
}

class BaseCard extends StatelessWidget {
  const BaseCard.section({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _kit.card(child: child);
}

class BaseButton extends StatelessWidget {
  const BaseButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.backgroundColor,
    this.titleColor,
  });

  final String title;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) => _kit.button(
    title: title,
    onPressed: onPressed,
    backgroundColor: backgroundColor,
    titleColor: titleColor,
  );
}

class BaseInputModel {
  const BaseInputModel({
    required this.controller,
    required this.label,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
}

class BaseInput extends StatelessWidget {
  const BaseInput({super.key, required this.model});

  final BaseInputModel model;

  @override
  Widget build(BuildContext context) => _kit.input(
    controller: model.controller,
    label: model.label,
    obscureText: model.obscureText,
  );
}

class BaseCupertinoSwitch extends StatelessWidget {
  const BaseCupertinoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.leftLabel,
    this.fontWeight,
    this.mainAxisSize = MainAxisSize.min,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? leftLabel;
  final FontWeight? fontWeight;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) => _kit.toggle(
    value: value,
    onChanged: onChanged,
    leftLabel: leftLabel,
    fontWeight: fontWeight,
    mainAxisSize: mainAxisSize,
  );
}

class AdaptiveSelectableCard extends StatelessWidget {
  const AdaptiveSelectableCard({
    super.key,
    required this.isSelected,
    required this.onTap,
    this.padding,
    required this.child,
  });

  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => _kit.selectableCard(
    isSelected: isSelected,
    onTap: onTap,
    padding: padding,
    child: child,
  );
}

/// Thanh tiêu đề trang; [title] là khoá đa ngôn ngữ.
class BaseAppBar {
  const BaseAppBar({required this.title});

  final String title;
}

class BaseScaffoldHelper extends StatelessWidget {
  const BaseScaffoldHelper({
    super.key,
    required this.appBar,
    required this.body,
  });

  final BaseAppBar appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) =>
      _kit.page(title: appBar.title, body: body);
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    required this.onConfirm,
  });

  final String title;
  final String content;
  final String confirmText;
  final FutureOr<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) => _kit.confirmDialog(
    title: title,
    content: content,
    confirmText: confirmText,
    onConfirm: onConfirm,
  );
}

abstract final class BaseBottomSheet {
  static Future<T?> show<T>({
    required Widget body,
    String? headerTitle,
    bool? allowOffline,
  }) => _kit.showSheet<T>(body: body, headerTitle: headerTitle);
}

abstract final class AppNotification {
  static Future<void> show({
    required String message,
    AppNotificationType? type,
    Widget? trailing,
    Duration? duration,
  }) => _kit.notify(
    message: message,
    type: type ?? AppNotificationType.info,
    trailing: trailing,
    duration: duration,
  );

  static Future<void> error({required String message, Widget? trailing}) =>
      show(
        message: message,
        type: AppNotificationType.error,
        trailing: trailing,
      );

  static void dismiss() => _kit.dismissNotification();
}
